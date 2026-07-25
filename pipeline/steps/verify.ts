/**
 * Vérification déterministe de couverture lexicale — le différenciateur méthodologique n°1.
 * Analyse morphologique (Kiwi) → lemmes → comparaison au profil lexical.
 * Aucun LLM ici : la mesure doit être reproductible.
 *
 * Définitions :
 * - Couverture = part des tokens « connus » sur l'ensemble des tokens analysés.
 *   Les morphèmes grammaticaux (particules, terminaisons, ponctuation) sont connus
 *   par construction ; les tokens de contenu sont connus s'ils sont dans le profil,
 *   l'allowlist ou les noms propres de la série.
 * - Les items CIBLES (nouveaux du jour) comptent comme inconnus : c'est le budget
 *   d'apprentissage (3–8 items ≈ 2–4 % des tokens d'un texte de 300–400 mots).
 * - Les INTRUS sont les lemmes de contenu inconnus hors cibles : c'est eux que la
 *   boucle de réécriture doit éliminer.
 */
import type { Analyzer } from '../lib/kiwi';
import { isContentTag, lemmaKey, ALWAYS_KNOWN_LEMMAS } from '../lib/normalize';

export interface VerifyInput {
  sentences: string[];
  /** Lemmes du profil (known + seen + prior NIKL). */
  knownLemmas: Set<string>;
  /** Lemmes cibles du jour (nouveaux à introduire). */
  targetLemmas: string[];
  /** Noms propres / lieux de la série (allowlist du series_bible). */
  properNouns?: string[];
  /** Seuil d'acceptation (défaut 96). */
  thresholdPct?: number;
  /** Occurrences minimales attendues par cible (défaut 2). */
  minTargetOccurrences?: number;
}

export interface VerifyResult {
  ok: boolean;
  coveragePct: number;
  totalTokens: number;
  unknownTokens: number;
  /** Lemmes inconnus hors cibles, avec leur nombre d'occurrences — à réécrire. */
  intruders: { lemma: string; count: number }[];
  /** Occurrences constatées de chaque cible. */
  targetCounts: Record<string, number>;
  missingTargets: string[];
}

export async function verifyCoverage(input: VerifyInput, analyzer: Analyzer): Promise<VerifyResult> {
  const threshold = input.thresholdPct ?? 96;
  const minOcc = input.minTargetOccurrences ?? 2;
  const targets = new Set(input.targetLemmas.map(lemmaKey));
  const proper = new Set((input.properNouns ?? []).map(lemmaKey));

  let totalTokens = 0;
  let unknownTokens = 0;
  const intruderCounts = new Map<string, number>();
  const targetCounts: Record<string, number> = {};
  for (const t of targets) targetCounts[t] = 0;

  for (const sentence of input.sentences) {
    const tokens = await analyzer.analyze(sentence);
    for (const token of tokens) {
      totalTokens++;
      if (!isContentTag(token.tag)) continue; // grammatical → connu par construction
      const lemma = lemmaKey(token.str);
      if (targets.has(lemma)) {
        targetCounts[lemma]++;
        unknownTokens++; // budget d'apprentissage : compte dans la couverture
        continue;
      }
      if (
        input.knownLemmas.has(lemma) ||
        ALWAYS_KNOWN_LEMMAS.has(lemma) ||
        proper.has(lemma) ||
        token.tag.startsWith('NNP') // noms propres détectés par Kiwi : tolérés
      ) {
        continue;
      }
      unknownTokens++;
      intruderCounts.set(lemma, (intruderCounts.get(lemma) ?? 0) + 1);
    }
  }

  const coveragePct = totalTokens === 0 ? 0 : ((totalTokens - unknownTokens) / totalTokens) * 100;
  const intruders = [...intruderCounts.entries()]
    .map(([lemma, count]) => ({ lemma, count }))
    .sort((a, b) => b.count - a.count);
  const missingTargets = Object.entries(targetCounts)
    .filter(([, c]) => c < minOcc)
    .map(([l]) => l);

  return {
    ok: coveragePct >= threshold && missingTargets.length === 0,
    coveragePct: Math.round(coveragePct * 10) / 10,
    totalTokens,
    unknownTokens,
    intruders,
    targetCounts,
    missingTargets,
  };
}
