'use client';

import { useRef, useEffect, useCallback } from 'react';
import { Plus, X } from '@phosphor-icons/react';
import { Suggestion } from '@/lib/types';
import styles from './AddWordSheet.module.css';

const MAX_LENGTH = 50;

interface ShimmerCard {
  korean: string;
}

interface AddWordSheetProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  value: string;
  onChange: (value: string) => void;
  onSubmit: () => void;
  disabled?: boolean;
  error?: string;
  shimmerCards: ShimmerCard[];
  suggestions: Suggestion[];
  showSuggestions: boolean;
  onSuggestionSelect: (korean: string) => void;
  onSuggestionDismiss: () => void;
}

export default function AddWordSheet({
  open,
  onOpenChange,
  value,
  onChange,
  onSubmit,
  disabled,
  error,
  shimmerCards,
  suggestions,
  showSuggestions,
  onSuggestionSelect,
  onSuggestionDismiss,
}: AddWordSheetProps) {
  const inputRef = useRef<HTMLInputElement>(null);
  const tooLong = value.trim().length > MAX_LENGTH;

  // Auto-focus input when sheet opens
  useEffect(() => {
    if (open && inputRef.current) {
      // Small delay to let the sheet animate in before focusing
      const timer = setTimeout(() => {
        inputRef.current?.focus({ preventScroll: true });
      }, 100);
      return () => clearTimeout(timer);
    }
  }, [open]);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && value.trim() && !disabled && !tooLong) {
      onSubmit();
    }
  };

  const handleClose = useCallback(() => {
    onOpenChange(false);
  }, [onOpenChange]);

  // Close on backdrop tap
  const handleBackdropClick = useCallback(() => {
    if (!disabled) {
      handleClose();
    }
  }, [disabled, handleClose]);

  return (
    <>
      {/* Trigger button */}
      {!open && (
        <div className={styles.trigger}>
          <button
            className={styles.triggerBtn}
            onClick={() => onOpenChange(true)}
          >
            <Plus weight="bold" />
            Add word
          </button>
        </div>
      )}

      {/* Backdrop */}
      <div
        className={`${styles.backdrop} ${open ? styles.open : ''}`}
        onClick={handleBackdropClick}
      />

      {/* Sheet */}
      <div className={`${styles.sheet} ${open ? styles.open : ''}`}>
        <div className={styles.sheetHeader}>
          <span className={styles.sheetTitle}>Add a word</span>
          <button className={styles.closeBtn} onClick={handleClose}>
            <X weight="bold" />
          </button>
        </div>

        {/* Input row */}
        <div className={`${styles.inputRow} ${tooLong || error ? styles.inputRowError : ''}`}>
          <input
            ref={inputRef}
            className={styles.input}
            type="text"
            placeholder="Type a Korean word..."
            value={value}
            onChange={(e) => onChange(e.target.value)}
            onKeyDown={handleKeyDown}
            disabled={disabled}
            autoComplete="off"
            autoCapitalize="off"
          />
          <button
            className={styles.submitBtn}
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

        {/* Shimmer / Analyzing */}
        {shimmerCards.map((s) => (
          <div key={s.korean} className={styles.shimmer}>
            <span className={styles.shimmerKorean}>{s.korean}</span>
            <span className={styles.shimmerText}>Analyzing...</span>
          </div>
        ))}

        {/* Suggestions */}
        {showSuggestions && suggestions.length > 0 && (
          <div className={styles.suggestions}>
            <div className={styles.suggestLabel}>Did you mean?</div>
            <div className={styles.suggestChips}>
              {suggestions.map((s) => (
                <button
                  key={s.korean}
                  className={styles.suggestChip}
                  onClick={() => onSuggestionSelect(s.korean)}
                >
                  <span className={styles.suggestChipKorean}>{s.korean}</span>
                  <span className={styles.suggestChipDef}>{s.definition}</span>
                </button>
              ))}
              <button className={styles.dismissBtn} onClick={onSuggestionDismiss}>
                Add anyway
              </button>
            </div>
          </div>
        )}
      </div>
    </>
  );
}
