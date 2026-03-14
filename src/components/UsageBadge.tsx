'use client';

import { usageConfig, UsageLevel } from '@/lib/utils';
import styles from './UsageBadge.module.css';

interface UsageBadgeProps {
  usage: UsageLevel;
  variant?: 'compact' | 'full' | 'detail';
}

const iconMap: Record<UsageLevel, string> = {
  high: '/icons/common.svg',
  mid: '/icons/uncommon.svg',
  low: '/icons/rare.svg',
};

export default function UsageBadge({ usage, variant = 'compact' }: UsageBadgeProps) {
  const config = usageConfig[usage];
  if (!config) return null;

  const iconSize = variant === 'compact' ? 20 : variant === 'detail' ? 13 : 15;

  return (
    <span
      className={`${styles.badge} ${styles[config.colorClass]} ${
        variant === 'compact' ? styles.compact : variant === 'detail' ? styles.detail : ''
      }`}
    >
      <img src={iconMap[usage]} alt={config.label} width={iconSize} height={iconSize} style={{ display: 'block' }} />
      {variant !== 'compact' && <span>{config.label}</span>}
    </span>
  );
}
