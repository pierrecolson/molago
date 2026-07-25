'use client';

import { useState } from 'react';
import { Plus, CaretRight } from '@phosphor-icons/react';
import { FamilyWord, Morpheme } from '@/lib/types';
import { highlightSharedMorphemes } from '@/lib/utils';
import styles from './WordFamily.module.css';

interface WordFamilyProps {
  family: FamilyWord[];
  morphemes: Morpheme[];
  wordListKoreans: Set<string>;
  onAdd: (korean: string) => Promise<void>;
  onNavigate: (korean: string) => void;
}

export default function WordFamily({
  family,
  morphemes,
  wordListKoreans,
  onAdd,
  onNavigate,
}: WordFamilyProps) {
  const [addingKorean, setAddingKorean] = useState<string | null>(null);

  if (family.length === 0) return null;

  const handleAdd = async (korean: string) => {
    setAddingKorean(korean);
    try {
      await onAdd(korean);
    } finally {
      setAddingKorean(null);
    }
  };

  return (
    <>
      <div className={styles.label}>Word Family</div>
      <div className={styles.list}>
        {family.map((fw) => {
          const inList = wordListKoreans.has(fw.korean);
          const isAdding = addingKorean === fw.korean;
          const highlighted = highlightSharedMorphemes(fw.korean, morphemes);

          return (
            <div
              key={fw.korean}
              className={`${styles.item} ${inList ? styles.itemInList : ''}`}
              onClick={inList ? () => onNavigate(fw.korean) : undefined}
            >
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
              {inList ? (
                <span className={styles.chevron}>
                  <CaretRight size={16} />
                </span>
              ) : (
                <button
                  className={styles.actionBtn}
                  onClick={() => handleAdd(fw.korean)}
                  disabled={isAdding}
                  aria-label={`Add ${fw.korean}`}
                >
                  {isAdding ? <span className={styles.spinner} /> : <Plus size={16} />}
                </button>
              )}
            </div>
          );
        })}
      </div>
    </>
  );
}
