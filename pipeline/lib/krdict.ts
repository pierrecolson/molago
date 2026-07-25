/**
 * Client krdict (Dictionnaire coréen de base, API ouverte du NIKL).
 * https://krdict.korean.go.kr/openApi/openApiInfo — clé gratuite.
 * P9 : le glossaire est ancré sur un dictionnaire réel, jamais halluciné.
 * Réponses XML (l'API ne fait pas de JSON) — parsing par regex ciblées, suffisant
 * pour les champs plats utilisés ici.
 */

export interface KrdictSense {
  target_code: string;
  word: string;
  pos: string;
  definition_ko: string;
  translation_fr: string | null;
  definition_fr: string | null;
}

function pick(xml: string, tag: string): string | null {
  const m = xml.match(new RegExp(`<${tag}>([\\s\\S]*?)</${tag}>`));
  return m ? decodeEntities(m[1].trim()) : null;
}

function pickAll(xml: string, tag: string): string[] {
  return [...xml.matchAll(new RegExp(`<${tag}>([\\s\\S]*?)</${tag}>`, 'g'))].map((m) => m[1]);
}

function decodeEntities(s: string): string {
  return s
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, '&')
    .trim();
}

/** Cherche un mot dans krdict avec traductions françaises. Rend les sens trouvés. */
export async function krdictLookup(word: string): Promise<KrdictSense[]> {
  const key = process.env.KRDICT_API_KEY;
  if (!key) return [];
  const url =
    `https://krdict.korean.go.kr/api/search?key=${key}` +
    `&q=${encodeURIComponent(word)}&translated=y&trans_lang=3&advanced=y&method=exact&num=10`;
  const res = await fetch(url);
  if (!res.ok) return [];
  const xml = await res.text();
  const items = pickAll(xml, 'item');
  const senses: KrdictSense[] = [];
  for (const item of items) {
    const w = pick(item, 'word');
    if (!w) continue;
    for (const sense of pickAll(item, 'sense')) {
      senses.push({
        target_code: pick(item, 'target_code') ?? '',
        word: w,
        pos: pick(item, 'pos') ?? '',
        definition_ko: pick(sense, 'definition') ?? '',
        translation_fr: pick(sense, 'trans_word'),
        definition_fr: pick(sense, 'trans_dfn'),
      });
    }
  }
  return senses;
}
