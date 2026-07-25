/**
 * FSRS comme planificateur interne invisible (P3).
 * Reconstruit une Card ts-fsrs depuis lexeme_state, applique une note,
 * rend les champs à persister. due_at n'est JAMAIS affiché à l'utilisateur —
 * il ne sert qu'à la sélection du pipeline nocturne.
 */
import { fsrs, createEmptyCard, Rating, State, type Card, type Grade } from 'ts-fsrs';
import type { LexemeStateRow } from './types';

// Rétention cible 0.9 (défaut FSRS) ; pas de fuzz : la « variété » vient des textes.
const scheduler = fsrs();

export type ReviewGrade = 'again' | 'good';

function toCard(row: Pick<LexemeStateRow, 'stability' | 'difficulty' | 'due_at' | 'last_review_at' | 'reps' | 'lapses'>, now: Date): Card {
  if (row.reps === 0 || row.stability === null || row.difficulty === null) {
    return createEmptyCard(now);
  }
  const due = row.due_at ? new Date(row.due_at) : now;
  const lastReview = row.last_review_at ? new Date(row.last_review_at) : undefined;
  return {
    due,
    stability: row.stability,
    difficulty: row.difficulty,
    elapsed_days: 0,
    scheduled_days: lastReview ? Math.max(0, Math.round((due.getTime() - lastReview.getTime()) / 86400000)) : 0,
    learning_steps: 0,
    reps: row.reps,
    lapses: row.lapses,
    state: State.Review,
    last_review: lastReview,
  };
}

export interface FsrsFields {
  stability: number;
  difficulty: number;
  due_at: string;
  last_review_at: string;
  reps: number;
  lapses: number;
}

/** Applique une review FSRS et rend les champs à écrire dans lexeme_state. */
export function reviewLexeme(
  row: Pick<LexemeStateRow, 'stability' | 'difficulty' | 'due_at' | 'last_review_at' | 'reps' | 'lapses'>,
  grade: ReviewGrade,
  now: Date = new Date(),
): FsrsFields {
  const card = toCard(row, now);
  const rating: Grade = grade === 'again' ? Rating.Again : Rating.Good;
  const { card: next } = scheduler.next(card, now, rating);
  return {
    stability: next.stability,
    difficulty: next.difficulty,
    due_at: next.due.toISOString(),
    last_review_at: now.toISOString(),
    reps: next.reps,
    lapses: next.lapses,
  };
}
