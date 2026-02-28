'use client';

import { Example } from '@/lib/types';
import { highlightWordInExample } from '@/lib/utils';
import styles from './ExampleCard.module.css';

interface ExampleCardProps {
  examples: Example[];
  targetKorean: string;
}

export default function ExampleCard({ examples, targetKorean }: ExampleCardProps) {
  if (examples.length === 0) return null;

  return (
    <>
      <div className={styles.label}>Examples</div>
      {examples.map((ex, i) => {
        const parts = highlightWordInExample(ex.korean, targetKorean);
        return (
          <div key={i} className={styles.card}>
            <div className={styles.korean}>
              {parts.map((p, j) => (
                <span key={j} className={p.highlighted ? 'accent-text' : ''}>
                  {p.text}
                </span>
              ))}
            </div>
            <div className={styles.english}>{ex.english}</div>
            {ex.context && (
              <span className={styles.context}>{ex.context}</span>
            )}
          </div>
        );
      })}
    </>
  );
}
