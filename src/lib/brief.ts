import { supabaseAdmin } from '@/lib/supabase-server';
import type { Episode, Sentence, Lexeme } from '@/lib/types';

export interface GlossInfo {
  lexeme_id: string;
  lemma: string;
  gloss_fr: string;
  gloss_source: 'krdict' | 'unverified';
  collocation: string | null;
  role: 'new' | 'review';
  hanja: string | null;
}

export interface BriefData {
  episode: Episode;
  sentences: Sentence[];
  glossary: GlossInfo[];
  audioUrl: string | null;
  seriesTitle: string | null;
  totalPlanned: number | null;
}

export function kstToday(): string {
  return new Date(Date.now() + 9 * 3600 * 1000).toISOString().slice(0, 10);
}

/** Charge un brief complet (épisode ready) pour une date. null si absent/non prêt. */
export async function fetchBrief(date: string): Promise<BriefData | null> {
  const db = supabaseAdmin();
  const { data: episode } = await db
    .from('episodes')
    .select('*')
    .eq('brief_date', date)
    .eq('status', 'ready')
    .maybeSingle<Episode>();
  if (!episode) return null;

  const [{ data: sentences }, { data: glossRows }, seriesRes] = await Promise.all([
    db.from('sentences').select('*').eq('episode_id', episode.id).order('idx'),
    db
      .from('episode_lexemes')
      .select('lexeme_id, role, gloss_fr, gloss_source, collocation, lexemes(lemma, hanja)')
      .eq('episode_id', episode.id),
    episode.series_id
      ? db.from('series').select('title, series_bible').eq('id', episode.series_id).single()
      : Promise.resolve({ data: null }),
  ]);

  let audioUrl: string | null = null;
  if (episode.audio_path) {
    const { data: signed } = await db.storage.from('audio').createSignedUrl(episode.audio_path, 6 * 3600);
    audioUrl = signed?.signedUrl ?? null;
  }

  const glossary: GlossInfo[] = (glossRows ?? []).map((g) => {
    const lex = g.lexemes as unknown as Pick<Lexeme, 'lemma' | 'hanja'>;
    return {
      lexeme_id: g.lexeme_id,
      lemma: lex?.lemma ?? '',
      gloss_fr: g.gloss_fr,
      gloss_source: g.gloss_source,
      collocation: g.collocation,
      role: g.role,
      hanja: lex?.hanja ?? null,
    };
  });

  const seriesData = seriesRes.data as { title: string; series_bible: { episodes_planned?: number } | null } | null;

  return {
    episode,
    sentences: (sentences ?? []) as Sentence[],
    glossary,
    audioUrl,
    seriesTitle: seriesData?.title ?? null,
    totalPlanned: seriesData?.series_bible?.episodes_planned ?? null,
  };
}

/** Dernier brief prêt (pour l'état dégradé). */
export async function lastReadyBrief(): Promise<{ brief_date: string; title: string } | null> {
  const { data } = await supabaseAdmin()
    .from('episodes')
    .select('brief_date, title')
    .eq('status', 'ready')
    .order('brief_date', { ascending: false })
    .limit(1)
    .maybeSingle();
  return data ?? null;
}
