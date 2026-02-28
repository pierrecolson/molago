'use client';

import { Plus } from '@phosphor-icons/react';
import styles from './AddInput.module.css';

interface AddInputProps {
  value: string;
  onChange: (value: string) => void;
  onSubmit: () => void;
  disabled?: boolean;
}

export default function AddInput({ value, onChange, onSubmit, disabled }: AddInputProps) {
  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && value.trim() && !disabled) {
      onSubmit();
    }
  };

  return (
    <div className={styles.area}>
      <div className="content-wrap">
        <div className={styles.wrap}>
          <input
            className={styles.input}
            type="text"
            placeholder="Add a Korean word..."
            value={value}
            onChange={(e) => onChange(e.target.value)}
            onKeyDown={handleKeyDown}
            disabled={disabled}
          />
          <button
            className={styles.button}
            onClick={onSubmit}
            disabled={disabled || !value.trim()}
            aria-label="Add word"
          >
            <Plus weight="bold" />
          </button>
        </div>
      </div>
    </div>
  );
}
