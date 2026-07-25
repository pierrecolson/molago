'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import type { Episode, Sentence, TokenSpan, AppEvent, QuizItem } from '@/lib/types';
import type { GlossInfo } from '@/lib/brief';
import KaraokeReader from '@/components/KaraokeReader';
import GlossSheet from '@/components/GlossSheet';
import ClozeQuiz from '@/components/ClozeQuiz';
import styles from './BriefReader.module.css';

interface Props {
  episode: Episode;
  sentences: Sentence[];
  glossary: GlossInfo[];
  audioUrl: string | null;
  seriesTitle: string | null;
  totalPlanned: number | null;
}

// File d'événements envoyée en batch (sendBeacon à la fermeture, fetch sinon).
function useEventQueue(episodeId: string) {
  const queue = useRef<AppEvent[]>([]);

  const flush = useCallback(() => {
    if (queue.current.length === 0) return;
    const body = JSON.stringify({ events: queue.current });
    queue.current = [];
    if (navigator.sendBeacon) {
      navigator.sendBeacon('/api/events', new Blob([body], { type: 'application/json' }));
    } else {
      fetch('/api/events', { method: 'POST', body, headers: { 'Content-Type': 'application/json' } });
    }
  }, []);

  const push = useCallback(
    (event: Omit<AppEvent, 'episode_id'>) => {
      queue.current.push({ ...event, episode_id: episodeId });
      if (queue.current.length >= 10) flush();
    },
    [episodeId, flush],
  );

  useEffect(() => {
    const onHide = () => flush();
    document.addEventListener('visibilitychange', onHide);
    window.addEventListener('pagehide', onHide);
    const interval = setInterval(flush, 15000);
    return () => {
      document.removeEventListener('visibilitychange', onHide);
      window.removeEventListener('pagehide', onHide);
      clearInterval(interval);
      flush();
    };
  }, [flush]);

  return { push, flush };
}

export default function BriefReader({ episode, sentences, glossary, audioUrl, seriesTitle, totalPlanned }: Props) {
  const { push } = useEventQueue(episode.id);
  const [gloss, setGloss] = useState<{ info: GlossInfo; surface: string; sentenceId: string } | null>(null);
  // reading → quiz (si quiz non vide) → exit
  const [phase, setPhase] = useState<'reading' | 'quiz' | 'exit'>('reading');
  const glossById = useRef(new Map(glossary.map((g) => [g.lexeme_id, g])));
  const quiz = (episode.quiz ?? []) as QuizItem[];

  const onTapToken = useCallback(
    (token: TokenSpan, sentence: Sentence) => {
      if (!token.lexeme_id) return;
      const info = glossById.current.get(token.lexeme_id);
      push({ type: 'tap_gloss', sentence_id: sentence.id, lexeme_id: token.lexeme_id, payload: { surface: token.surface } });
      if (info) {
        setGloss({ info, surface: token.surface, sentenceId: sentence.id });
      } else {
        // Token hors glossaire du jour : gloss minimal (lemme seul).
        setGloss({
          info: {
            lexeme_id: token.lexeme_id,
            lemma: token.lemma,
            gloss_fr: '',
            gloss_source: 'unverified',
            collocation: null,
            role: 'review',
            hanja: null,
          },
          surface: token.surface,
          sentenceId: sentence.id,
        });
      }
    },
    [push],
  );

  const onCompleted = useCallback(() => {
    setPhase((current) => {
      if (current !== 'reading') return current;
      push({ type: 'episode_completed' });
      return quiz.length > 0 ? 'quiz' : 'exit';
    });
  }, [push, quiz.length]);

  return (
    <main className={`content-wrap ${styles.main}`}>
      <header className={styles.header}>
        {seriesTitle && (
          <p className={styles.seriesLine}>
            {seriesTitle}
            {totalPlanned ? ` — épisode ${episode.episode_number}/${totalPlanned}` : ''}
          </p>
        )}
        <h1 className={styles.title}>{episode.title}</h1>
        <p className={styles.meta}>{episode.est_read_min ?? 4} min · {episode.brief_date}</p>
      </header>

      <KaraokeReader
        sentences={sentences}
        audioUrl={audioUrl}
        onTapToken={onTapToken}
        onCompleted={onCompleted}
        onMaskRevealedEarly={(token, sentence) =>
          push({ type: 'mask_revealed_early', sentence_id: sentence.id, lexeme_id: token.lexeme_id })
        }
        onReplay={() => push({ type: 'audio_replay' })}
      />

      {phase === 'quiz' && (
        <ClozeQuiz
          quiz={quiz}
          sentences={sentences}
          onAnswer={(item, correct) =>
            push({ type: 'quiz_answer', lexeme_id: item.answer_lexeme_id, payload: { correct } })
          }
          onDone={() => setPhase('exit')}
        />
      )}

      {phase === 'exit' && episode.try_today && episode.try_today.length > 0 && (
        <section className={styles.exit}>
          <h2 className={styles.exitTitle}>À essayer aujourd&apos;hui</h2>
          {episode.try_today.map((t, i) => (
            <div key={i} className={styles.tryCard}>
              <p className={styles.tryKo}>{t.ko}</p>
              <p className={styles.tryFr}>{t.fr}</p>
              <p className={styles.tryContext}>{t.contexte_usage}</p>
            </div>
          ))}
          {episode.teaser_next && (
            <p className={styles.teaser}>À demain — {episode.teaser_next}</p>
          )}
          <a href="/progres" className={styles.progressLink}>où j&apos;en suis</a>
        </section>
      )}

      <GlossSheet
        gloss={gloss?.info ?? null}
        surface={gloss?.surface ?? ''}
        onClose={() => setGloss(null)}
        onHanjaOpen={(lexemeId) => push({ type: 'hanja_open', lexeme_id: lexemeId })}
        onFlag={() =>
          push({
            type: 'flag_awkward',
            sentence_id: gloss?.sentenceId,
            lexeme_id: gloss?.info.lexeme_id,
            payload: { surface: gloss?.surface },
          })
        }
      />
    </main>
  );
}
