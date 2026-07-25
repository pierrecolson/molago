'use client';

import { Morpheme } from '@/lib/types';
import styles from './MorphemePills.module.css';

interface MorphemePillsProps {
  morphemes: Morpheme[];
}

export default function MorphemePills({ morphemes }: MorphemePillsProps) {
  if (morphemes.length === 0) return null;

  return (
    <>
      <div className={styles.label}>Morphemes</div>
      <div className={styles.row}>
        {morphemes.map((m, i) => (
          <div key={i} className={styles.pill}>
            <div className={styles.korean}>{m.korean}</div>
            <div className={styles.hanja}>{m.hanja}</div>
            <div className={styles.meaning}>{m.meaning}</div>
          </div>
        ))}
      </div>
    </>
  );
}
