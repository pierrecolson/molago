/**
 * Choix/création de la série du jour.
 * Alternance T4 : après un feuilleton (couche native, 해요체), une série « actu »
 * (couche sino-coréenne, style journalistique léger) construite sur de vrais
 * titres RSS — et inversement.
 */
import { db } from '../lib/db';
import { llmJson, LlmUsage } from '../lib/llm';
import { fetchHeadlines } from '../lib/rss';
import type { Series, SeriesBible, SeriesKind } from '../../src/lib/types';

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

const PLANNER_BASE = `Tu conçois des mini-séries pour Molago, le brief matinal en coréen d'un
Français qui vit à Séoul depuis 8 ans. Ses centres d'intérêt : la vie de quartier à Séoul,
l'actualité coréenne et la société, la tech, l'histoire et la culture coréennes.
Il est indifférent à la K-pop et aux dramas romantiques.

Une mini-série = 4 épisodes de 300-400 mots, un par matin, avec un cliffhanger par épisode
(effet Zeigarnik : la raison d'ouvrir l'app demain).`;

const PLANNER_FEUILLETON = `${PLANNER_BASE}
Feuilleton de vie quotidienne : histoires crédibles ancrées dans le Séoul réel (quartiers,
situations, petites tensions du quotidien). Pas de mélodrame : de l'humour sec, de
l'observation, des situations vraies.`;

const PLANNER_ACTU = `${PLANNER_BASE}
Série « fil d'actu » : choisis parmi les titres fournis UN sujet qui peut se suivre sur
4 matins (une situation qui évolue, un dossier qu'on creuse, un phénomène qu'on explique
sous 4 angles). Chaque épisode est une brève de chronique journalistique légère. Le
« cliffhanger » est ici une vraie question ouverte (« que va décider X demain ? »).
Pas de personnages fictifs : characters liste les acteurs réels du dossier (institutions,
entreprises, personnes publiques) avec leur nom coréen exact.`;

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

  // Alternance : la nouvelle série prend l'autre registre que la précédente (T4).
  const { data: lastSeries } = await db()
    .from('series')
    .select('kind')
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  const nextKind: SeriesKind = lastSeries?.kind === 'feuilleton' ? 'actu' : 'feuilleton';

  let plannerUser = 'Conçois la prochaine mini-série (feuilleton de vie quotidienne à Séoul, 4 épisodes).';
  if (nextKind === 'actu') {
    const headlines = await fetchHeadlines();
    plannerUser = headlines.length
      ? `Titres d'actualité du moment :\n${headlines
          .map((h) => `- [${h.source}] ${h.title}${h.description ? ` — ${h.description}` : ''}`)
          .join('\n')}\n\nConçois la prochaine mini-série « fil d'actu » (4 épisodes) à partir d'UN de ces sujets.`
      : 'Aucun flux disponible : conçois une série « fil d\'actu » sur un phénomène de société coréen durable (4 épisodes).';
  }

  const { data: planned, usage } = await llmJson<PlannedSeries>({
    system: nextKind === 'actu' ? PLANNER_ACTU : PLANNER_FEUILLETON,
    user: plannerUser,
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
      kind: nextKind,
      register: nextKind === 'actu' ? 'journalistique' : 'haeyo',
      status: 'active',
      synopsis: planned.synopsis,
      series_bible: bible,
    })
    .select()
    .single();
  if (insErr) throw new Error(`plan insert: ${insErr.message}`);
  return { series: inserted as Series, usage };
}
