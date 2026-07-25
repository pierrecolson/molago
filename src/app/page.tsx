import { redirect } from 'next/navigation';
import { fetchBrief, lastReadyBrief, kstToday } from '@/lib/brief';
import { supabaseAdmin } from '@/lib/supabase-server';
import BriefReader from '@/components/BriefReader';
import RegenerateButton from '@/components/RegenerateButton';
import styles from './page.module.css';

export const dynamic = 'force-dynamic';

export default async function Home() {
  // Profil vide → calibrage d'abord (une seule fois).
  const { count: profileCount } = await supabaseAdmin()
    .from('lexeme_state')
    .select('lexeme_id', { count: 'exact', head: true });
  if ((profileCount ?? 0) === 0) redirect('/placement');

  const today = kstToday();
  const brief = await fetchBrief(today);

  if (!brief) {
    const { data: attempt } = await supabaseAdmin()
      .from('episodes')
      .select('status')
      .eq('brief_date', today)
      .maybeSingle();
    const lastReady = await lastReadyBrief();
    return (
      <main className={`content-wrap ${styles.fallback}`}>
        <h1 className={styles.logo}>몰라고</h1>
        <p className={styles.subtitle}>
          {attempt?.status === 'failed'
            ? 'La génération de cette nuit a échoué — le prochain brief reprendra le fil.'
            : "Le brief du jour n'est pas encore prêt."}
        </p>
        <RegenerateButton />
        {lastReady ? (
          <a className={styles.fallbackLink} href={`/brief/${lastReady.brief_date}`}>
            Relire « {lastReady.title} » ({lastReady.brief_date})
          </a>
        ) : (
          <p className={styles.hint}>
            Ou en local : <code>npm run pipeline</code>.
          </p>
        )}
      </main>
    );
  }

  return (
    <BriefReader
      episode={brief.episode}
      sentences={brief.sentences}
      glossary={brief.glossary}
      audioUrl={brief.audioUrl}
      seriesTitle={brief.seriesTitle}
      totalPlanned={brief.totalPlanned}
    />
  );
}
