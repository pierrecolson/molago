'use client';

import { useState, useEffect, useCallback } from 'react';
import { X, Lightning } from '@phosphor-icons/react';
import { Word } from '@/lib/types';
import styles from './QuizSheet.module.css';

interface QuizSheetProps {
  words: Word[];
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

interface QuizQuestion {
  word: Word;
  options: string[];
  correctIndex: number;
}

type QuizPhase = 'start' | 'question' | 'feedback' | 'results';

function shuffleArray<T>(array: T[]): T[] {
  const shuffled = [...array];
  for (let i = shuffled.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
  }
  return shuffled;
}

function generateQuiz(words: Word[]): QuizQuestion[] {
  if (words.length < 4) return [];

  const shuffled = shuffleArray(words);
  const selected = shuffled.slice(0, Math.min(10, shuffled.length));

  return selected.map((word) => {
    const otherDefs = words
      .filter((w) => w.id !== word.id && w.definition !== word.definition)
      .map((w) => w.definition);
    const distractors = shuffleArray(otherDefs).slice(0, 3);
    const options = shuffleArray([word.definition, ...distractors]);
    const correctIndex = options.indexOf(word.definition);

    return { word, options, correctIndex };
  });
}

function getScoreMessage(score: number, total: number): string {
  const pct = score / total;
  if (pct === 1) return 'Perfect!';
  if (pct >= 0.7) return 'Great job!';
  if (pct >= 0.4) return 'Keep practicing!';
  return "Don't give up!";
}

export default function QuizSheet({ words, open, onOpenChange }: QuizSheetProps) {
  const [phase, setPhase] = useState<QuizPhase>('start');
  const [questions, setQuestions] = useState<QuizQuestion[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [selectedAnswer, setSelectedAnswer] = useState<number | null>(null);
  const [score, setScore] = useState(0);

  // Lock background scroll when sheet is open
  useEffect(() => {
    if (open) {
      const scrollY = window.scrollY;
      document.documentElement.style.position = 'fixed';
      document.documentElement.style.top = `-${scrollY}px`;
      document.documentElement.style.width = '100%';
    } else {
      const top = document.documentElement.style.top;
      document.documentElement.style.position = '';
      document.documentElement.style.top = '';
      document.documentElement.style.width = '';
      if (top) {
        window.scrollTo(0, parseInt(top, 10) * -1);
      }
    }
  }, [open]);

  const startQuiz = useCallback(() => {
    const q = generateQuiz(words);
    setQuestions(q);
    setCurrentIndex(0);
    setScore(0);
    setSelectedAnswer(null);
    setPhase('question');
  }, [words]);

  const handleSelect = useCallback((index: number) => {
    if (selectedAnswer !== null) return;
    setSelectedAnswer(index);
    if (index === questions[currentIndex].correctIndex) {
      setScore((s) => s + 1);
    }
    setPhase('feedback');
  }, [selectedAnswer, questions, currentIndex]);

  const handleNext = useCallback(() => {
    if (currentIndex + 1 >= questions.length) {
      setPhase('results');
    } else {
      setCurrentIndex((i) => i + 1);
      setSelectedAnswer(null);
      setPhase('question');
    }
  }, [currentIndex, questions.length]);

  const handleClose = useCallback(() => {
    onOpenChange(false);
    setPhase('start');
    setSelectedAnswer(null);
  }, [onOpenChange]);

  const current = questions[currentIndex];

  return (
    <>
      <div
        className={`${styles.backdrop} ${open ? styles.backdropOpen : ''}`}
        onClick={handleClose}
      />

      <div className={`${styles.sheet} ${open ? styles.sheetOpen : ''}`}>
        <div className={styles.sheetHeader}>
          <span className={styles.sheetTitle}>Practice</span>
          <button className={styles.closeBtn} onClick={handleClose}>
            <X weight="bold" />
          </button>
        </div>

        <div className={styles.body}>
          {/* START */}
          {phase === 'start' && (
            <>
              <div className={styles.startIcon}>
                <Lightning size={40} weight="fill" />
              </div>
              <div className={styles.startTitle}>Practice Quiz</div>
              <div className={styles.startSubtitle}>
                Test your knowledge of {words.length} word{words.length === 1 ? '' : 's'}
              </div>
              <button className={styles.primaryBtn} onClick={startQuiz}>
                Start
              </button>
            </>
          )}

          {/* QUESTION & FEEDBACK */}
          {(phase === 'question' || phase === 'feedback') && current && (
            <>
              <div className={styles.progressText}>
                Question {currentIndex + 1} of {questions.length}
              </div>
              <div className={styles.progressBar}>
                <div
                  className={styles.progressFill}
                  style={{ width: `${((currentIndex + 1) / questions.length) * 100}%` }}
                />
              </div>

              <div className={styles.koreanWord}>{current.word.korean}</div>
              <div className={styles.romanization}>{current.word.romanization}</div>

              <div className={styles.options}>
                {current.options.map((opt, i) => {
                  let optClass = styles.option;
                  if (phase === 'feedback') {
                    if (i === current.correctIndex) {
                      optClass += ` ${styles.optionCorrect}`;
                    } else if (i === selectedAnswer) {
                      optClass += ` ${styles.optionWrong}`;
                    } else {
                      optClass += ` ${styles.optionDimmed}`;
                    }
                  }
                  return (
                    <button
                      key={i}
                      className={optClass}
                      onClick={() => handleSelect(i)}
                      disabled={phase === 'feedback'}
                    >
                      {opt}
                    </button>
                  );
                })}
              </div>

              {phase === 'feedback' && (
                <button className={styles.primaryBtn} onClick={handleNext}>
                  {currentIndex + 1 >= questions.length ? 'See Results' : 'Next'}
                </button>
              )}
            </>
          )}

          {/* RESULTS */}
          {phase === 'results' && (
            <>
              <div className={styles.scoreDisplay}>
                {score} / {questions.length}
              </div>
              <div className={styles.scoreMessage}>
                {getScoreMessage(score, questions.length)}
              </div>
              <button className={styles.primaryBtn} onClick={startQuiz}>
                Try Again
              </button>
              <button className={styles.secondaryBtn} onClick={handleClose}>
                Done
              </button>
            </>
          )}
        </div>
      </div>
    </>
  );
}
