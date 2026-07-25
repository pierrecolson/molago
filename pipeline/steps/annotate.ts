/**
 * Annotation : segmentation Kiwi de chaque phrase → spans tappables (offsets),
 * résolution vers les lexèmes connus en base, glossaire d'épisode ancré krdict
 * (fallback : gloss LLM déjà présent en base, marqué 'unverified').
 */
import { db } from '../lib/db';
import { getKiwi } from '../lib/kiwi';
import { isContentTag, lemmaKey } from '../lib/normalize';
import { krdictLookup } from '../lib/krdict';
import type { TokenSpan } from '../../src/lib/types';
import type { TargetItem } from './generate';

export interface AnnotatedSentence {
  text_ko: string;
  translation_fr: string;
  tokens: TokenSpan[];
}

export interface GlossaryEntry {
  lexeme_id: string;
  role: 'new' | 'review';
  occurrences: number;
  gloss_fr: string;
  gloss_source: 'krdict' | 'unverified';
  collocation: string | null;
  krdict_sense: unknown;
}

export async function annotateSentences(opts: {
  sentences: { ko: string; fr: string }[];
  newItems: (TargetItem & { lexeme_id: string })[];
  reviewItems: (TargetItem & { lexeme_id: string; masked: boolean })[];
}): Promise<{ annotated: AnnotatedSentence[]; glossary: GlossaryEntry[] }> {
  const kiwi = await getKiwi();

  // Lemme → lexème connu en base (pour rendre chaque token tappable).
  const allLemmas = new Set<string>();
  const perSentenceTokens: { lemma: string; tag: string; position: number; length: number; str: string }[][] = [];
  for (const s of opts.sentences) {
    const tokens = await kiwi.analyze(s.ko);
    const content = tokens.filter((t) => isContentTag(t.tag));
    content.forEach((t) => allLemmas.add(lemmaKey(t.str)));
    perSentenceTokens.push(content.map((t) => ({ ...t, lemma: lemmaKey(t.str) })));
  }

  const { data: lexRows } = await db()
    .from('lexemes')
    .select('id, lemma')
    .in('lemma', [...allLemmas]);
  const lemmaToId = new Map((lexRows ?? []).map((r) => [r.lemma, r.id]));

  const roleById = new Map<string, { role: 'new' | 'review'; masked: boolean }>();
  opts.newItems.forEach((i) => roleById.set(i.lexeme_id, { role: 'new', masked: false }));
  opts.reviewItems.forEach((i) => roleById.set(i.lexeme_id, { role: 'review', masked: i.masked }));

  const occurrences = new Map<string, number>();
  const annotated: AnnotatedSentence[] = opts.sentences.map((s, si) => {
    const tokens: TokenSpan[] = perSentenceTokens[si].map((t) => {
      const lexeme_id = lemmaToId.get(t.lemma);
      const span: TokenSpan = {
        s: t.position,
        e: t.position + t.length,
        surface: s.ko.slice(t.position, t.position + t.length),
        lemma: t.lemma,
        pos: t.tag,
      };
      if (lexeme_id) {
        span.lexeme_id = lexeme_id;
        occurrences.set(lexeme_id, (occurrences.get(lexeme_id) ?? 0) + 1);
        const role = roleById.get(lexeme_id);
        if (role) {
          span.role = role.role;
          // Seule la 1re occurrence d'un item en révision est masquée (2 s).
          if (role.masked && occurrences.get(lexeme_id) === 1) span.masked = true;
        }
      }
      return span;
    });
    return { text_ko: s.ko, translation_fr: s.fr, tokens };
  });

  // Glossaire pour les items du jour (nouveaux + révision), ancré krdict.
  const glossary: GlossaryEntry[] = [];
  const items = [
    ...opts.newItems.map((i) => ({ ...i, role: 'new' as const })),
    ...opts.reviewItems.map((i) => ({ ...i, role: 'review' as const })),
  ];
  for (const item of items) {
    let gloss_fr = item.gloss_fr ?? '';
    let gloss_source: 'krdict' | 'unverified' = 'unverified';
    let krdict_sense: unknown = null;

    // Cache krdict en base d'abord.
    const { data: lexRow } = await db()
      .from('lexemes')
      .select('krdict_cache, gloss_fr')
      .eq('id', item.lexeme_id)
      .single();
    if (lexRow?.krdict_cache) {
      krdict_sense = lexRow.krdict_cache;
      gloss_source = 'krdict';
      gloss_fr = extractGloss(lexRow.krdict_cache) ?? gloss_fr;
    } else {
      const senses = await krdictLookup(item.lemma);
      if (senses.length > 0) {
        krdict_sense = senses[0];
        gloss_source = 'krdict';
        gloss_fr = senses[0].translation_fr ?? senses[0].definition_fr ?? gloss_fr;
        await db()
          .from('lexemes')
          .update({ krdict_cache: senses[0], krdict_id: senses[0].target_code })
          .eq('id', item.lexeme_id);
      } else if (lexRow?.gloss_fr) {
        gloss_fr = lexRow.gloss_fr; // gloss manuel (liste expat) : fiable mais hors dico
      }
    }

    glossary.push({
      lexeme_id: item.lexeme_id,
      role: item.role,
      occurrences: occurrences.get(item.lexeme_id) ?? 0,
      gloss_fr,
      gloss_source,
      collocation: null, // J3 : rédigée par le LLM lors de la passe de révision
      krdict_sense,
    });
  }

  return { annotated, glossary };
}

function extractGloss(cache: unknown): string | null {
  if (cache && typeof cache === 'object') {
    const c = cache as { translation_fr?: string; definition_fr?: string };
    return c.translation_fr ?? c.definition_fr ?? null;
  }
  return null;
}
