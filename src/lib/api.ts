import supabase from './supabase';
import { Word, Morpheme, FamilyWord, Example, AddWordResponse } from './types';
import { mockWords } from './mock-data';

const useMock = !supabase;

// ===================== ERROR TYPES =====================

export class ApiError extends Error {
  type: 'too_long' | 'rate_limited' | 'unauthorized' | 'server_error' | 'network_error';
  userMessage: string;

  constructor(
    type: ApiError['type'],
    userMessage: string,
    originalMessage?: string
  ) {
    super(originalMessage ?? userMessage);
    this.type = type;
    this.userMessage = userMessage;
  }
}

// ===================== READ OPERATIONS (Supabase) =====================

export async function fetchWords(): Promise<Word[]> {
  if (useMock) return mockWords;

  const { data, error } = await supabase!
    .from('words')
    .select('*')
    .order('created_at', { ascending: false });

  if (error) throw error;
  if (!data) return [];

  return data.map((row) => ({
    id: row.id,
    korean: row.korean,
    romanization: row.romanization,
    definition: row.definition,
    literal_meaning: row.literal_meaning,
    part_of_speech: row.part_of_speech,
    origin_type: row.origin_type,
    usage: row.usage,
    nuances: row.nuances,
    morphemes: [],
    family: [],
    examples: [],
  }));
}

export async function fetchWordById(id: string): Promise<Word | null> {
  if (useMock) {
    return mockWords.find((w) => w.id === id) ?? null;
  }

  // Fetch word
  const { data: word, error: wordError } = await supabase!
    .from('words')
    .select('*')
    .eq('id', id)
    .single();

  if (wordError || !word) return null;

  // Fetch morphemes via junction table
  const { data: wordMorphemes } = await supabase!
    .from('word_morphemes')
    .select('position, morphemes(korean, hanja, meaning)')
    .eq('word_id', id)
    .order('position');

  const morphemes: Morpheme[] = (wordMorphemes ?? []).map((wm: Record<string, unknown>) => {
    const m = wm.morphemes as Record<string, string>;
    return {
      korean: m.korean,
      hanja: m.hanja,
      meaning: m.meaning,
    };
  });

  // Fetch examples (alias DB columns to match frontend Example interface)
  const { data: examplesData } = await supabase!
    .from('examples')
    .select('korean:korean_sentence, english:english_translation, context')
    .eq('word_id', id);

  const examples: Example[] = (examplesData ?? []) as Example[];

  // Extract family from raw_llm_response
  const rawResponse = word.raw_llm_response as Record<string, unknown> | null;
  const familyData = (rawResponse?.word_family ?? []) as Array<Record<string, string>>;
  const family: FamilyWord[] = familyData.map((f) => ({
    korean: f.korean,
    hanja: f.hanja,
    meaning: f.meaning,
    connection: f.connection,
  }));

  return {
    id: word.id,
    korean: word.korean,
    romanization: word.romanization,
    definition: word.definition,
    literal_meaning: word.literal_meaning,
    part_of_speech: word.part_of_speech,
    origin_type: word.origin_type,
    usage: word.usage,
    nuances: word.nuances,
    morphemes,
    family,
    examples,
  };
}

// ===================== WRITE OPERATIONS (via API routes) =====================

async function handleApiError(res: Response): Promise<never> {
  let errorData: { error?: string; message?: string } = {};
  try {
    errorData = await res.json();
  } catch {
    // non-JSON response
  }

  const errorCode = errorData.error ?? '';

  if (res.status === 400 && errorCode === 'too_long') {
    throw new ApiError('too_long', 'Word is too long (max 50 characters).');
  }

  if (res.status === 429) {
    throw new ApiError('rate_limited', 'Too many requests. Please wait a moment.');
  }

  if (res.status === 401) {
    throw new ApiError('unauthorized', 'Something went wrong. Please try again.');
  }

  throw new ApiError(
    'server_error',
    "Couldn't get the definition. Please try again."
  );
}

export async function addWord(korean: string): Promise<AddWordResponse> {
  let res: Response;

  try {
    res = await fetch('/api/add-word', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ word: korean }),
    });
  } catch {
    throw new ApiError('network_error', 'No connection. Check your internet and try again.');
  }

  if (!res.ok) {
    return handleApiError(res);
  }

  return res.json();
}

export async function deleteWord(wordId: string): Promise<void> {
  let res: Response;

  try {
    res = await fetch('/api/delete-word', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ word_id: wordId }),
    });
  } catch {
    throw new ApiError('network_error', 'No connection. Check your internet and try again.');
  }

  if (!res.ok) {
    let errorData: { error?: string; message?: string } = {};
    try {
      errorData = await res.json();
    } catch {
      // non-JSON response
    }

    if (res.status === 401) {
      throw new ApiError('unauthorized', 'Something went wrong. Please try again.');
    }

    throw new ApiError(
      'server_error',
      errorData.message ?? "Couldn't delete. Try again."
    );
  }
}
