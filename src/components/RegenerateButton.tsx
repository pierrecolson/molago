'use client';

import { useState } from 'react';
import styles from './RegenerateButton.module.css';

type Status = 'idle' | 'busy' | 'done' | 'error';

export default function RegenerateButton() {
  const [status, setStatus] = useState<Status>('idle');
  const [message, setMessage] = useState('');

  const trigger = async () => {
    setStatus('busy');
    try {
      const res = await fetch('/api/admin/generate', { method: 'POST' });
      const data = await res.json();
      if (res.ok) {
        setStatus('done');
        setMessage('Génération relancée — le brief arrive dans quelques minutes.');
      } else {
        setStatus('error');
        setMessage(data.error ?? 'Échec de la relance.');
      }
    } catch {
      setStatus('error');
      setMessage('Échec de la relance.');
    }
  };

  if (status === 'done' || status === 'error') {
    return <p className={status === 'done' ? styles.done : styles.error}>{message}</p>;
  }

  return (
    <button className={styles.button} onClick={trigger} disabled={status === 'busy'}>
      {status === 'busy' ? 'Relance…' : 'Relancer la génération'}
    </button>
  );
}
