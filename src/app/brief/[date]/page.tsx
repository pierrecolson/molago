import { notFound } from 'next/navigation';
import { fetchBrief } from '@/lib/brief';
import BriefReader from '@/components/BriefReader';

export const dynamic = 'force-dynamic';

// Relecture d'un brief passé (pas d'archive navigable — accessible uniquement
// via le lien de l'état dégradé ou une URL directe).
export default async function BriefByDate({ params }: { params: Promise<{ date: string }> }) {
  const { date } = await params;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) notFound();
  const brief = await fetchBrief(date);
  if (!brief) notFound();

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
