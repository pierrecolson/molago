-- Molago 2.0 — schéma initial
-- À exécuter dans le SQL Editor de Supabase.
-- Mono-utilisateur strict : aucune colonne user_id. RLS activée sans policy anon :
-- toutes les écritures/lectures passent par les routes serveur (service role).

-- ===================== LEXEMES =====================
-- Référentiel lexical : mots ET chunks parlés (P6 — l'unité est le chunk).
CREATE TABLE lexemes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lemma text NOT NULL,
  pos text NOT NULL DEFAULT '',            -- tag Kiwi (NNG, VV…) ou '' pour les chunks
  kind text NOT NULL DEFAULT 'word' CHECK (kind IN ('word', 'chunk')),
  freq_rank int,                           -- rang de fréquence (NIKL 2005), null si absent
  nikl_grade text CHECK (nikl_grade IN ('A', 'B', 'C')),
  hanja text,                              -- ex : '約束' pour 약속
  hanja_family jsonb,                      -- panneau famille pré-calculé, cache
  gloss_fr text,
  krdict_id text,
  krdict_cache jsonb,                      -- réponse krdict brute (cache)
  tags text[] NOT NULL DEFAULT '{}',       -- 'expat','actu','tech','histoire','backchannel'…
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (lemma, pos)
);

CREATE INDEX idx_lexemes_lemma ON lexemes(lemma);
CREATE INDEX idx_lexemes_freq_rank ON lexemes(freq_rank);

-- ===================== LEXEME_STATE =====================
-- Profil lexical : stealth assessment + FSRS. PK = lexeme_id (mono-user).
CREATE TABLE lexeme_state (
  lexeme_id uuid PRIMARY KEY REFERENCES lexemes(id) ON DELETE CASCADE,
  state text NOT NULL CHECK (state IN ('unknown', 'seen', 'known')),
  source text NOT NULL DEFAULT '',         -- 'placement','nikl_prior','tap','quiz','pipeline'
  -- Champs FSRS (planificateur interne invisible — jamais affichés)
  stability float8,
  difficulty float8,
  due_at timestamptz,
  last_review_at timestamptz,
  reps int NOT NULL DEFAULT 0,
  lapses int NOT NULL DEFAULT 0,
  -- Stealth assessment (modèle Kimchi Reader : unknown → seen → known)
  exposures int NOT NULL DEFAULT 0,
  exposures_since_tap int NOT NULL DEFAULT 0,
  exposure_days date[] NOT NULL DEFAULT '{}',
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_lexeme_state_due ON lexeme_state(due_at) WHERE state IN ('seen', 'known');
CREATE INDEX idx_lexeme_state_state ON lexeme_state(state);

-- ===================== SERIES =====================
CREATE TABLE series (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  kind text NOT NULL CHECK (kind IN ('feuilleton', 'actu', 'chronique')),
  register text NOT NULL CHECK (register IN ('haeyo', 'journalistique')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'terminee')),
  synopsis text NOT NULL DEFAULT '',
  -- Bible de série : personnages/lieux (allowlist noms propres pour le vérificateur),
  -- arc prévu de 3–5 épisodes, cliffhangers.
  series_bible jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ===================== EPISODES =====================
CREATE TABLE episodes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  series_id uuid REFERENCES series(id),
  brief_date date NOT NULL UNIQUE,         -- LE brief du jour
  episode_number int NOT NULL DEFAULT 1,
  title text NOT NULL DEFAULT '',
  teaser_next text,                        -- teaser affiché en fin de lecture
  status text NOT NULL DEFAULT 'generating'
    CHECK (status IN ('generating', 'ready', 'failed', 'read')),
  word_count int,
  est_read_min numeric,
  coverage_pct numeric,                    -- couverture lexicale mesurée (kiwi)
  audio_path text,                         -- chemin dans le bucket Storage 'audio'
  audio_duration_ms int,
  quiz jsonb,          -- [{sentence_idx, blank_start, blank_end, answer_lexeme_id, answer_surface, distractors: [text,text,text]}]
  try_today jsonb,     -- [{ko, fr, contexte_usage}] — 1 à 2 chunks à essayer aujourd'hui
  generation_meta jsonb,                   -- prompts, coûts, itérations, couverture avant/après
  created_at timestamptz NOT NULL DEFAULT now(),
  read_at timestamptz
);

CREATE INDEX idx_episodes_brief_date ON episodes(brief_date DESC);

-- ===================== SENTENCES =====================
CREATE TABLE sentences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  episode_id uuid NOT NULL REFERENCES episodes(id) ON DELETE CASCADE,
  idx int NOT NULL,
  text_ko text NOT NULL,
  translation_fr text NOT NULL DEFAULT '',
  audio_start_ms int,                      -- timings karaoké
  audio_end_ms int,
  -- Spans en offsets de caractères dans text_ko :
  -- [{s, e, surface, lemma, pos, lexeme_id?, role?('new'|'review'), masked?}]
  tokens jsonb NOT NULL DEFAULT '[]',
  UNIQUE (episode_id, idx)
);

CREATE INDEX idx_sentences_episode ON sentences(episode_id, idx);

-- ===================== EPISODE_LEXEMES =====================
-- Glossaire par épisode, ancré krdict (P9 — jamais de définitions hallucinées).
CREATE TABLE episode_lexemes (
  episode_id uuid NOT NULL REFERENCES episodes(id) ON DELETE CASCADE,
  lexeme_id uuid NOT NULL REFERENCES lexemes(id),
  role text NOT NULL CHECK (role IN ('new', 'review')),
  occurrences int NOT NULL DEFAULT 0,
  gloss_fr text NOT NULL DEFAULT '',
  gloss_source text NOT NULL DEFAULT 'krdict' CHECK (gloss_source IN ('krdict', 'unverified')),
  collocation text,
  krdict_sense jsonb,
  hanja_panel jsonb,
  PRIMARY KEY (episode_id, lexeme_id)
);

-- ===================== EVENTS =====================
-- Événements d'interaction : la source du stealth assessment.
CREATE TABLE events (
  id bigserial PRIMARY KEY,
  created_at timestamptz NOT NULL DEFAULT now(),
  type text NOT NULL,
  -- 'tap_gloss','hanja_open','quiz_answer','episode_completed',
  -- 'flag_awkward','audio_replay','mask_revealed_early'
  episode_id uuid REFERENCES episodes(id) ON DELETE SET NULL,
  sentence_id uuid REFERENCES sentences(id) ON DELETE SET NULL,
  lexeme_id uuid REFERENCES lexemes(id) ON DELETE SET NULL,
  payload jsonb
);

CREATE INDEX idx_events_type_created ON events(type, created_at DESC);
CREATE INDEX idx_events_lexeme ON events(lexeme_id) WHERE lexeme_id IS NOT NULL;

-- ===================== PLACEMENT =====================
CREATE TABLE placement_responses (
  id bigserial PRIMARY KEY,
  band int NOT NULL,                       -- 1..10 (+ 11 = bande expat)
  lexeme_id uuid NOT NULL REFERENCES lexemes(id),
  known boolean NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ===================== updated_at trigger =====================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER lexeme_state_updated_at
  BEFORE UPDATE ON lexeme_state
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ===================== RLS =====================
-- Activée sans policy anon : seul le service role (routes serveur, pipeline) accède.
ALTER TABLE lexemes ENABLE ROW LEVEL SECURITY;
ALTER TABLE lexeme_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE series ENABLE ROW LEVEL SECURITY;
ALTER TABLE episodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE sentences ENABLE ROW LEVEL SECURITY;
ALTER TABLE episode_lexemes ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE placement_responses ENABLE ROW LEVEL SECURITY;

-- ===================== STORAGE =====================
-- Bucket audio (un mp3 par épisode). Privé : lecture via URL signée côté serveur.
INSERT INTO storage.buckets (id, name, public)
VALUES ('audio', 'audio', false)
ON CONFLICT (id) DO NOTHING;
