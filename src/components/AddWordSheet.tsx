'use client';

import { useRef, useEffect, useCallback, useState } from 'react';
import { Plus, X } from '@phosphor-icons/react';
import { Word, Suggestion } from '@/lib/types';
import styles from './AddWordSheet.module.css';

const MAX_LENGTH = 50;

type Phase = 'input' | 'analyzing' | 'result' | 'suggestions';

interface AddWordSheetProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  value: string;
  onChange: (value: string) => void;
  onSubmit: () => void;
  onConfirm: (word: Word) => void;
  disabled?: boolean;
  error?: string;
  shimmerWord: string;
  resultWord: Word | null;
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
  onConfirm,
  error,
  shimmerWord,
  resultWord,
  suggestions,
  showSuggestions,
  onSuggestionSelect,
  onSuggestionDismiss,
}: AddWordSheetProps) {
  const inputRef = useRef<HTMLInputElement>(null);
  const tooLong = value.trim().length > MAX_LENGTH;
  const [phase, setPhase] = useState<Phase>('input');

  // Derive phase from props
  useEffect(() => {
    if (resultWord) {
      setPhase('result');
    } else if (showSuggestions && suggestions.length > 0) {
      setPhase('suggestions');
    } else if (shimmerWord) {
      setPhase('analyzing');
    } else {
      setPhase('input');
    }
  }, [resultWord, showSuggestions, suggestions, shimmerWord]);

  // Auto-focus input when sheet opens or returns to input phase
  useEffect(() => {
    if (open && phase === 'input' && inputRef.current) {
      const timer = setTimeout(() => {
        inputRef.current?.focus({ preventScroll: true });
      }, 100);
      return () => clearTimeout(timer);
    }
  }, [open, phase]);

  // Lock background scroll when sheet is open
  useEffect(() => {
    if (open) {
      const scrollY = window.scrollY;
      document.documentElement.style.position = 'fixed';
      document.documentElement.style.top = `-${scrollY}px`;
      document.documentElement.style.width = '100%';
    } else {
      const top = document.documentElement.style.top;
      document.documentElement.style.position = '';
      document.documentElement.style.top = '';
      document.documentElement.style.width = '';
      if (top) {
        window.scrollTo(0, parseInt(top, 10) * -1);
      }
    }
  }, [open]);

  // Reset phase when sheet closes
  useEffect(() => {
    if (!open) {
      setPhase('input');
    }
  }, [open]);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && value.trim() && !tooLong) {
      onSubmit();
    }
  };

  const handleClose = useCallback(() => {
    onOpenChange(false);
  }, [onOpenChange]);

  const handleBackdropClick = useCallback(() => {
    if (phase !== 'analyzing') {
      handleClose();
    }
  }, [phase, handleClose]);

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
        className={`${styles.backdrop} ${open ? styles.backdropOpen : ''}`}
        onClick={handleBackdropClick}
      />

      {/* Sheet */}
      <div className={`${styles.sheet} ${open ? styles.sheetOpen : ''}`}>
        <div className={styles.sheetHeader}>
          <span className={styles.sheetTitle}>Add a word</span>
          <button className={styles.closeBtn} onClick={handleClose}>
            <X weight="bold" />
          </button>
        </div>

        {/* === INPUT PHASE === */}
        {phase === 'input' && (
          <>
            <div className={`${styles.inputRow} ${tooLong || error ? styles.inputRowError : ''}`}>
              <input
                ref={inputRef}
                className={styles.input}
                type="text"
                placeholder="Type a Korean word..."
                value={value}
                onChange={(e) => onChange(e.target.value)}
                onKeyDown={handleKeyDown}
                autoComplete="off"
                autoCapitalize="off"
              />
            </div>

            {tooLong && (
              <div className={styles.errorText}>Word is too long (max {MAX_LENGTH} characters)</div>
            )}
            {error && !tooLong && (
              <div className={styles.errorText}>{error}</div>
            )}

            <button
              className={styles.searchBtn}
              onClick={onSubmit}
              disabled={!value.trim() || tooLong}
            >
              Search word
            </button>
          </>
        )}

        {/* === ANALYZING PHASE === */}
        {phase === 'analyzing' && (
          <div className={styles.shimmer}>
            <span className={styles.shimmerKorean}>{shimmerWord}</span>
            <span className={styles.shimmerText}>Analyzing...</span>
          </div>
        )}

        {/* === RESULT PHASE === */}
        {phase === 'result' && resultWord && (
          <>
            <div className={styles.result}>
              <div className={styles.resultKorean}>{resultWord.korean}</div>
              <div className={styles.resultDef}>{resultWord.definition}</div>
            </div>
            <button
              className={styles.confirmBtn}
              onClick={() => onConfirm(resultWord)}
            >
              Add to list
            </button>
          </>
        )}

        {/* === SUGGESTIONS PHASE === */}
        {phase === 'suggestions' && (
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
