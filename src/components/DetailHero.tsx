'use client';

import UsageBadge from './UsageBadge';
import styles from './DetailHero.module.css';

interface DetailHeroProps {
  korean: string;
  romanization: string;
  definition: string;
  literalMeaning: string;
  partOfSpeech: string;
  originType: string;
  usage: 'high' | 'mid' | 'low';
}

export default function DetailHero({
  korean,
  romanization,
  definition,
  literalMeaning,
  partOfSpeech,
  originType,
  usage,
}: DetailHeroProps) {
  return (
    <>
      <div className={styles.hero}>
        <div className={styles.korean}>{korean}</div>
        <div className={styles.romanization}>{romanization}</div>
        <div className={styles.badges}>
          <span className={`${styles.badge} ${styles.badgePos}`}>{partOfSpeech}</span>
          <span className={`${styles.badge} ${styles.badgeOrigin}`}>{originType}</span>
          <UsageBadge usage={usage} variant="detail" />
        </div>
      </div>
      <div className={styles.definition}>
        {definition}
        {literalMeaning && (
          <span className={styles.literalMeaning}>
            Lit. &ldquo;{literalMeaning}&rdquo;
          </span>
        )}
      </div>
    </>
  );
}
