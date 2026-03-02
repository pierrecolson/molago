'use client';

import { Plus } from '@phosphor-icons/react';
import styles from './AddInput.module.css';

const MAX_LENGTH = 50;

interface AddInputProps {
  value: string;
  onChange: (value: string) => void;
  onSubmit: () => void;
  disabled?: boolean;
  error?: string;
}

export default function AddInput({ value, onChange, onSubmit, disabled, error }: AddInputProps) {
  const tooLong = value.trim().length > MAX_LENGTH;

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && value.trim() && !disabled && !tooLong) {
      onSubmit();
    }
  };

  return (
    <div className={styles.area}>
      <div className="content-wrap">
        <div className={`${styles.wrap} ${tooLong || error ? styles.wrapError : ''}`}>
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
            disabled={disabled || !value.trim() || tooLong}
            aria-label="Add word"
          >
            <Plus weight="bold" />
          </button>
        </div>
        {tooLong && (
          <div className={styles.errorText}>Word is too long (max {MAX_LENGTH} characters)</div>
        )}
        {error && !tooLong && (
          <div className={styles.errorText}>{error}</div>
        )}
      </div>
    </div>
  );
}
