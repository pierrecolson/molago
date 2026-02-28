'use client';

import { Plus, CaretRight } from '@phosphor-icons/react';
import { FamilyWord, Morpheme } from '@/lib/types';
import { highlightSharedMorphemes } from '@/lib/utils';
import styles from './WordFamily.module.css';

interface WordFamilyProps {
  family: FamilyWord[];
  morphemes: Morpheme[];
  wordListKoreans: Set<string>;
  onAdd: (korean: string) => void;
  onNavigate: (korean: string) => void;
}

export default function WordFamily({
  family,
  morphemes,
  wordListKoreans,
  onAdd,
  onNavigate,
}: WordFamilyProps) {
  if (family.length === 0) return null;

  return (
    <>
      <div className={styles.label}>Word Family</div>
      <div className={styles.list}>
        {family.map((fw) => {
          const inList = wordListKoreans.has(fw.korean);
          const highlighted = highlightSharedMorphemes(fw.korean, morphemes);

          return (
            <div key={fw.korean} className={styles.item}>
              <div className={styles.info}>
                <div className={styles.korean}>
                  {highlighted.map((h, i) => (
                    <span key={i} className={h.highlighted ? 'accent-text' : ''}>
                      {h.char}
                    </span>
                  ))}
                  <span className={styles.hanja}>{fw.hanja}</span>
                </div>
                <div className={styles.meaning}>{fw.meaning}</div>
                <div className={styles.connection}>{fw.connection}</div>
              </div>
              <button
                className={`${styles.actionBtn} ${inList ? styles.inList : ''}`}
                onClick={() => (inList ? onNavigate(fw.korean) : onAdd(fw.korean))}
                aria-label={inList ? `Go to ${fw.korean}` : `Add ${fw.korean}`}
              >
                {inList ? <CaretRight size={16} /> : <Plus size={16} />}
              </button>
            </div>
          );
        })}
      </div>
    </>
  );
}
