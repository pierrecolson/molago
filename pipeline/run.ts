/**
 * Orchestrateur du pipeline nocturne. Idempotent : si l'épisode du jour est déjà
 * 'ready', ne fait rien (le job de rattrapage peut donc tourner sans risque).
 *
 * Usage : npm run pipeline [-- --date=YYYY-MM-DD] [--force]
 */
import { db } from './lib/db';
import { getKiwi } from './lib/kiwi';
import { lemmaKey } from './lib/normalize';
import { planSeries } from './steps/plan';
import { selectItems } from './steps/select-items';
import { generateEpisode, rewriteEpisode, GeneratedEpisode } from './steps/generate';
import { verifyCoverage, VerifyResult } from './steps/verify';
import { annotateSentences } from './steps/annotate';
import { synthesizeEpisode } from './lib/tts';

const MAX_REWRITES = 2;
const MAX_REGENERATIONS = 1;
const COVERAGE_THRESHOLD = 96;

function kstToday(): string {
  return new Date(Date.now() + 9 * 3600 * 1000).toISOString().slice(0, 10);
}

function argValue(name: string): string | null {
  const arg = process.argv.find((a) => a.startsWith(`--${name}=`));
  return arg ? arg.split('=')[1] : null;
}

async function loadKnownLemmas(): Promise<Set<string>> {
  const known = new Set<string>();
  let from = 0;
  const PAGE = 1000;
  for (;;) {
    const { data, error } = await db()
      .from('lexeme_state')
      .select('lexemes(lemma)')
      .in('state', ['known', 'seen'])
      .range(from, from + PAGE - 1);
    if (error) throw new Error(`loadKnownLemmas: ${error.message}`);
    for (const row of data ?? []) {
      const lex = row.lexemes as unknown as { lemma: string } | null;
      if (lex?.lemma) known.add(lemmaKey(lex.lemma));
    }
    if (!data || data.length < PAGE) break;
    from += PAGE;
  }
  return known;
}

async function main() {
  const briefDate = argValue('date') ?? kstToday();
  const force = process.argv.includes('--force');
  console.log(`[pipeline] brief du ${briefDate}`);

  const { data: existing } = await db()
    .from('episodes')
    .select('id, status')
    .eq('brief_date', briefDate)
    .maybeSingle();
  if (existing && existing.status === 'ready' && !force) {
    console.log('[pipeline] épisode déjà prêt — rien à faire.');
    return;
  }
  if (existing && (force || existing.status !== 'ready')) {
    await db().from('episodes').delete().eq('id', existing.id);
  }

  const meta: Record<string, unknown> = { started_at: new Date().toISOString(), usage: [] };
  const usages = meta.usage as { step: string; input_tokens: number; output_tokens: number }[];

  // 1. Série
  const { series, usage: planUsage } = await planSeries();
  if (planUsage) usages.push({ step: 'plan', ...planUsage });
  const { count: prevCount } = await db()
    .from('episodes')
    .select('id', { count: 'exact', head: true })
    .eq('series_id', series.id);
  const episodeNumber = (prevCount ?? 0) + 1;
  console.log(`[pipeline] série « ${series.title} », épisode ${episodeNumber}`);

  // Résumé de l'épisode précédent (teaser + titre suffisent en J1).
  const { data: prev } = await db()
    .from('episodes')
    .select('title, teaser_next')
    .eq('series_id', series.id)
    .order('episode_number', { ascending: false })
    .limit(1)
    .maybeSingle();
  const previousSummary = prev ? `« ${prev.title} » — ${prev.teaser_next ?? ''}` : null;

  // 2. Items du jour
  const { newItems, reviewItems } = await selectItems();
  console.log(
    `[pipeline] cibles : ${newItems.map((i) => i.lemma).join(', ')} | révision : ${reviewItems.map((i) => i.lemma).join(', ') || '—'}`,
  );

  // 3-5. Générer → vérifier → réécrire (boucle SRS-Stories)
  const knownLemmas = await loadKnownLemmas();
  const kiwi = await getKiwi();
  const targetLemmas = newItems.map((i) => i.lemma);
  const properNouns = series.series_bible?.proper_nouns ?? [];

  let episode: GeneratedEpisode | null = null;
  let verdict: VerifyResult | null = null;
  let accepted = false;

  for (let regen = 0; regen <= MAX_REGENERATIONS && !accepted; regen++) {
    const gen = await generateEpisode({ series, episodeNumber, previousSummary, newItems, reviewItems });
    episode = gen.episode;
    usages.push({ step: `generate#${regen}`, ...gen.usage });

    for (let attempt = 0; attempt <= MAX_REWRITES; attempt++) {
      verdict = await verifyCoverage(
        {
          sentences: episode.sentences.map((s) => s.ko),
          knownLemmas,
          targetLemmas,
          properNouns,
          thresholdPct: COVERAGE_THRESHOLD,
          minTargetOccurrences: 2,
        },
        kiwi,
      );
      console.log(
        `[pipeline] couverture ${verdict.coveragePct}% — intrus: ${verdict.intruders.length}, cibles manquantes: ${verdict.missingTargets.length}`,
      );
      if (verdict.ok) {
        accepted = true;
        break;
      }
      if (attempt === MAX_REWRITES) break;
      const rw = await rewriteEpisode({
        episode,
        intruders: verdict.intruders.slice(0, 12),
        missingTargets: verdict.missingTargets,
      });
      episode = rw.episode;
      usages.push({ step: `rewrite#${regen}.${attempt}`, ...rw.usage });
    }
  }

  if (!episode || !verdict) throw new Error('pipeline: génération vide');
  meta.coverage = verdict;
  if (!accepted) {
    // Meilleur effort refusé : on marque failed avec le diagnostic (état dégradé côté UI).
    await db().from('episodes').insert({
      series_id: series.id,
      brief_date: briefDate,
      episode_number: episodeNumber,
      title: episode.title,
      status: 'failed',
      generation_meta: { ...meta, failed_reason: 'coverage', finished_at: new Date().toISOString() },
    });
    throw new Error(`pipeline: couverture insuffisante après réécritures (${verdict.coveragePct}%)`);
  }

  // 6. Annotation + glossaire krdict
  const { annotated, glossary } = await annotateSentences({
    sentences: episode.sentences,
    newItems,
    reviewItems,
  });

  // 7. (J3 : quiz cloze déterministe)

  // 8. TTS + timings
  console.log('[pipeline] synthèse TTS…');
  const tts = await synthesizeEpisode(episode.sentences.map((s) => s.ko));
  const audioPath = `${briefDate}.mp3`;
  const { error: upErr } = await db()
    .storage.from('audio')
    .upload(audioPath, tts.mp3, { contentType: 'audio/mpeg', upsert: true });
  if (upErr) throw new Error(`upload audio: ${upErr.message}`);

  // 9. Commit
  const wordCount = episode.sentences.reduce((n, s) => n + s.ko.split(/\s+/).length, 0);
  const { data: epRow, error: epErr } = await db()
    .from('episodes')
    .insert({
      series_id: series.id,
      brief_date: briefDate,
      episode_number: episodeNumber,
      title: episode.title,
      teaser_next: episode.teaser_next,
      status: 'ready',
      word_count: wordCount,
      est_read_min: Math.max(3, Math.round(tts.durationMs / 60000) + 2),
      coverage_pct: verdict.coveragePct,
      audio_path: audioPath,
      audio_duration_ms: tts.durationMs,
      try_today: episode.try_today,
      generation_meta: { ...meta, finished_at: new Date().toISOString() },
    })
    .select('id')
    .single();
  if (epErr) throw new Error(`insert episode: ${epErr.message}`);

  const sentenceRows = annotated.map((s, i) => ({
    episode_id: epRow.id,
    idx: i,
    text_ko: s.text_ko,
    translation_fr: s.translation_fr,
    audio_start_ms: tts.timings[i]?.startMs ?? null,
    audio_end_ms: tts.timings[i]?.endMs ?? null,
    tokens: s.tokens,
  }));
  const { error: sErr } = await db().from('sentences').insert(sentenceRows);
  if (sErr) throw new Error(`insert sentences: ${sErr.message}`);

  const { error: gErr } = await db()
    .from('episode_lexemes')
    .insert(glossary.map((g) => ({ ...g, episode_id: epRow.id })));
  if (gErr) throw new Error(`insert glossaire: ${gErr.message}`);

  // Les nouveaux items entrent dans le profil : 'seen', dû demain (FSRS complet en J2).
  const tomorrow = new Date(Date.now() + 24 * 3600 * 1000).toISOString();
  for (const item of newItems) {
    await db()
      .from('lexeme_state')
      .upsert(
        {
          lexeme_id: item.lexeme_id,
          state: 'seen',
          source: 'pipeline',
          due_at: tomorrow,
          exposures: glossary.find((g) => g.lexeme_id === item.lexeme_id)?.occurrences ?? 0,
        },
        { onConflict: 'lexeme_id' },
      );
  }

  console.log(`[pipeline] ✓ épisode « ${episode.title} » prêt (${verdict.coveragePct}% de couverture, ${Math.round(tts.durationMs / 1000)}s d'audio)`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
