'use client';

import { useEffect, useState } from 'react';
import type { HanjaFamily } from '@/lib/types';
import styles from './HanjaPanel.module.css';

interface Props {
  lexemeId: string;
  hanja: string;
}

// Panneau famille de mots (pattern WordFamily v1) — discret, un niveau de
// profondeur en plus dans la GlossSheet, jamais imposé.
export default function HanjaPanel({ lexemeId, hanja }: Props) {
  const [family, setFamily] = useState<HanjaFamily | null | 'loading'>('loading');

  useEffect(() => {
    let cancelled = false;
    fetch(`/api/hanja/${lexemeId}`)
      .then((r) => r.json())
      .then((data: { family: HanjaFamily | null }) => {
        if (!cancelled) setFamily(data.family);
      })
      .catch(() => {
        if (!cancelled) setFamily(null);
      });
    return () => {
      cancelled = true;
    };
  }, [lexemeId]);

  if (family === 'loading') {
    return <div className={`shimmer ${styles.loading}`} />;
  }
  if (!family || family.members.length === 0) {
    return <p className={styles.empty}>Pas encore d&apos;autres mots de la famille {hanja}.</p>;
  }

  return (
    <div className={styles.panel}>
      <p className={styles.head}>
        <span className={styles.char}>{family.char}</span>
        <span className={styles.reading}>{family.reading}</span>
        {family.meaning_fr && <span className={styles.meaning}>{family.meaning_fr}</span>}
      </p>
      <ul className={styles.members}>
        {family.members.map((m) => (
          <li key={m.lemma} className={styles.member}>
            <span className={styles.memberLemma}>{m.lemma}</span>
            {m.hanja && <span className={styles.memberHanja}>{m.hanja}</span>}
            <span className={styles.memberGloss}>{m.gloss_fr}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}
