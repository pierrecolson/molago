/**
 * Choix/création de la série du jour.
 * J1 : feuilleton seul. J3 : alternance feuilleton / actu (RSS) selon l'arc hebdo.
 */
import { db } from '../lib/db';
import { llmJson, LlmUsage } from '../lib/llm';
import type { Series, SeriesBible } from '../../src/lib/types';

const SERIES_SCHEMA = {
  type: 'object',
  properties: {
    title: { type: 'string', description: 'Titre de la mini-série, en coréen' },
    synopsis: { type: 'string', description: 'Synopsis en français, 2-3 phrases' },
    characters: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          name_ko: { type: 'string' },
          name_fr: { type: 'string' },
          description: { type: 'string', description: 'Une phrase, en français' },
        },
        required: ['name_ko', 'name_fr', 'description'],
      },
    },
    places: { type: 'array', items: { type: 'string' }, description: 'Lieux (noms coréens)' },
    arc: {
      type: 'array',
      description: 'Arc de 4 épisodes : résumé + cliffhanger de chacun',
      items: {
        type: 'object',
        properties: {
          episode: { type: 'integer' },
          summary: { type: 'string', description: 'En français' },
          cliffhanger: { type: 'string', description: 'En français' },
        },
        required: ['episode', 'summary', 'cliffhanger'],
      },
    },
  },
  required: ['title', 'synopsis', 'characters', 'places', 'arc'],
} as const;

interface PlannedSeries {
  title: string;
  synopsis: string;
  characters: SeriesBible['characters'];
  places: string[];
  arc: SeriesBible['arc'];
}

const PLANNER_SYSTEM = `Tu conçois des mini-séries pour Molago, le brief matinal en coréen d'un
Français qui vit à Séoul depuis 8 ans. Ses centres d'intérêt : la vie de quartier à Séoul,
l'actualité coréenne et la société, la tech, l'histoire et la culture coréennes.
Il est indifférent à la K-pop et aux dramas romantiques.

Une mini-série = 4 épisodes de 300-400 mots, un par matin, avec un cliffhanger par épisode
(effet Zeigarnik : la raison d'ouvrir l'app demain). Histoires de vie quotidienne crédibles,
ancrées dans le Séoul réel (quartiers, situations, petites tensions du quotidien).
Pas de mélodrame : de l'humour sec, de l'observation, des situations vraies.`;

export async function planSeries(): Promise<{ series: Series; usage: LlmUsage | null }> {
  // Série active avec des épisodes restants ?
  const { data: active, error } = await db()
    .from('series')
    .select('*')
    .eq('status', 'active')
    .order('created_at', { ascending: false })
    .limit(1);
  if (error) throw new Error(`plan: ${error.message}`);

  if (active && active.length > 0) {
    const series = active[0] as Series;
    const planned = series.series_bible?.episodes_planned ?? 4;
    const { count } = await db()
      .from('episodes')
      .select('id', { count: 'exact', head: true })
      .eq('series_id', series.id);
    if ((count ?? 0) < planned) return { series, usage: null };
    // Arc terminé → clôturer et créer la suivante.
    await db().from('series').update({ status: 'terminee' }).eq('id', series.id);
  }

  const { data: planned, usage } = await llmJson<PlannedSeries>({
    system: PLANNER_SYSTEM,
    user: 'Conçois la prochaine mini-série (feuilleton de vie quotidienne à Séoul, 4 épisodes).',
    schema: SERIES_SCHEMA as unknown as Record<string, unknown>,
    maxTokens: 3000,
  });

  const bible: SeriesBible = {
    characters: planned.characters,
    places: planned.places,
    proper_nouns: [
      ...planned.characters.map((c) => c.name_ko),
      ...planned.places,
    ],
    arc: planned.arc,
    episodes_planned: planned.arc.length,
  };

  const { data: inserted, error: insErr } = await db()
    .from('series')
    .insert({
      title: planned.title,
      kind: 'feuilleton',
      register: 'haeyo',
      status: 'active',
      synopsis: planned.synopsis,
      series_bible: bible,
    })
    .select()
    .single();
  if (insErr) throw new Error(`plan insert: ${insErr.message}`);
  return { series: inserted as Series, usage };
}
