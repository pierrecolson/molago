'use client';

import { useEffect, useCallback } from 'react';
import { X } from '@phosphor-icons/react';
import styles from './SettingsSheet.module.css';

interface SettingsSheetProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  showFrequency: boolean;
  onShowFrequencyChange: (value: boolean) => void;
}

export default function SettingsSheet({
  open,
  onOpenChange,
  showFrequency,
  onShowFrequencyChange,
}: SettingsSheetProps) {
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

  return (
    <>
      <div
        className={`${styles.backdrop} ${open ? styles.backdropOpen : ''}`}
        onClick={handleClose}
      />

      <div className={`${styles.sheet} ${open ? styles.sheetOpen : ''}`}>
        <div className={styles.sheetHeader}>
          <span className={styles.sheetTitle}>Settings</span>
          <button className={styles.closeBtn} onClick={handleClose} aria-label="Close settings">
            <X weight="bold" />
          </button>
        </div>

        <div className={styles.settingRow}>
          <div className={styles.settingInfo}>
            <span className={styles.settingLabel}>Word Frequency</span>
            <span className={styles.settingDescription}>
              Show frequency badges on each word in your list
            </span>
          </div>
          <button
            role="switch"
            aria-checked={showFrequency}
            className={`${styles.toggle} ${showFrequency ? styles.toggleOn : ''}`}
            onClick={() => onShowFrequencyChange(!showFrequency)}
          >
            <span className={styles.toggleThumb} />
          </button>
        </div>
      </div>
    </>
  );
}
