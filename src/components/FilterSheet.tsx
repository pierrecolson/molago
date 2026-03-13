'use client';

import { useEffect, useCallback } from 'react';
import { X } from '@phosphor-icons/react';
import { usageConfig, UsageLevel } from '@/lib/utils';
import styles from './FilterSheet.module.css';

interface FilterSheetProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  usageFilter: Set<UsageLevel>;
  onUsageFilterChange: (filter: Set<UsageLevel>) => void;
  posFilter: Set<string>;
  onPosFilterChange: (filter: Set<string>) => void;
  availablePos: string[];
  onClear: () => void;
}

const usageLevels: UsageLevel[] = ['high', 'mid', 'low'];

export default function FilterSheet({
  open,
  onOpenChange,
  usageFilter,
  onUsageFilterChange,
  posFilter,
  onPosFilterChange,
  availablePos,
  onClear,
}: FilterSheetProps) {
  const hasActiveFilters = usageFilter.size > 0 || posFilter.size > 0;

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

  const handleClose = useCallback(() => {
    onOpenChange(false);
  }, [onOpenChange]);

  const handleBackdropClick = useCallback(() => {
    handleClose();
  }, [handleClose]);

  const toggleUsage = useCallback(
    (level: UsageLevel) => {
      const next = new Set(usageFilter);
      if (next.has(level)) {
        next.delete(level);
      } else {
        next.add(level);
      }
      onUsageFilterChange(next);
    },
    [usageFilter, onUsageFilterChange]
  );

  const togglePos = useCallback(
    (pos: string) => {
      const next = new Set(posFilter);
      if (next.has(pos)) {
        next.delete(pos);
      } else {
        next.add(pos);
      }
      onPosFilterChange(next);
    },
    [posFilter, onPosFilterChange]
  );

  const handleClear = useCallback(() => {
    onClear();
  }, [onClear]);

  return (
    <>
      {/* Backdrop */}
      <div
        className={`${styles.backdrop} ${open ? styles.backdropOpen : ''}`}
        onClick={handleBackdropClick}
      />

      {/* Sheet */}
      <div className={`${styles.sheet} ${open ? styles.sheetOpen : ''}`}>
        <div className={styles.sheetHeader}>
          <span className={styles.sheetTitle}>Filter</span>
          <button className={styles.closeBtn} onClick={handleClose}>
            <X weight="bold" />
          </button>
        </div>

        {/* Frequency section */}
        <div className={styles.section}>
          <div className={styles.sectionLabel}>Frequency</div>
          <div className={styles.chips}>
            {usageLevels.map((level) => (
              <button
                key={level}
                className={`${styles.chip} ${usageFilter.has(level) ? styles.chipActive : ''}`}
                onClick={() => toggleUsage(level)}
              >
                {usageConfig[level].label}
              </button>
            ))}
          </div>
        </div>

        {/* Part of speech section */}
        {availablePos.length > 0 && (
          <div className={styles.section}>
            <div className={styles.sectionLabel}>Part of speech</div>
            <div className={styles.chips}>
              {availablePos.map((pos) => (
                <button
                  key={pos}
                  className={`${styles.chip} ${posFilter.has(pos) ? styles.chipActive : ''}`}
                  onClick={() => togglePos(pos)}
                >
                  {pos}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Clear all */}
        <button
          className={styles.clearBtn}
          onClick={handleClear}
          disabled={!hasActiveFilters}
        >
          Clear all
        </button>
      </div>
    </>
  );
}
