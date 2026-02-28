import supabase from './supabase';
import { Word, Morpheme, FamilyWord, Example, AddWordResponse } from './types';
import { mockWords } from './mock-data';

const useMock = !supabase;

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

  // Fetch examples
  const { data: examplesData } = await supabase!
    .from('examples')
    .select('korean_sentence, english_translation, context')
    .eq('word_id', id);

  const examples: Example[] = (examplesData ?? []).map((ex) => ({
    korean: ex.korean_sentence,
    english: ex.english_translation,
    context: ex.context,
  }));

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

// ===================== WRITE OPERATIONS (n8n webhooks) =====================

const addWordUrl = process.env.NEXT_PUBLIC_N8N_ADD_WORD_URL;
const deleteWordUrl = process.env.NEXT_PUBLIC_N8N_DELETE_WORD_URL;

export async function addWord(korean: string): Promise<AddWordResponse> {
  if (!addWordUrl) {
    throw new Error('N8N add word webhook URL not configured');
  }

  const res = await fetch(addWordUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ word: korean }),
  });

  if (!res.ok) {
    throw new Error(`Failed to add word: ${res.statusText}`);
  }

  return res.json();
}

export async function deleteWord(wordId: string): Promise<void> {
  if (!deleteWordUrl) {
    throw new Error('N8N delete word webhook URL not configured');
  }

  const res = await fetch(deleteWordUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ word_id: wordId }),
  });

  if (!res.ok) {
    throw new Error(`Failed to delete word: ${res.statusText}`);
  }
}
