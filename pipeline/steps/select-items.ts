/**
 * Sélection des items du jour.
 * - Items DUS : lexeme_state.due_at <= aujourd'hui (FSRS), plafonnés — les autres attendent
 *   sans backlog (P4).
 * - Items NOUVEAUX : J1 = frontière de fréquence + priorité aux tags d'intérêt.
 *   (J2 : triple filtre complet fréquence × sujet × rendement hanja.)
 */
import { db } from '../lib/db';
import type { Lexeme } from '../../src/lib/types';
import type { TargetItem } from './generate';

const MAX_REVIEW = 8;
const MAX_MASKED = 3;
const NEW_MIN = 3;
const NEW_MAX = 6;

export interface SelectedItems {
  newItems: (TargetItem & { lexeme_id: string })[];
  reviewItems: (TargetItem & { lexeme_id: string; masked: boolean })[];
}

export async function selectItems(): Promise<SelectedItems> {
  const today = new Date().toISOString();

  // Items dus (FSRS), les plus urgents d'abord.
  const { data: due, error: dueErr } = await db()
    .from('lexeme_state')
    .select('lexeme_id, due_at, lexemes(id, lemma, gloss_fr, kind)')
    .in('state', ['seen', 'known'])
    .not('due_at', 'is', null)
    .lte('due_at', today)
    .order('due_at', { ascending: true })
    .limit(MAX_REVIEW);
  if (dueErr) throw new Error(`select due: ${dueErr.message}`);

  const reviewItems = (due ?? []).map((row, i) => {
    const lex = row.lexemes as unknown as Lexeme;
    return {
      lexeme_id: lex.id,
      lemma: lex.lemma,
      gloss_fr: lex.gloss_fr,
      kind: lex.kind,
      masked: i < MAX_MASKED, // les plus urgents sont masqués 2 s (micro-récupération)
    };
  });

  // Items nouveaux : triple filtre (T3) —
  // fenêtre de fréquence autour de la frontière de connaissance × pertinence
  // situationnelle (tags) × rendement morphologique hanja.
  const { data: withState } = await db().from('lexeme_state').select('lexeme_id');
  const excluded = new Set((withState ?? []).map((r) => r.lexeme_id));

  // Frontière de connaissance : rang p95 des lexèmes 'known' rangés.
  const { data: knownRanked } = await db()
    .from('lexeme_state')
    .select('lexemes(freq_rank)')
    .eq('state', 'known')
    .not('lexemes.freq_rank', 'is', null);
  const ranks = (knownRanked ?? [])
    .map((r) => (r.lexemes as unknown as { freq_rank: number | null })?.freq_rank)
    .filter((r): r is number => r !== null)
    .sort((a, b) => a - b);
  const frontier = ranks.length ? ranks[Math.floor(ranks.length * 0.95)] : 3000;

  const { data: candidates, error: candErr } = await db()
    .from('lexemes')
    .select('id, lemma, gloss_fr, kind, freq_rank, tags, hanja')
    .order('freq_rank', { ascending: true, nullsFirst: false })
    .limit(2000);
  if (candErr) throw new Error(`select new: ${candErr.message}`);

  const fresh = (candidates ?? []).filter((c) => !excluded.has(c.id));
  const score = (c: { freq_rank: number | null; tags: string[] | null; hanja: string | null }) => {
    // Proximité de la frontière (fenêtre utile : frontier ± 800).
    const rank = c.freq_rank ?? frontier + 400; // sans rang (expat) : dans la fenêtre
    const distance = Math.abs(rank - frontier);
    const proximity = Math.max(0, 1 - distance / 800);
    const situational = c.tags?.length ? 1 : 0; // liste expat/intérêts
    const hanjaYield = c.hanja ? 0.5 : 0;
    return proximity + situational + hanjaYield;
  };
  const scored = fresh.sort((a, b) => score(b) - score(a));

  const count = Math.min(NEW_MAX, Math.max(NEW_MIN, scored.length));
  const newItems = scored.slice(0, count).map((c) => ({
    lexeme_id: c.id,
    lemma: c.lemma,
    gloss_fr: c.gloss_fr,
    kind: c.kind as 'word' | 'chunk',
  }));

  return { newItems, reviewItems };
}
