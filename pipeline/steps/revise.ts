/**
 * Passe « relecteur natif sévère » (P9) : traque le 번역투, les dérives de registre,
 * les collocations approximatives et la ponctuation non coréenne. Produit aussi la
 * collocation du glossaire pour chaque item cible (le chunk réel du texte).
 * La sortie est RE-VÉRIFIÉE (couverture) par l'appelant : en cas d'échec, on garde
 * la version pré-révision (déjà acceptée).
 */
import { llmJson, LlmUsage } from '../lib/llm';
import type { GeneratedEpisode, TargetItem } from './generate';

const REVISE_SCHEMA = {
  type: 'object',
  properties: {
    sentences: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          ko: { type: 'string' },
          fr: { type: 'string' },
        },
        required: ['ko', 'fr'],
      },
    },
    collocations: {
      type: 'array',
      description: 'Pour chaque item cible : la collocation/le chunk tel qu’utilisé dans le texte',
      items: {
        type: 'object',
        properties: {
          lemma: { type: 'string' },
          collocation: { type: 'string', description: 'Ex : « 약속을 잡다 » — le chunk complet du texte' },
        },
        required: ['lemma', 'collocation'],
      },
    },
  },
  required: ['sentences', 'collocations'],
} as const;

const REVISER_SYSTEM = `Tu es un relecteur coréen natif sévère. Tu reçois un texte destiné à un
apprenant et tu corriges UNIQUEMENT ce qui sonne artificiel, sans changer l'histoire ni le niveau :

1. 번역투 (translationese) : calques de l'anglais, pronoms sujets superflus, passifs artificiels.
2. Registre : 해요체 constant (sauf dialogue rapporté justifié). Jamais 당신. Pas de 문어체.
3. Ponctuation : retire les virgules superflues (les LLM en mettent 2× trop). Phrases courtes.
4. Collocations : remplace toute combinaison inhabituelle par la collocation que disent
   vraiment les gens (사진을 찍다, 약속을 잡다…).
5. Vocabulaire daté ou littéraire → le mot courant.

Ne simplifie pas, ne complexifie pas : corrige la naturalité. Garde le même nombre de phrases
autant que possible. Mets à jour la traduction française si la phrase change.`;

export async function reviseEpisode(opts: {
  episode: GeneratedEpisode;
  targetItems: TargetItem[];
}): Promise<{ sentences: { ko: string; fr: string }[]; collocations: Map<string, string>; usage: LlmUsage }> {
  const user = `Texte à relire (une phrase par ligne, avec sa traduction) :

${opts.episode.sentences.map((s) => `${s.ko}\n→ ${s.fr}`).join('\n\n')}

Items cibles dont il faut extraire la collocation réelle du texte :
${opts.targetItems.map((i) => `- ${i.lemma}`).join('\n')}

Rends le texte corrigé et les collocations.`;

  const { data, usage } = await llmJson<{
    sentences: { ko: string; fr: string }[];
    collocations: { lemma: string; collocation: string }[];
  }>({
    system: REVISER_SYSTEM,
    user,
    schema: REVISE_SCHEMA as unknown as Record<string, unknown>,
    maxTokens: 8000,
  });

  return {
    sentences: data.sentences,
    collocations: new Map(data.collocations.map((c) => [c.lemma, c.collocation])),
    usage,
  };
}
