'use client';

import { X } from '@phosphor-icons/react';
import type { GlossInfo } from '@/lib/brief';
import styles from './GlossSheet.module.css';

interface Props {
  gloss: GlossInfo | null;
  surface: string;
  onClose: () => void;
  onHanjaOpen: (lexemeId: string) => void;
}

// Bottom sheet de gloss (pattern AddWordSheet de la v1).
// Entrée animée par keyframes CSS au montage (pas d'état de transition).
export default function GlossSheet({ gloss, surface, onClose, onHanjaOpen }: Props) {
  if (!gloss) return null;

  return (
    <>
      <div className={styles.backdrop} onClick={onClose} />
      <div className={styles.sheet} key={gloss.lexeme_id}>
        <div className={styles.handle} />
        <button className={styles.close} onClick={onClose} aria-label="Fermer">
          <X size={18} weight="bold" />
        </button>
        <div className={styles.head}>
          <p className={styles.lemma}>{gloss.lemma}</p>
          {surface !== gloss.lemma && <p className={styles.surface}>dans le texte : {surface}</p>}
        </div>
        {gloss.gloss_fr ? (
          <p className={styles.gloss}>{gloss.gloss_fr}</p>
        ) : (
          <p className={styles.glossEmpty}>Pas encore de définition pour ce mot.</p>
        )}
        {gloss.collocation && <p className={styles.collocation}>{gloss.collocation}</p>}
        <div className={styles.footer}>
          {gloss.hanja && (
            <button className={styles.hanjaButton} onClick={() => onHanjaOpen(gloss.lexeme_id)}>
              {gloss.hanja} · famille
            </button>
          )}
          {gloss.gloss_source === 'unverified' && gloss.gloss_fr && (
            <span className={styles.unverified}>définition non vérifiée</span>
          )}
        </div>
      </div>
    </>
  );
}
