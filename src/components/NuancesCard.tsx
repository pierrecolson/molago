'use client';

import styles from './NuancesCard.module.css';

interface NuancesCardProps {
  nuances: string;
}

export default function NuancesCard({ nuances }: NuancesCardProps) {
  if (!nuances) return null;

  return (
    <>
      <div className={styles.label}>Nuances</div>
      <div className={styles.card}>
        <div className={styles.text}>{nuances}</div>
      </div>
    </>
  );
}
