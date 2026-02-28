'use client';

import { CellSignalFull, CellSignalMedium, CellSignalLow } from '@phosphor-icons/react';
import { usageConfig, UsageLevel } from '@/lib/utils';
import styles from './UsageBadge.module.css';

interface UsageBadgeProps {
  usage: UsageLevel;
  variant?: 'compact' | 'full' | 'detail';
}

const iconMap = {
  high: CellSignalFull,
  mid: CellSignalMedium,
  low: CellSignalLow,
};

export default function UsageBadge({ usage, variant = 'compact' }: UsageBadgeProps) {
  const config = usageConfig[usage];
  if (!config) return null;

  const Icon = iconMap[usage];
  const iconSize = variant === 'compact' ? 16 : variant === 'detail' ? 13 : 15;

  return (
    <span
      className={`${styles.badge} ${styles[config.colorClass]} ${
        variant === 'compact' ? styles.compact : variant === 'detail' ? styles.detail : ''
      }`}
    >
      <Icon size={iconSize} weight="bold" />
      {variant !== 'compact' && <span>{config.label}</span>}
    </span>
  );
}
