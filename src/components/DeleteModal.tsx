'use client';

import styles from './DeleteModal.module.css';

interface DeleteModalProps {
  korean: string;
  visible: boolean;
  onCancel: () => void;
  onConfirm: () => void;
}

export default function DeleteModal({ korean, visible, onCancel, onConfirm }: DeleteModalProps) {
  if (!visible) return null;

  return (
    <div
      className={`${styles.overlay} ${visible ? styles.visible : ''}`}
      onClick={onCancel}
    >
      <div className={styles.box} onClick={(e) => e.stopPropagation()}>
        <div className={styles.title}>Delete word?</div>
        <div className={styles.text}>
          &ldquo;{korean}&rdquo; will be permanently removed with all its data.
        </div>
        <div className={styles.actions}>
          <button className={styles.cancel} onClick={onCancel}>
            Cancel
          </button>
          <button className={styles.delete} onClick={onConfirm}>
            Delete
          </button>
        </div>
      </div>
    </div>
  );
}
