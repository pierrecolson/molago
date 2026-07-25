/**
 * Quiz cloze construit DÉTERMINISTIQUEMENT sur les phrases mêmes du texte
 * (récupération active déguisée, P5). Pas de LLM : le trou est un span cible,
 * les distracteurs sont des lexèmes de même POS et de bande de fréquence proche.
 *
 * Seuls les tokens nominaux/adverbiaux (NNG, NNP, NR, MAG) sont clozés : leur
 * surface est proche du lemme, donc les distracteurs (lemmes) restent plausibles.
 * Les verbes conjugués feraient des distracteurs agrammaticaux.
 */
import { db } from '../lib/db';
import type { QuizItem } from '../../src/lib/types';
import type { AnnotatedSentence } from './annotate';

const MAX_QUESTIONS = 5;
const MIN_QUESTIONS = 3;
const CLOZABLE_POS = ['NNG', 'NNP', 'NR', 'MAG'];

export async function buildQuiz(opts: {
  annotated: AnnotatedSentence[];
  targetLexemeIds: Set<string>;
}): Promise<QuizItem[]> {
  // Candidats : première occurrence de chaque cible dans une phrase, POS clozable.
  const candidates: {
    sentence_idx: number;
    lexeme_id: string;
    s: number;
    e: number;
    surface: string;
    pos: string;
  }[] = [];
  const usedLexemes = new Set<string>();
  const usedSentences = new Set<number>();

  opts.annotated.forEach((sentence, idx) => {
    for (const token of sentence.tokens) {
      if (!token.lexeme_id || !opts.targetLexemeIds.has(token.lexeme_id)) continue;
      if (usedLexemes.has(token.lexeme_id) || usedSentences.has(idx)) continue;
      if (!CLOZABLE_POS.some((p) => token.pos.startsWith(p))) continue;
      candidates.push({
        sentence_idx: idx,
        lexeme_id: token.lexeme_id,
        s: token.s,
        e: token.e,
        surface: token.surface,
        pos: token.pos,
      });
      usedLexemes.add(token.lexeme_id);
      usedSentences.add(idx);
    }
  });

  const picked = candidates.slice(0, MAX_QUESTIONS);
  if (picked.length < MIN_QUESTIONS) {
    // Trop peu de cibles clozables : on accepte un quiz plus court (jamais 0 forcé).
  }

  const quiz: QuizItem[] = [];
  for (const c of picked) {
    // Rang de fréquence de la réponse pour choisir des distracteurs plausibles.
    const { data: answerLex } = await db()
      .from('lexemes')
      .select('lemma, freq_rank, pos')
      .eq('id', c.lexeme_id)
      .single();
    const rank = answerLex?.freq_rank ?? 2500;

    const { data: pool } = await db()
      .from('lexemes')
      .select('lemma')
      .eq('kind', 'word')
      .like('pos', `${c.pos.slice(0, 3)}%`)
      .gte('freq_rank', Math.max(1, rank - 700))
      .lte('freq_rank', rank + 700)
      .neq('id', c.lexeme_id)
      .limit(60);

    const distractors = shuffle((pool ?? []).map((p) => p.lemma).filter((l) => l !== answerLex?.lemma))
      .slice(0, 3);
    if (distractors.length < 3) continue; // pas assez de matière : question sautée

    quiz.push({
      sentence_idx: c.sentence_idx,
      blank_start: c.s,
      blank_end: c.e,
      answer_lexeme_id: c.lexeme_id,
      answer_surface: c.surface,
      distractors,
    });
  }
  return quiz;
}

function shuffle<T>(arr: T[]): T[] {
  const copy = [...arr];
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}
