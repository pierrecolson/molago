// ===================== DATABASE ROW TYPES =====================

export interface WordRow {
  id: string;
  korean: string;
  romanization: string;
  definition: string;
  part_of_speech: string;
  origin_type: string;
  literal_meaning: string;
  nuances: string;
  usage: 'high' | 'mid' | 'low';
  raw_llm_response: Record<string, unknown> | null;
  created_at: string;
  updated_at: string;
}

export interface MorphemeRow {
  id: string;
  korean: string;
  hanja: string;
  meaning: string;
  origin_type: string;
  created_at: string;
}

export interface WordMorphemeRow {
  word_id: string;
  morpheme_id: string;
  position: number;
}

export interface ExampleRow {
  id: string;
  word_id: string;
  korean_sentence: string;
  english_translation: string;
  context: string;
}

// ===================== FRONTEND DISPLAY TYPES =====================

export interface Morpheme {
  korean: string;
  hanja: string;
  meaning: string;
}

export interface FamilyWord {
  korean: string;
  hanja: string;
  meaning: string;
  connection: string;
}

export interface Example {
  korean: string;
  english: string;
  context: string;
}

export interface Word {
  id: string;
  korean: string;
  romanization: string;
  definition: string;
  literal_meaning: string;
  part_of_speech: string;
  origin_type: string;
  usage: 'high' | 'mid' | 'low';
  nuances: string;
  created_at: string;
  morphemes: Morpheme[];
  family: FamilyWord[];
  examples: Example[];
}

// ===================== N8N RESPONSE TYPES =====================

export interface Suggestion {
  korean: string;
  definition: string;
}

export interface AddWordSuccessResponse {
  word: Word;
}

export interface AddWordSuggestionResponse {
  suggestions: Suggestion[];
}

export type AddWordResponse = AddWordSuccessResponse | AddWordSuggestionResponse;

export function isSuggestionResponse(
  res: AddWordResponse
): res is AddWordSuggestionResponse {
  return 'suggestions' in res;
}
