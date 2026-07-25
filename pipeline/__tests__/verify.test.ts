import { describe, it, expect } from 'vitest';
import { verifyCoverage } from '../steps/verify';
import type { Analyzer, KiwiToken } from '../lib/kiwi';
import { normalizeNiklEntry, cleanLemma, isContentTag } from '../lib/normalize';

/**
 * Analyseur factice : phrases pré-segmentées « surface/LEMME/TAG surface/LEMME/TAG … ».
 * Permet de tester la logique de couverture hors ligne, sans modèle Kiwi (le
 * comportement réel de Kiwi est couvert par le run d'intégration du pipeline).
 */
const stub: Analyzer = {
  async analyze(text: string): Promise<KiwiToken[]> {
    let pos = 0;
    return text.split(/\s+/).filter(Boolean).map((part) => {
      const [surface, lemma, tag] = part.split('/');
      const token = { str: lemma ?? surface, tag: tag ?? 'NNG', position: pos, length: surface.length };
      pos += surface.length + 1;
      return token;
    });
  },
};

describe('normalizeNiklEntry', () => {
  it('retire le 다 des verbes et adjectifs', () => {
    expect(normalizeNiklEntry('가다', '동사')).toEqual({ lemma: '가', pos: 'VV' });
    expect(normalizeNiklEntry('예쁘다', '형용사')).toEqual({ lemma: '예쁘', pos: 'VA' });
  });
  it('garde le 다 hors verbes et nettoie les homographes', () => {
    expect(normalizeNiklEntry('바다01', '명사')).toEqual({ lemma: '바다', pos: 'NNG' });
    expect(cleanLemma('가다01')).toBe('가다');
  });
  it('mappe les POS coréens vers les tags Kiwi', () => {
    expect(normalizeNiklEntry('빨리', '부사').pos).toBe('MAG');
    expect(normalizeNiklEntry('것', '의존명사').pos).toBe('NNB');
  });
});

describe('isContentTag', () => {
  it('classe contenus vs grammaticaux', () => {
    expect(isContentTag('NNG')).toBe(true);
    expect(isContentTag('VV')).toBe(true);
    expect(isContentTag('JKS')).toBe(false); // particule
    expect(isContentTag('EF')).toBe(false);  // terminaison
    expect(isContentTag('SF')).toBe(false);  // ponctuation
  });
});

describe('verifyCoverage', () => {
  const known = new Set(['날씨', '좋', '오늘', '아침', '커피', '마시']);

  it('accepte un texte entièrement connu (100 %)', async () => {
    const result = await verifyCoverage(
      {
        sentences: ['오늘/오늘/NNG 날씨가/날씨/NNG 가/가/JKS 좋아요/좋/VA 아요/아요/EF'],
        knownLemmas: known,
        targetLemmas: [],
      },
      stub,
    );
    expect(result.coveragePct).toBe(100);
    expect(result.ok).toBe(true);
    expect(result.intruders).toEqual([]);
  });

  it('compte les cibles comme budget inconnu mais pas comme intrus', async () => {
    const result = await verifyCoverage(
      {
        // 배달 apparaît 2 fois (cible), le reste est connu
        sentences: [
          '오늘/오늘/NNG 배달을/배달/NNG 을/을/JKO 시켰어요/시키/VV 었어요/었어요/EF',
          '배달이/배달/NNG 이/이/JKS 빨리/빨리/MAG 왔어요/오/VV 았어요/았어요/EF',
        ],
        knownLemmas: new Set([...known, '시키', '빨리', '오']),
        targetLemmas: ['배달'],
        // Texte de test minuscule : 2 tokens cibles sur 10 pèsent 20 %.
        // Sur un vrai texte de 300–400 mots, le même budget pèse 2–4 %.
        thresholdPct: 80,
      },
      stub,
    );
    expect(result.intruders).toEqual([]);
    expect(result.targetCounts['배달']).toBe(2);
    expect(result.missingTargets).toEqual([]);
    expect(result.coveragePct).toBe(80);
    expect(result.ok).toBe(true);
  });

  it('détecte les intrus et fait échouer sous le seuil', async () => {
    const result = await verifyCoverage(
      {
        // 폭염(inconnu, pas cible) répété : la couverture plonge
        sentences: ['폭염이/폭염/NNG 이/이/JKS 왔다/오/VV 다/다/EF 폭염/폭염/NNG 폭염/폭염/NNG'],
        knownLemmas: known,
        targetLemmas: [],
        thresholdPct: 96,
      },
      stub,
    );
    expect(result.intruders[0]).toEqual({ lemma: '폭염', count: 3 });
    expect(result.ok).toBe(false);
  });

  it('signale une cible manquante ou trop rare', async () => {
    const result = await verifyCoverage(
      {
        sentences: ['오늘/오늘/NNG 커피를/커피/NNG 를/를/JKO 마셔요/마시/VV 어요/어요/EF'],
        knownLemmas: known,
        targetLemmas: ['배달'],
      },
      stub,
    );
    expect(result.missingTargets).toEqual(['배달']);
    expect(result.ok).toBe(false);
  });

  it('tolère noms propres (tag NNP) et allowlist de la série', async () => {
    const result = await verifyCoverage(
      {
        sentences: ['민준이/민준/NNP 이/이/JKS 성수동에서/성수동/NNG 에서/에서/JKB 커피를/커피/NNG 를/를/JKO 마셔요/마시/VV 어요/어요/EF'],
        knownLemmas: known,
        targetLemmas: [],
        properNouns: ['성수동'],
      },
      stub,
    );
    expect(result.coveragePct).toBe(100);
    expect(result.ok).toBe(true);
  });

  it('les mots-outils de l’allowlist globale ne comptent jamais comme intrus', async () => {
    const result = await verifyCoverage(
      {
        sentences: ['그게/그게/NP 뭐예요/뭐/NP 예요/이/VCP'],
        knownLemmas: new Set(),
        targetLemmas: [],
      },
      stub,
    );
    expect(result.intruders).toEqual([]);
  });
});
