-- Molago V1 Database Schema
-- Run in Supabase SQL Editor to create all tables

-- ===================== WORDS =====================
CREATE TABLE words (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  korean text NOT NULL UNIQUE,
  romanization text NOT NULL DEFAULT '',
  definition text NOT NULL DEFAULT '',
  part_of_speech text NOT NULL DEFAULT '',
  origin_type text NOT NULL DEFAULT '',
  literal_meaning text NOT NULL DEFAULT '',
  nuances text NOT NULL DEFAULT '',
  usage text NOT NULL DEFAULT 'mid' CHECK (usage IN ('high', 'mid', 'low')),
  raw_llm_response jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_words_korean ON words(korean);
CREATE INDEX idx_words_created_at ON words(created_at DESC);

-- ===================== MORPHEMES =====================
CREATE TABLE morphemes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  korean text NOT NULL,
  hanja text NOT NULL DEFAULT '',
  meaning text NOT NULL DEFAULT '',
  origin_type text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(korean, hanja)
);

CREATE INDEX idx_morphemes_korean ON morphemes(korean);

-- ===================== WORD ↔ MORPHEME JUNCTION =====================
CREATE TABLE word_morphemes (
  word_id uuid NOT NULL REFERENCES words(id) ON DELETE CASCADE,
  morpheme_id uuid NOT NULL REFERENCES morphemes(id) ON DELETE CASCADE,
  position int NOT NULL DEFAULT 0,
  PRIMARY KEY (word_id, morpheme_id)
);

-- ===================== EXAMPLES =====================
CREATE TABLE examples (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  word_id uuid NOT NULL REFERENCES words(id) ON DELETE CASCADE,
  korean_sentence text NOT NULL DEFAULT '',
  english_translation text NOT NULL DEFAULT '',
  context text NOT NULL DEFAULT ''
);

CREATE INDEX idx_examples_word_id ON examples(word_id);

-- ===================== UPDATED_AT TRIGGER =====================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER words_updated_at
  BEFORE UPDATE ON words
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();
