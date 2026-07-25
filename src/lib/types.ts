// Types partagés app + pipeline (miroir du schéma supabase/migrations/001_init.sql)

export type LexemeKind = 'word' | 'chunk';
export type LexemeState = 'unknown' | 'seen' | 'known';
export type SeriesKind = 'feuilleton' | 'actu' | 'chronique';
export type Register = 'haeyo' | 'journalistique';
export type EpisodeStatus = 'generating' | 'ready' | 'failed' | 'read';
export type TokenRole = 'new' | 'review';

export interface Lexeme {
  id: string;
  lemma: string;
  pos: string;
  kind: LexemeKind;
  freq_rank: number | null;
  nikl_grade: 'A' | 'B' | 'C' | null;
  hanja: string | null;
  hanja_family: HanjaFamily | null;
  gloss_fr: string | null;
  krdict_id: string | null;
  krdict_cache: unknown;
  tags: string[];
}

export interface HanjaFamily {
  char: string;            // ex : '約'
  reading: string;         // ex : '약'
  meaning_fr: string;      // ex : 'promettre, lier'
  members: { lemma: string; hanja: string; gloss_fr: string }[];
}

export interface LexemeStateRow {
  lexeme_id: string;
  state: LexemeState;
  source: string;
  stability: number | null;
  difficulty: number | null;
  due_at: string | null;
  last_review_at: string | null;
  reps: number;
  lapses: number;
  exposures: number;
  exposures_since_tap: number;
  exposure_days: string[];
}

export interface Series {
  id: string;
  title: string;
  kind: SeriesKind;
  register: Register;
  status: 'active' | 'terminee';
  synopsis: string;
  series_bible: SeriesBible | null;
}

export interface SeriesBible {
  characters: { name_ko: string; name_fr: string; description: string }[];
  places: string[];
  proper_nouns: string[];      // allowlist pour le vérificateur de couverture
  arc: { episode: number; summary: string; cliffhanger: string }[];
  episodes_planned: number;
}

export interface Episode {
  id: string;
  series_id: string | null;
  brief_date: string;          // YYYY-MM-DD
  episode_number: number;
  title: string;
  teaser_next: string | null;
  status: EpisodeStatus;
  word_count: number | null;
  est_read_min: number | null;
  coverage_pct: number | null;
  audio_path: string | null;
  audio_duration_ms: number | null;
  quiz: QuizItem[] | null;
  try_today: TryToday[] | null;
  generation_meta: Record<string, unknown> | null;
  read_at: string | null;
}

export interface Sentence {
  id: string;
  episode_id: string;
  idx: number;
  text_ko: string;
  translation_fr: string;
  audio_start_ms: number | null;
  audio_end_ms: number | null;
  tokens: TokenSpan[];
}

// Span en offsets de caractères dans text_ko.
export interface TokenSpan {
  s: number;                   // début (inclus)
  e: number;                   // fin (exclue)
  surface: string;
  lemma: string;
  pos: string;
  lexeme_id?: string;
  role?: TokenRole;
  masked?: boolean;
}

export interface EpisodeLexeme {
  episode_id: string;
  lexeme_id: string;
  role: TokenRole;
  occurrences: number;
  gloss_fr: string;
  gloss_source: 'krdict' | 'unverified';
  collocation: string | null;
  krdict_sense: unknown;
  hanja_panel: HanjaFamily | null;
}

export interface QuizItem {
  sentence_idx: number;
  blank_start: number;
  blank_end: number;
  answer_lexeme_id: string;
  answer_surface: string;
  distractors: string[];       // 3 formes de surface plausibles
}

export interface TryToday {
  ko: string;
  fr: string;
  contexte_usage: string;      // « au café », « avec le gardien »…
}

export type AppEventType =
  | 'tap_gloss'
  | 'hanja_open'
  | 'quiz_answer'
  | 'episode_completed'
  | 'flag_awkward'
  | 'audio_replay'
  | 'mask_revealed_early';

export interface AppEvent {
  type: AppEventType;
  episode_id?: string;
  sentence_id?: string;
  lexeme_id?: string;
  payload?: Record<string, unknown>;
}
