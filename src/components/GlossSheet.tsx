'use client';

import { useState } from 'react';
import { X, Flag } from '@phosphor-icons/react';
import type { GlossInfo } from '@/lib/brief';
import HanjaPanel from '@/components/HanjaPanel';
import styles from './GlossSheet.module.css';

interface Props {
  gloss: GlossInfo | null;
  surface: string;
  onClose: () => void;
  onHanjaOpen: (lexemeId: string) => void;
  onFlag: () => void;
}

// Bottom sheet de gloss (pattern AddWordSheet de la v1).
// Entrée animée par keyframes CSS au montage (pas d'état de transition).
export default function GlossSheet({ gloss, surface, onClose, onHanjaOpen, onFlag }: Props) {
  const [showHanja, setShowHanja] = useState(false);
  const [flagged, setFlagged] = useState(false);

  if (!gloss) return null;

  const toggleHanja = () => {
    if (!showHanja) onHanjaOpen(gloss.lexeme_id);
    setShowHanja(!showHanja);
  };

  const flag = () => {
    if (flagged) return;
    setFlagged(true);
    onFlag();
  };

  const reset = () => {
    setShowHanja(false);
    setFlagged(false);
    onClose();
  };

  return (
    <>
      <div className={styles.backdrop} onClick={reset} />
      <div className={styles.sheet} key={gloss.lexeme_id}>
        <div className={styles.handle} />
        <button className={styles.close} onClick={reset} aria-label="Fermer">
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
        {showHanja && gloss.hanja && <HanjaPanel lexemeId={gloss.lexeme_id} hanja={gloss.hanja} />}
        <div className={styles.footer}>
          {gloss.hanja && (
            <button className={styles.hanjaButton} onClick={toggleHanja}>
              {gloss.hanja} · famille
            </button>
          )}
          <span className={styles.footerRight}>
            {gloss.gloss_source === 'unverified' && gloss.gloss_fr && (
              <span className={styles.unverified}>définition non vérifiée</span>
            )}
            <button
              className={`${styles.flagButton} ${flagged ? styles.flagged : ''}`}
              onClick={flag}
              aria-label="Ce passage sonne bizarre"
            >
              <Flag size={15} weight={flagged ? 'fill' : 'regular'} />
              {flagged ? 'signalé' : 'sonne bizarre'}
            </button>
          </span>
        </div>
      </div>
    </>
  );
}
