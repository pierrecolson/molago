/**
 * Stealth assessment (P8) — appliqué côté serveur à partir des événements.
 * Modèle Kimchi Reader : unknown → seen → known, sans jamais tester frontalement.
 *
 * Règles :
 * - tap_gloss           → unknown→seen (source tap) ; sur un 'known' → rétrograde 'seen'
 *                         + FSRS Again ; remet exposures_since_tap à 0.
 * - quiz_answer correct → FSRS Good ; incorrect → FSRS Again (réinjection : le due_at
 *                         rapproché fera revenir l'item dans un prochain brief).
 * - episode_completed   → pour chaque item du glossaire de l'épisode NON tappé pendant
 *                         la lecture : exposition passive (exposures++, jour compté) ;
 *                         si l'item était dû → review passive FSRS Good.
 *                         Promotion seen→known : ≥ 5 expositions sans tap sur ≥ 3 jours.
 */
import type { SupabaseClient } from '@supabase/supabase-js';
import { reviewLexeme } from './fsrs';
import type { AppEvent, LexemeStateRow } from './types';

const PROMOTE_EXPOSURES = 5;
const PROMOTE_DAYS = 3;

async function getState(db: SupabaseClient, lexemeId: string): Promise<LexemeStateRow | null> {
  const { data } = await db.from('lexeme_state').select('*').eq('lexeme_id', lexemeId).maybeSingle();
  return data as LexemeStateRow | null;
}

export async function applyEvent(db: SupabaseClient, event: AppEvent): Promise<void> {
  const now = new Date();
  const today = now.toISOString().slice(0, 10);

  if (event.type === 'tap_gloss' && event.lexeme_id) {
    const state = await getState(db, event.lexeme_id);
    if (!state) {
      // Premier contact : unknown → seen, dû dès demain.
      await db.from('lexeme_state').upsert(
        {
          lexeme_id: event.lexeme_id,
          state: 'seen',
          source: 'tap',
          due_at: new Date(now.getTime() + 86400000).toISOString(),
          exposures: 1,
          exposures_since_tap: 0,
          exposure_days: [today],
        },
        { onConflict: 'lexeme_id' },
      );
      return;
    }
    // Un tap = l'item n'était pas si connu : Again + rétrogradation éventuelle.
    const fields = reviewLexeme(state, 'again', now);
    await db
      .from('lexeme_state')
      .update({
        ...fields,
        state: state.state === 'known' ? 'seen' : state.state === 'unknown' ? 'seen' : state.state,
        source: 'tap',
        exposures: state.exposures + 1,
        exposures_since_tap: 0,
        exposure_days: addDay(state.exposure_days, today),
      })
      .eq('lexeme_id', event.lexeme_id);
    return;
  }

  if (event.type === 'quiz_answer' && event.lexeme_id) {
    const correct = Boolean(event.payload?.correct);
    const state = await getState(db, event.lexeme_id);
    if (!state) return;
    const fields = reviewLexeme(state, correct ? 'good' : 'again', now);
    await db
      .from('lexeme_state')
      .update({ ...fields, source: 'quiz' })
      .eq('lexeme_id', event.lexeme_id);
    return;
  }

  if (event.type === 'episode_completed' && event.episode_id) {
    await db
      .from('episodes')
      .update({ read_at: now.toISOString() })
      .eq('id', event.episode_id)
      .is('read_at', null);

    // Items du glossaire de l'épisode…
    const { data: glossRows } = await db
      .from('episode_lexemes')
      .select('lexeme_id, occurrences')
      .eq('episode_id', event.episode_id);
    if (!glossRows?.length) return;

    // …moins ceux tappés pendant la lecture de cet épisode.
    const { data: taps } = await db
      .from('events')
      .select('lexeme_id')
      .eq('episode_id', event.episode_id)
      .eq('type', 'tap_gloss');
    const tapped = new Set((taps ?? []).map((t) => t.lexeme_id));

    for (const row of glossRows) {
      if (tapped.has(row.lexeme_id)) continue;
      const state = await getState(db, row.lexeme_id);
      if (!state) continue;

      const exposureDays = addDay(state.exposure_days, today);
      const exposures = state.exposures + (row.occurrences || 1);
      const exposuresSinceTap = state.exposures_since_tap + (row.occurrences || 1);

      const wasDue = state.due_at !== null && new Date(state.due_at) <= now;
      const fsrsFields = wasDue ? reviewLexeme(state, 'good', now) : {};

      const promote =
        state.state === 'seen' &&
        exposuresSinceTap >= PROMOTE_EXPOSURES &&
        exposureDays.length >= PROMOTE_DAYS;

      await db
        .from('lexeme_state')
        .update({
          ...fsrsFields,
          state: promote ? 'known' : state.state,
          exposures,
          exposures_since_tap: exposuresSinceTap,
          exposure_days: exposureDays,
        })
        .eq('lexeme_id', row.lexeme_id);
    }
  }
}

function addDay(days: string[] | null, today: string): string[] {
  const set = new Set(days ?? []);
  set.add(today);
  // Garde une fenêtre bornée (60 jours suffisent pour la promotion).
  return [...set].sort().slice(-60);
}
