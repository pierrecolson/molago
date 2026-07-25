import { NextRequest, NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase-server';

/**
 * GET  : échantillon de placement — ~8 mots par bande de fréquence (10 bandes)
 *        + bande « expat ». Fallback bandes par grade NIKL si pas de rangs.
 * POST : { responses: [{lexeme_id, band, known}] } → stocke, initialise le profil :
 *        - réponses individuelles → known/unknown (source placement)
 *        - bandes avec ≥ 85 % de connus (en partant du facile) → tous les lexèmes
 *          de rangs inférieurs = known (source placement_prior)
 *        - bandes 40–85 % → seen ; au-delà → unknown (rien à écrire).
 */

const RANK_BANDS: [number, number][] = [
  [1, 500], [501, 1000], [1001, 1500], [1501, 2000], [2001, 2500],
  [2501, 3000], [3001, 3500], [3501, 4000], [4001, 5000], [5001, 6000],
];
const PER_BAND = 8;
const KNOWN_P = 0.85;
const SEEN_P = 0.4;

function sample<T>(arr: T[], n: number): T[] {
  const copy = [...arr];
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy.slice(0, n);
}

export async function GET() {
  const db = supabaseAdmin();
  const { count: ranked } = await db
    .from('lexemes')
    .select('id', { count: 'exact', head: true })
    .not('freq_rank', 'is', null);

  const bands: { band: number; label: string; words: { lexeme_id: string; lemma: string }[] }[] = [];

  if ((ranked ?? 0) >= 1000) {
    for (let b = 0; b < RANK_BANDS.length; b++) {
      const [lo, hi] = RANK_BANDS[b];
      const { data } = await db
        .from('lexemes')
        .select('id, lemma')
        .gte('freq_rank', lo)
        .lte('freq_rank', hi)
        .eq('kind', 'word')
        .limit(300);
      bands.push({
        band: b + 1,
        label: `${lo}–${hi}`,
        words: sample(data ?? [], PER_BAND).map((w) => ({ lexeme_id: w.id, lemma: w.lemma })),
      });
    }
  } else {
    // Fallback : bandes par grade NIKL (A/B/C).
    const grades: ('A' | 'B' | 'C')[] = ['A', 'B', 'C'];
    for (let g = 0; g < grades.length; g++) {
      const { data } = await db
        .from('lexemes')
        .select('id, lemma')
        .eq('nikl_grade', grades[g])
        .eq('kind', 'word')
        .limit(500);
      bands.push({
        band: g + 1,
        label: `NIKL ${grades[g]}`,
        words: sample(data ?? [], 10).map((w) => ({ lexeme_id: w.id, lemma: w.lemma })),
      });
    }
  }

  // Bande expat (mots seuls, les chunks se testent mal en binaire).
  const { data: expat } = await db
    .from('lexemes')
    .select('id, lemma')
    .contains('tags', ['expat'])
    .eq('kind', 'word')
    .limit(300);
  bands.push({
    band: 11,
    label: 'vie quotidienne',
    words: sample(expat ?? [], PER_BAND).map((w) => ({ lexeme_id: w.id, lemma: w.lemma })),
  });

  return NextResponse.json({ bands: bands.filter((b) => b.words.length > 0) });
}

interface PlacementResponse {
  lexeme_id: string;
  band: number;
  known: boolean;
}

export async function POST(request: NextRequest) {
  const db = supabaseAdmin();
  let body: { responses?: PlacementResponse[] };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'JSON invalide' }, { status: 400 });
  }
  const responses = (body.responses ?? []).slice(0, 200);
  if (responses.length === 0) return NextResponse.json({ error: 'aucune réponse' }, { status: 400 });

  await db.from('placement_responses').insert(
    responses.map((r) => ({ band: r.band, lexeme_id: r.lexeme_id, known: r.known })),
  );

  // 1. Réponses individuelles.
  for (const r of responses) {
    await db.from('lexeme_state').upsert(
      {
        lexeme_id: r.lexeme_id,
        state: r.known ? 'known' : 'unknown',
        source: 'placement',
      },
      { onConflict: 'lexeme_id' },
    );
  }

  // 2. Généralisation par bande de rang (uniquement bandes 1-10).
  const byBand = new Map<number, { known: number; total: number }>();
  for (const r of responses) {
    if (r.band > RANK_BANDS.length) continue;
    const s = byBand.get(r.band) ?? { known: 0, total: 0 };
    s.total++;
    if (r.known) s.known++;
    byBand.set(r.band, s);
  }

  let knownUpTo = 0; // rang jusqu'auquel on considère tout connu
  let seenUpTo = 0;
  let dips = 0;
  for (let b = 1; b <= RANK_BANDS.length; b++) {
    const s = byBand.get(b);
    if (!s || s.total === 0) break;
    const p = s.known / s.total;
    if (p >= KNOWN_P && dips === 0) {
      knownUpTo = RANK_BANDS[b - 1][1];
    } else if (p >= SEEN_P) {
      dips++;
      seenUpTo = RANK_BANDS[b - 1][1];
      if (dips >= 2) break; // deux bandes moyennes de suite : on arrête la généralisation
    } else {
      break;
    }
  }

  let knownCount = 0;
  let seenCount = 0;
  if (knownUpTo > 0) {
    const { data: rows } = await db
      .from('lexemes')
      .select('id')
      .lte('freq_rank', knownUpTo)
      .not('freq_rank', 'is', null);
    for (const batchStart of range(0, rows?.length ?? 0, 500)) {
      const batch = (rows ?? []).slice(batchStart, batchStart + 500).map((r) => ({
        lexeme_id: r.id,
        state: 'known',
        source: 'placement_prior',
      }));
      if (batch.length) {
        await db.from('lexeme_state').upsert(batch, { onConflict: 'lexeme_id', ignoreDuplicates: true });
        knownCount += batch.length;
      }
    }
  }
  if (seenUpTo > knownUpTo) {
    const { data: rows } = await db
      .from('lexemes')
      .select('id')
      .gt('freq_rank', knownUpTo)
      .lte('freq_rank', seenUpTo)
      .not('freq_rank', 'is', null);
    for (const batchStart of range(0, rows?.length ?? 0, 500)) {
      const batch = (rows ?? []).slice(batchStart, batchStart + 500).map((r) => ({
        lexeme_id: r.id,
        state: 'seen',
        source: 'placement_prior',
      }));
      if (batch.length) {
        await db.from('lexeme_state').upsert(batch, { onConflict: 'lexeme_id', ignoreDuplicates: true });
        seenCount += batch.length;
      }
    }
  }

  return NextResponse.json({ initialized: { known: knownCount, seen: seenCount, knownUpTo, seenUpTo } });
}

function range(start: number, end: number, step: number): number[] {
  const out: number[] = [];
  for (let i = start; i < end; i += step) out.push(i);
  return out;
}
