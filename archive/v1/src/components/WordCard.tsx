'use client';

import { CaretRight } from '@phosphor-icons/react';
import UsageBadge from './UsageBadge';
import styles from './WordCard.module.css';

interface WordCardProps {
  korean: string;
  definition: string;
  usage: 'high' | 'mid' | 'low';
  loading?: boolean;
  showUsage?: boolean;
  onClick: () => void;
}

export default function WordCard({ korean, definition, usage, loading, showUsage = true, onClick }: WordCardProps) {
  return (
    <div
      className={`${styles.card} ${loading ? styles.loading : ''}`}
      onClick={onClick}
    >
      <span className={styles.korean}>{korean}</span>
      <span className={styles.definition}>{definition}</span>
      {showUsage && (
        <span className={styles.badge}>
          <UsageBadge usage={usage} variant="compact" />
        </span>
      )}
      <span className={styles.arrow}>
        <CaretRight size={20} />
      </span>
    </div>
  );
}
