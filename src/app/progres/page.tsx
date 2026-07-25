import Link from 'next/link';
import { supabaseAdmin } from '@/lib/supabase-server';
import styles from './progres.module.css';

export const dynamic = 'force-dynamic';

// Progression purement informationnelle (P8) : jamais de points, gemmes,
// ligues ou streaks — des faits sur le lexique, c'est tout.
export default async function ProgresPage() {
  const db = supabaseAdmin();

  const [known, seen, episodes, recent] = await Promise.all([
    db.from('lexeme_state').select('lexeme_id', { count: 'exact', head: true }).eq('state', 'known'),
    db.from('lexeme_state').select('lexeme_id', { count: 'exact', head: true }).eq('state', 'seen'),
    db.from('episodes').select('id', { count: 'exact', head: true }).eq('status', 'ready'),
    db
      .from('episodes')
      .select('brief_date, title, coverage_pct, read_at')
      .eq('status', 'ready')
      .order('brief_date', { ascending: false })
      .limit(14),
  ]);

  const avgCoverage =
    recent.data && recent.data.length
      ? recent.data.reduce((sum, e) => sum + (Number(e.coverage_pct) || 0), 0) / recent.data.length
      : null;

  return (
    <main className={`content-wrap ${styles.main}`}>
      <header className={styles.header}>
        <Link href="/" className={styles.back}>← brief du jour</Link>
        <h1 className={styles.title}>Où j&apos;en suis</h1>
      </header>

      <div className={styles.stats}>
        <div className={styles.stat}>
          <p className={styles.statValue}>{known.count ?? 0}</p>
          <p className={styles.statLabel}>mots connus</p>
        </div>
        <div className={styles.stat}>
          <p className={styles.statValue}>{seen.count ?? 0}</p>
          <p className={styles.statLabel}>en cours d&apos;acquisition</p>
        </div>
        <div className={styles.stat}>
          <p className={styles.statValue}>{avgCoverage ? `${avgCoverage.toFixed(1)} %` : '—'}</p>
          <p className={styles.statLabel}>couverture moyenne des textes</p>
        </div>
        <div className={styles.stat}>
          <p className={styles.statValue}>{episodes.count ?? 0}</p>
          <p className={styles.statLabel}>épisodes générés</p>
        </div>
      </div>

      {recent.data && recent.data.length > 0 && (
        <section className={styles.recent}>
          <h2 className={styles.sectionTitle}>Derniers épisodes</h2>
          <ul className={styles.episodeList}>
            {recent.data.map((e) => (
              <li key={e.brief_date}>
                <Link href={`/brief/${e.brief_date}`} className={styles.episodeRow}>
                  <span className={styles.episodeDate}>{e.brief_date.slice(5)}</span>
                  <span className={styles.episodeTitle}>{e.title}</span>
                  {e.read_at && <span className={styles.episodeRead}>lu</span>}
                </Link>
              </li>
            ))}
          </ul>
        </section>
      )}
    </main>
  );
}
