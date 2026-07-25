'use client';

import { useMemo, useState } from 'react';
import type { QuizItem, Sentence } from '@/lib/types';
import styles from './ClozeQuiz.module.css';

interface Props {
  quiz: QuizItem[];
  sentences: Sentence[];
  onAnswer: (item: QuizItem, correct: boolean) => void;
  onDone: () => void;
}

// Micro-quiz de clôture : 3-5 cloze sur les phrases mêmes du texte.
// Correction immédiate, pas de note, pas de score (P5/P8).
export default function ClozeQuiz({ quiz, sentences, onAnswer, onDone }: Props) {
  const [index, setIndex] = useState(0);
  const [picked, setPicked] = useState<string | null>(null);

  const current = quiz[index];
  const sentence = sentences[current?.sentence_idx ?? 0];

  const choices = useMemo(() => {
    if (!current) return [];
    const all = [current.answer_surface, ...current.distractors];
    // Mélange stable par question (l'ordre ne doit pas bouger entre re-renders).
    return all
      .map((c, i) => ({ c, key: hash(`${current.answer_lexeme_id}:${c}:${i}`) }))
      .sort((a, b) => a.key - b.key)
      .map((x) => x.c);
  }, [current]);

  if (!current || !sentence) return null;

  const before = sentence.text_ko.slice(0, current.blank_start);
  const after = sentence.text_ko.slice(current.blank_end);
  const answered = picked !== null;
  const isCorrect = picked === current.answer_surface;

  const pick = (choice: string) => {
    if (answered) return;
    setPicked(choice);
    onAnswer(current, choice === current.answer_surface);
  };

  const next = () => {
    setPicked(null);
    if (index + 1 < quiz.length) {
      setIndex(index + 1);
    } else {
      onDone();
    }
  };

  return (
    <section className={styles.quiz}>
      <p className={styles.counter}>{index + 1} / {quiz.length}</p>
      <p className={styles.sentence}>
        {before}
        <span className={`${styles.blank} ${answered ? (isCorrect ? styles.blankCorrect : styles.blankWrong) : ''}`}>
          {answered ? current.answer_surface : '＿＿＿'}
        </span>
        {after}
      </p>
      <div className={styles.choices}>
        {choices.map((choice) => {
          let cls = styles.choice;
          if (answered && choice === current.answer_surface) cls += ` ${styles.correct}`;
          else if (answered && choice === picked) cls += ` ${styles.wrong}`;
          return (
            <button key={choice} className={cls} onClick={() => pick(choice)} disabled={answered}>
              {choice}
            </button>
          );
        })}
      </div>
      {answered && (
        <button className={styles.next} onClick={next}>
          {index + 1 < quiz.length ? 'Suivant' : 'Terminer'}
        </button>
      )}
    </section>
  );
}

function hash(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) | 0;
  return h;
}
