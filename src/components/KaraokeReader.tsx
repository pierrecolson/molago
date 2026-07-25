'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { Play, Pause, ArrowCounterClockwise } from '@phosphor-icons/react';
import type { Sentence, TokenSpan } from '@/lib/types';
import styles from './KaraokeReader.module.css';

interface Props {
  sentences: Sentence[];
  audioUrl: string | null;
  onTapToken: (token: TokenSpan, sentence: Sentence) => void;
  onCompleted: () => void;
  onMaskRevealedEarly: (token: TokenSpan, sentence: Sentence) => void;
  onReplay: () => void;
}

const SPEEDS = [1, 0.8] as const;
const MASK_REVEAL_MS = 2000; // micro-instant de génération avant révélation

/** Découpe text_ko en segments [texte brut | span tappable] à partir des offsets. */
function segmentSentence(sentence: Sentence): { text: string; token?: TokenSpan }[] {
  const segments: { text: string; token?: TokenSpan }[] = [];
  let cursor = 0;
  const sorted = [...(sentence.tokens ?? [])].sort((a, b) => a.s - b.s);
  for (const token of sorted) {
    if (token.s < cursor) continue; // chevauchement : on garde le premier
    if (token.s > cursor) segments.push({ text: sentence.text_ko.slice(cursor, token.s) });
    segments.push({ text: sentence.text_ko.slice(token.s, token.e), token });
    cursor = token.e;
  }
  if (cursor < sentence.text_ko.length) segments.push({ text: sentence.text_ko.slice(cursor) });
  return segments;
}

export default function KaraokeReader({
  sentences,
  audioUrl,
  onTapToken,
  onCompleted,
  onMaskRevealedEarly,
  onReplay,
}: Props) {
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const rowRefs = useRef<(HTMLParagraphElement | null)[]>([]);
  const [playing, setPlaying] = useState(false);
  const [activeIdx, setActiveIdx] = useState(-1);
  const [speedIdx, setSpeedIdx] = useState(0);
  const [ended, setEnded] = useState(false);
  // Masques révélés (par « sentenceIdx:s »). Révélation auto 2 s après activation de la phrase.
  const [revealed, setRevealed] = useState<Set<string>>(new Set());
  const revealTimers = useRef<ReturnType<typeof setTimeout>[]>([]);

  const onTimeUpdate = useCallback(() => {
    const audio = audioRef.current;
    if (!audio) return;
    const ms = audio.currentTime * 1000;
    const idx = sentences.findIndex(
      (s) => s.audio_start_ms !== null && s.audio_end_ms !== null && ms >= s.audio_start_ms && ms < s.audio_end_ms,
    );
    if (idx !== -1 && idx !== activeIdx) setActiveIdx(idx);
  }, [sentences, activeIdx]);

  // Phrase active : autoscroll + programmation de la révélation des masques.
  useEffect(() => {
    if (activeIdx < 0) return;
    rowRefs.current[activeIdx]?.scrollIntoView({ behavior: 'smooth', block: 'center' });
    const sentence = sentences[activeIdx];
    for (const token of sentence.tokens ?? []) {
      if (!token.masked) continue;
      const key = `${activeIdx}:${token.s}`;
      const timer = setTimeout(() => {
        setRevealed((prev) => (prev.has(key) ? prev : new Set(prev).add(key)));
      }, MASK_REVEAL_MS);
      revealTimers.current.push(timer);
    }
  }, [activeIdx, sentences]);

  useEffect(() => () => revealTimers.current.forEach(clearTimeout), []);

  const togglePlay = () => {
    const audio = audioRef.current;
    if (!audio) return;
    if (playing) {
      audio.pause();
    } else {
      if (ended) {
        audio.currentTime = 0;
        setEnded(false);
        onReplay();
      }
      audio.play();
    }
  };

  const cycleSpeed = () => {
    const next = (speedIdx + 1) % SPEEDS.length;
    setSpeedIdx(next);
    if (audioRef.current) audioRef.current.playbackRate = SPEEDS[next];
  };

  const seekTo = (sentence: Sentence, idx: number) => {
    const audio = audioRef.current;
    if (!audio || sentence.audio_start_ms === null) return;
    audio.currentTime = sentence.audio_start_ms / 1000;
    setActiveIdx(idx);
  };

  const handleTokenTap = (token: TokenSpan, sentence: Sentence, sentenceIdx: number) => {
    const key = `${sentenceIdx}:${token.s}`;
    if (token.masked && !revealed.has(key)) {
      setRevealed((prev) => new Set(prev).add(key));
      onMaskRevealedEarly(token, sentence);
      return; // le premier tap dévoile ; un second tap ouvrira le gloss
    }
    onTapToken(token, sentence);
  };

  return (
    <div className={styles.reader}>
      <div className={styles.textFlow}>
        {sentences.map((sentence, idx) => (
          <p
            key={sentence.id}
            ref={(el) => {
              rowRefs.current[idx] = el;
            }}
            className={`${styles.sentence} ${idx === activeIdx ? styles.active : ''}`}
            onClick={() => seekTo(sentence, idx)}
          >
            {segmentSentence(sentence).map((seg, si) => {
              if (!seg.token?.lexeme_id) {
                return <span key={si}>{seg.text}</span>;
              }
              const key = `${idx}:${seg.token.s}`;
              const isMasked = seg.token.masked && !revealed.has(key);
              return (
                <button
                  key={si}
                  className={`${styles.token} ${isMasked ? styles.masked : ''}`}
                  onClick={(e) => {
                    e.stopPropagation();
                    handleTokenTap(seg.token!, sentence, idx);
                  }}
                >
                  {seg.text}
                </button>
              );
            })}
          </p>
        ))}
      </div>

      {audioUrl && (
        <>
          <audio
            ref={audioRef}
            src={audioUrl}
            preload="auto"
            onTimeUpdate={onTimeUpdate}
            onPlay={() => setPlaying(true)}
            onPause={() => setPlaying(false)}
            onEnded={() => {
              setPlaying(false);
              setEnded(true);
              setActiveIdx(-1);
              onCompleted();
            }}
          />
          <div className={styles.controls}>
            <button className={styles.speedButton} onClick={cycleSpeed}>
              {SPEEDS[speedIdx]}×
            </button>
            <button className={styles.playButton} onClick={togglePlay} aria-label={playing ? 'Pause' : 'Lecture'}>
              {playing ? <Pause size={26} weight="fill" /> : ended ? <ArrowCounterClockwise size={26} weight="bold" /> : <Play size={26} weight="fill" />}
            </button>
            <span className={styles.spacer} />
          </div>
        </>
      )}
      {!audioUrl && (
        <div className={styles.noAudio}>
          <button className={styles.doneButton} onClick={onCompleted}>J&apos;ai fini de lire</button>
        </div>
      )}
    </div>
  );
}
