import { NextRequest, NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase-server';
import type { HanjaFamily } from '@/lib/types';

/**
 * Panneau « famille de mots » hanja : les lexèmes partageant le premier caractère
 * hanja du mot tappé. Calcul déterministe depuis la base, mis en cache dans
 * lexemes.hanja_family.
 */
export async function GET(_req: NextRequest, ctx: { params: Promise<{ lexemeId: string }> }) {
  const { lexemeId } = await ctx.params;
  const db = supabaseAdmin();

  const { data: lexeme } = await db
    .from('lexemes')
    .select('id, lemma, hanja, hanja_family')
    .eq('id', lexemeId)
    .maybeSingle();
  if (!lexeme?.hanja) return NextResponse.json({ family: null });
  if (lexeme.hanja_family) return NextResponse.json({ family: lexeme.hanja_family });

  const char = [...lexeme.hanja][0];
  const reading = lexeme.lemma[0] ?? '';
  const { data: members } = await db
    .from('lexemes')
    .select('lemma, hanja, gloss_fr')
    .like('hanja', `%${char}%`)
    .neq('id', lexeme.id)
    .limit(8);

  const family: HanjaFamily = {
    char,
    reading,
    meaning_fr: '',
    members: (members ?? [])
      .filter((m) => m.gloss_fr)
      .map((m) => ({ lemma: m.lemma, hanja: m.hanja ?? '', gloss_fr: m.gloss_fr ?? '' })),
  };

  if (family.members.length > 0) {
    await db.from('lexemes').update({ hanja_family: family }).eq('id', lexeme.id);
  }
  return NextResponse.json({ family: family.members.length > 0 ? family : null });
}
