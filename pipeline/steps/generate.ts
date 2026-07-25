/**
 * Génération de l'épisode du jour (+ réécriture ciblée si le vérificateur échoue).
 * Pattern SRS-Stories : prompt simple + boucle de réécriture > constrained decoding.
 */
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { llmJson, LlmUsage } from '../lib/llm';
import type { Series, TryToday } from '../../src/lib/types';

export interface GeneratedEpisode {
  title: string;
  sentences: { ko: string; fr: string }[];
  teaser_next: string;
  try_today: TryToday[];
}

export interface TargetItem {
  lemma: string;
  gloss_fr: string | null;
  kind: 'word' | 'chunk';
}

const EPISODE_SCHEMA = {
  type: 'object',
  properties: {
    title: { type: 'string', description: "Titre court de l'épisode, en coréen" },
    sentences: {
      type: 'array',
      description: 'Le texte, phrase par phrase (une phrase = un élément)',
      items: {
        type: 'object',
        properties: {
          ko: { type: 'string', description: 'La phrase en coréen' },
          fr: { type: 'string', description: 'Traduction française naturelle' },
        },
        required: ['ko', 'fr'],
      },
    },
    teaser_next: {
      type: 'string',
      description: "Teaser d'une phrase (en français) pour l'épisode de demain — le cliffhanger",
    },
    try_today: {
      type: 'array',
      description: "1 à 2 expressions du texte à essayer aujourd'hui en situation réelle",
      items: {
        type: 'object',
        properties: {
          ko: { type: 'string' },
          fr: { type: 'string' },
          contexte_usage: { type: 'string', description: 'Où/avec qui l’utiliser (ex : au café)' },
        },
        required: ['ko', 'fr', 'contexte_usage'],
      },
    },
  },
  required: ['title', 'sentences', 'teaser_next', 'try_today'],
} as const;

function fewshot(): string {
  return readFileSync(resolve(__dirname, '../assets/fewshot-haeyo.md'), 'utf8');
}

const COMMON_RULES = `- TRÈS PEU de virgules (les LLM en mettent trop : c'est le marqueur n°1 du coréen artificiel).
- Vocabulaire courant uniquement. Si un mot n'est pas dans le vocabulaire des niveaux TOPIK 1-3,
  reformule avec un mot plus simple — SAUF pour les mots cibles imposés.
- Pas de mots rares, littéraires ou datés (서적 → 책).

STRUCTURE :
- 300 à 400 mots au total, découpés en phrases (une phrase par élément du tableau).
- Chaque mot cible imposé apparaît AU MOINS 3 FOIS, dans des contextes différents.
- Le texte doit être intéressant en soi — quelque chose qu'on lirait même en français.
- Termine sur une note qui donne envie de connaître la suite.`;

function systemFor(register: 'haeyo' | 'journalistique'): string {
  const intro = `Tu écris l'épisode du jour de Molago : un texte quotidien en coréen pour un Français
qui vit à Séoul depuis 8 ans (niveau ~TOPIK 3, ~3000-5000 mots). Il lira ce texte demain matin
avec son premier café, en 4-6 minutes.

RÈGLES DE LANGUE ABSOLUES :`;
  if (register === 'journalistique') {
    return `${intro}
- Brève d'actualité en style journalistique LÉGER : phrases déclaratives en -다/-이다, claires et
  courtes. Pas de jargon administratif, pas de nominalisations empilées.
- Ton d'un chroniqueur qui explique l'actu à un ami curieux, pas d'une dépêche d'agence.
- Le vocabulaire sino-coréen utile (경제, 정부, 발표…) est le bienvenu quand il est courant.
${COMMON_RULES}`;
  }
  return `${intro}
- 해요체 tout du long, ton de conteur qui parle à un ami. JAMAIS 당신. JAMAIS de 합쇼체 hors dialogue rapporté.
- Phrases COURTES qui finissent par le verbe. Style oral, pas style de rédaction.
- Contractions réelles du coréen parlé : 근데, 그게, 이따가, -는 거예요, -잖아요.
${COMMON_RULES}`;
}

export async function generateEpisode(opts: {
  series: Series;
  episodeNumber: number;
  previousSummary: string | null;
  newItems: TargetItem[];
  reviewItems: TargetItem[];
}): Promise<{ episode: GeneratedEpisode; usage: LlmUsage }> {
  const bible = opts.series.series_bible;
  const arc = bible?.arc?.find((a) => a.episode === opts.episodeNumber);
  const system = systemFor(opts.series.register);

  const user = `${opts.series.register === 'haeyo' ? fewshot() : ''}

---

## Série en cours : « ${opts.series.title} » (${opts.series.kind}, épisode ${opts.episodeNumber})

Synopsis : ${opts.series.synopsis}
${bible ? `Personnages : ${bible.characters.map((c) => `${c.name_ko} (${c.description})`).join(' · ')}
Lieux : ${bible.places.join(', ')}` : ''}
${opts.previousSummary ? `Résumé de l'épisode précédent : ${opts.previousSummary}` : "C'est le premier épisode."}
${arc ? `Ce que cet épisode doit raconter : ${arc.summary}
Cliffhanger de fin : ${arc.cliffhanger}` : ''}

## Mots cibles NOUVEAUX (chacun ≥ 3 fois, contextes variés) :
${opts.newItems.map((i) => `- ${i.lemma}${i.gloss_fr ? ` (${i.gloss_fr})` : ''}`).join('\n')}

## Mots en RÉVISION à réutiliser naturellement (1-2 fois chacun) :
${opts.reviewItems.length ? opts.reviewItems.map((i) => `- ${i.lemma}${i.gloss_fr ? ` (${i.gloss_fr})` : ''}`).join('\n') : '(aucun)'}

Écris l'épisode maintenant.`;

  const { data, usage } = await llmJson<GeneratedEpisode>({
    system,
    user,
    schema: EPISODE_SCHEMA as unknown as Record<string, unknown>,
    maxTokens: 8000,
  });
  return { episode: data, usage };
}

/** Réécriture ciblée : on renvoie la liste des lemmes intrus au LLM. */
export async function rewriteEpisode(opts: {
  episode: GeneratedEpisode;
  intruders: { lemma: string; count: number }[];
  missingTargets: string[];
  register?: 'haeyo' | 'journalistique';
}): Promise<{ episode: GeneratedEpisode; usage: LlmUsage }> {
  const user = `Voici un épisode déjà écrit :

${opts.episode.sentences.map((s) => s.ko).join('\n')}

PROBLÈMES DÉTECTÉS PAR L'ANALYSE MORPHOLOGIQUE :
${opts.intruders.length ? `Ces mots sont trop difficiles pour le lecteur — remplace-les par des synonymes plus simples (niveau TOPIK 1-3) ou reformule les phrases concernées :
${opts.intruders.map((i) => `- ${i.lemma} (${i.count}×)`).join('\n')}` : ''}
${opts.missingTargets.length ? `Ces mots cibles n'apparaissent pas assez (minimum 3 fois chacun, contextes variés) :
${opts.missingTargets.map((l) => `- ${l}`).join('\n')}` : ''}

Réécris l'épisode en corrigeant UNIQUEMENT ces problèmes. Garde l'histoire, le ton et le registre,
les phrases courtes. Rends l'épisode complet corrigé (avec traductions FR, titre, teaser, try_today).`;

  const { data, usage } = await llmJson<GeneratedEpisode>({
    system: systemFor(opts.register ?? 'haeyo'),
    user,
    schema: EPISODE_SCHEMA as unknown as Record<string, unknown>,
    maxTokens: 8000,
  });
  return { episode: data, usage };
}
