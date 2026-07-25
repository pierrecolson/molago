'use client';

import { useEffect, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Check, X } from '@phosphor-icons/react';
import styles from './placement.module.css';

interface PlacementWord {
  lexeme_id: string;
  lemma: string;
  band: number;
}

type Phase = 'loading' | 'intro' | 'running' | 'submitting' | 'done' | 'error';

// Test de placement par auto-marquage : ~80 jugements binaires, une seule fois.
// Deux gros boutons, rythme rapide — l'honnêteté est dans l'intérêt de l'utilisateur.
export default function PlacementPage() {
  const router = useRouter();
  const [phase, setPhase] = useState<Phase>('loading');
  const [words, setWords] = useState<PlacementWord[]>([]);
  const [index, setIndex] = useState(0);
  const [responses, setResponses] = useState<{ lexeme_id: string; band: number; known: boolean }[]>([]);
  const [summary, setSummary] = useState<string | null>(null);

  useEffect(() => {
    fetch('/api/placement')
      .then((r) => r.json())
      .then((data: { bands: { band: number; words: { lexeme_id: string; lemma: string }[] }[] }) => {
        const flat = (data.bands ?? []).flatMap((b) =>
          b.words.map((w) => ({ ...w, band: b.band })),
        );
        if (flat.length === 0) {
          setPhase('error');
          return;
        }
        setWords(flat);
        setPhase('intro');
      })
      .catch(() => setPhase('error'));
  }, []);

  const current = words[index];
  const progress = useMemo(
    () => (words.length ? Math.round((index / words.length) * 100) : 0),
    [index, words.length],
  );

  const answer = (known: boolean) => {
    if (!current) return;
    const next = [...responses, { lexeme_id: current.lexeme_id, band: current.band, known }];
    setResponses(next);
    if (index + 1 < words.length) {
      setIndex(index + 1);
    } else {
      submit(next);
    }
  };

  const submit = async (all: { lexeme_id: string; band: number; known: boolean }[]) => {
    setPhase('submitting');
    try {
      const res = await fetch('/api/placement', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ responses: all }),
      });
      const data = await res.json();
      const known = data?.initialized?.known ?? 0;
      setSummary(known > 0 ? `${known} mots marqués connus — le contenu partira de là.` : null);
      setPhase('done');
    } catch {
      setPhase('error');
    }
  };

  if (phase === 'loading') {
    return <main className={`content-wrap ${styles.center}`}><div className={`shimmer ${styles.shimmerCard}`} /></main>;
  }

  if (phase === 'error') {
    return (
      <main className={`content-wrap ${styles.center}`}>
        <p className={styles.text}>
          Impossible de charger le test — le lexique est-il seedé ? (<code>npm run seed</code>)
        </p>
      </main>
    );
  }

  if (phase === 'intro') {
    return (
      <main className={`content-wrap ${styles.center}`}>
        <h1 className={styles.title}>Calibrage</h1>
        <p className={styles.text}>
          {words.length} mots, environ 10 minutes, une seule fois. Pour chaque mot : le
          connais-tu assez pour le comprendre dans une phrase ? Pas de piège, pas de note —
          ça sert uniquement à calibrer les textes.
        </p>
        <button className={styles.primary} onClick={() => setPhase('running')}>Commencer</button>
      </main>
    );
  }

  if (phase === 'submitting') {
    return <main className={`content-wrap ${styles.center}`}><p className={styles.text}>Calibrage du profil…</p></main>;
  }

  if (phase === 'done') {
    return (
      <main className={`content-wrap ${styles.center}`}>
        <h1 className={styles.title}>C&apos;est calé.</h1>
        {summary && <p className={styles.text}>{summary}</p>}
        <p className={styles.text}>Le premier brief sera généré cette nuit. À demain matin.</p>
        <button className={styles.primary} onClick={() => router.push('/')}>Retour</button>
      </main>
    );
  }

  return (
    <main className={`content-wrap ${styles.running}`}>
      <div className={styles.progressTrack}>
        <div className={styles.progressFill} style={{ width: `${progress}%` }} />
      </div>
      <div className={styles.wordZone}>
        <p className={styles.word}>{current.lemma}</p>
      </div>
      <div className={styles.buttons}>
        <button className={styles.unknownButton} onClick={() => answer(false)}>
          <X size={22} weight="bold" /> Non
        </button>
        <button className={styles.knownButton} onClick={() => answer(true)}>
          <Check size={22} weight="bold" /> Je connais
        </button>
      </div>
    </main>
  );
}
