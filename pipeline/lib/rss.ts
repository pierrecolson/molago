/**
 * Récupération de titres d'actualité pour les séries « actu » (T4 : couche
 * sino-coréenne travaillée dans son registre). Parsing RSS minimal par regex —
 * on ne veut que titre + description.
 */

const FEEDS: { url: string; source: string; topics: string[] }[] = [
  { url: 'https://www.yna.co.kr/rss/news.xml', source: 'Yonhap', topics: ['actu'] },
  { url: 'https://www.yna.co.kr/rss/economy.xml', source: 'Yonhap éco', topics: ['actu', 'eco'] },
  { url: 'https://hnrss.org/frontpage', source: 'Hacker News', topics: ['tech'] },
];

export interface Headline {
  title: string;
  description: string;
  source: string;
}

function pickAll(xml: string, tag: string): string[] {
  return [...xml.matchAll(new RegExp(`<${tag}>([\\s\\S]*?)</${tag}>`, 'g'))].map((m) =>
    m[1]
      .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1')
      .replace(/<[^>]+>/g, '')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#?\w+;/g, ' ')
      .trim(),
  );
}

export async function fetchHeadlines(maxPerFeed = 5): Promise<Headline[]> {
  const all: Headline[] = [];
  for (const feed of FEEDS) {
    try {
      const res = await fetch(feed.url, { signal: AbortSignal.timeout(10000) });
      if (!res.ok) continue;
      const xml = await res.text();
      const items = xml.split(/<item[ >]/).slice(1, maxPerFeed + 1);
      for (const item of items) {
        const title = pickAll(item, 'title')[0];
        const description = pickAll(item, 'description')[0] ?? '';
        if (title) all.push({ title, description: description.slice(0, 300), source: feed.source });
      }
    } catch {
      // un flux en panne ne bloque jamais le pipeline
    }
  }
  return all;
}
