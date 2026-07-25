import { NextRequest, NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase-server';
import { applyEvent } from '@/lib/assessment';
import type { AppEvent, AppEventType } from '@/lib/types';

const VALID_TYPES = new Set<AppEventType>([
  'tap_gloss',
  'hanja_open',
  'quiz_answer',
  'episode_completed',
  'flag_awkward',
  'audio_replay',
  'mask_revealed_early',
]);

// Réception en batch (sendBeacon). J2 : applique aussi les règles de stealth
// assessment (unknown→seen, FSRS) côté serveur à partir de ces événements.
export async function POST(request: NextRequest) {
  let body: { events?: AppEvent[] };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'JSON invalide' }, { status: 400 });
  }
  const events = (body.events ?? []).filter((e) => VALID_TYPES.has(e.type)).slice(0, 100);
  if (events.length === 0) return NextResponse.json({ inserted: 0 });

  const rows = events.map((e) => ({
    type: e.type,
    episode_id: e.episode_id ?? null,
    sentence_id: e.sentence_id ?? null,
    lexeme_id: e.lexeme_id ?? null,
    payload: e.payload ?? null,
  }));

  const db = supabaseAdmin();
  const { error } = await db.from('events').insert(rows);
  if (error) return NextResponse.json({ error: error.message }, { status: 500 });

  // Stealth assessment : chaque événement fait évoluer le profil lexical.
  // Séquentiel volontairement (les règles lisent l'état qu'elles modifient).
  for (const event of events) {
    try {
      await applyEvent(db, event);
    } catch (err) {
      console.error('assessment:', err); // l'ingestion des events reste acquise
    }
  }

  return NextResponse.json({ inserted: rows.length });
}
