'use client';

import { Suggestion } from '@/lib/types';
import styles from './SuggestionBar.module.css';

interface SuggestionBarProps {
  suggestions: Suggestion[];
  visible: boolean;
  onSelect: (korean: string) => void;
  onDismiss: () => void;
}

export default function SuggestionBar({ suggestions, visible, onSelect, onDismiss }: SuggestionBarProps) {
  if (!visible && suggestions.length === 0) return null;

  return (
    <div className={`${styles.bar} ${visible ? styles.visible : ''}`}>
      <div className={styles.label}>Did you mean?</div>
      <div className={styles.chips}>
        {suggestions.map((s) => (
          <button
            key={s.korean}
            className={styles.chip}
            onClick={() => onSelect(s.korean)}
          >
            <span className={styles.chipKorean}>{s.korean}</span>
            <span className={styles.chipDef}>{s.definition}</span>
          </button>
        ))}
        <button className={styles.dismiss} onClick={onDismiss}>
          Add anyway
        </button>
      </div>
    </div>
  );
}
