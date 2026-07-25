import styles from './page.module.css';

// Placeholder J0 : sera remplacé par le brief du jour (KaraokeReader…) au jalon J1.
export default function Home() {
  return (
    <main className={`content-wrap ${styles.main}`}>
      <h1 className={styles.logo}>몰라고</h1>
      <p className={styles.subtitle}>Le brief coréen du matin — en construction (J0 : fondations posées).</p>
      <p className={styles.hint}>
        Schéma Supabase : <code>supabase/migrations/001_init.sql</code> · Seed : <code>npm run seed</code> ·
        Pipeline : <code>npm run pipeline</code>
      </p>
    </main>
  );
}
