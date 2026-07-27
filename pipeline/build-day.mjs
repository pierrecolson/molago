#!/usr/bin/env node
// La chaîne de fabrication nocturne — version M1.
//
// Produit la journée complète : trois textes coréens, découpés en phrases, avec
// une piste audio par phrase. Le découpage par phrase n'est pas un détail de
// confort : c'est lui qui rend le surlignage suivant la voix trivial côté app
// (spec §9, étape 9).
//
//   node pipeline/build-day.mjs [--date 2026-07-28] [--out <dir>]
//
// Sortie : <out>/<date>.json  ·  <out>/audio/<date>-<slot>-<nn>.mp3
//
// Ce qui n'est PAS encore là, et pourquoi :
//   · contrôle de niveau (Kiwi)  → M2 : il n'y a pas encore de profil de
//     vocabulaire à comparer, donc rien à contrôler.
//   · glossaire et mots tappables → M2 : personne ne tape encore de mot.
//   · quiz                        → M3.

import { writeFileSync, mkdirSync, existsSync, readFileSync, renameSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')
const UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'

const MODEL = 'openai/gpt-5.1'                    // decisions.md §32
// Neural2 B plutôt que Chirp3-HD : à l'écoute comparée elle tient, et surtout
// c'est la seule famille qui renvoie les repères temporels des marqueurs SSML.
// Chirp3-HD accepte le balisage mais rend une liste vide — donc pas de
// surlignage mot à mot avec elle. Voir decisions.md §36.
const VOICE = 'ko-KR-Neural2-B'

// La spec promet « 3 à 4 minutes » et affiche cette durée sur la carte. À la
// vitesse de lecture mesurée, 380 어절 font quatre minutes : c'est le plafond
// au-delà duquel la carte mentirait.
const MAX_EOJEOL = 380

// Le débit du MP3 dépend de la famille de voix : Neural2 rend du 64 kbps là où
// Chirp3-HD rendait du 32. La durée annoncée sur la carte s'en déduit, donc une
// valeur fausse ici fait mentir le contrat de durée — vérifiée à l'oreille et
// recoupée plus bas avec les repères SSML.
const MP3_KBPS = 64

// Trois univers, trois couches de langue. C'est l'écart entre ces couches qui
// fait plafonner les résidents de longue durée (spec §8.2).
const SLOTS = [
  {
    // Sources internationales, réécrites en coréen : c'est le slot « cerveau »,
    // et c'est ce qui le distingue d'une troisième dose d'actualité coréenne.
    id: 'tech', universe: 'Tech & Science', register: 'journalistique, sino-coréen dense',
    hackerNews: true,
    interest: "quelqu'un qui travaille dans la tech et lit Hacker News le matin",
  },
  {
    id: 'korea', universe: 'Korea', register: 'journalistique courant',
    feeds: ['https://rss.donga.com/total.xml', 'https://www.yna.co.kr/rss/news.xml'],
    interest: "un étranger installé à Séoul qui veut lire ce dont ses collègues parleront aujourd'hui",
  },
  {
    id: 'daily', universe: 'Daily life', register: 'parlé, 해요체',
    situations: true,
  },
]

// Le carnet est vide au premier jour : le slot 3 tourne sur un fonds de
// situations d'expat (spec §8.2, et §12 « carnet vide »).
const SITUATIONS = [
  "recevoir une facture de charges (관리비) plus élevée que d'habitude et appeler le 관리사무소",
  "aller à la pharmacie de quartier décrire un symptôme et repartir avec un traitement",
  "un colis livré chez le voisin, et la conversation avec le gardien de l'immeuble",
  "renouveler un abonnement de téléphone dans une boutique, avec les options qu'on essaie de vous vendre",
  "un 회식 de bureau un vendredi soir : qui commande, qui paie, comment on part poliment",
  "faire réparer une fuite d'eau dans un appartement en location, et qui paie quoi entre 세입자 et 집주인",
  "ouvrir un compte en banque : les papiers, le 도장, les questions du guichetier",
  "commander au restaurant quand le plat n'est plus disponible, et se faire conseiller autre chose",
]

// ── plomberie ────────────────────────────────────────────────────────────────

const env = (() => {
  const out = { ...process.env }
  const p = join(ROOT, '.env')
  if (existsSync(p)) {
    for (const l of readFileSync(p, 'utf8').split('\n')) {
      const m = l.match(/^\s*([A-Z_][A-Z0-9_]*)\s*=\s*(.*)$/)
      if (m && m[2].trim()) out[m[1]] = m[2].trim().replace(/^["']|["']$/g, '')
    }
  }
  return out
})()

const arg = (n, d = null) => {
  const i = process.argv.indexOf(`--${n}`)
  return i > -1 ? process.argv[i + 1] : d
}
const log = (...a) => console.log(...a)
const strip = (s) => s.replace(/<[^>]+>/g, '')
const unent = (s) => s.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"')
  .replace(/&#39;/g, "'").replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&')
const pad = (n) => String(n).padStart(2, '0')

async function get(url, headers = {}, tries = 3) {
  let last
  for (let i = 0; i < tries; i++) {
    try {
      const r = await fetch(url, {
        headers: { 'user-agent': UA, accept: '*/*', ...headers },
        signal: AbortSignal.timeout(25000),
      })
      if (!r.ok) throw new Error(`${r.status} ${r.statusText}`)
      return r
    } catch (e) {
      last = e
      if (i < tries - 1) await new Promise((r) => setTimeout(r, 800 * (i + 1)))
    }
  }
  throw new Error(`${last?.message || 'échec'} — ${url}`)
}

async function llm(prompt, { json = false } = {}) {
  const r = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      authorization: `Bearer ${env.OPENROUTER_API_KEY}`,
      'content-type': 'application/json',
      'x-title': 'Molago pipeline',
    },
    body: JSON.stringify({
      model: MODEL,
      messages: [{ role: 'user', content: prompt }],
      max_tokens: 8000,
      ...(json ? { response_format: { type: 'json_object' } } : {}),
    }),
  })
  const j = await r.json()
  if (!r.ok || j.error) throw new Error(j.error?.message || `HTTP ${r.status}`)
  let out = (j.choices?.[0]?.message?.content || '').trim()
  if (!out) throw new Error('réponse vide')
  if (json) {
    out = out.replace(/^```(?:json)?\s*|\s*```$/g, '')
    return JSON.parse(out.slice(out.indexOf('{'), out.lastIndexOf('}') + 1))
  }
  return out
}

// ── source : un article coréen du jour ───────────────────────────────────────

const JUNK = ['연합뉴스만의', '구글 검색', '제보는', '카카오톡', '저작권자', '무단 전재',
  '기사제보', '네이버에서', '이 기사는', '앱 다운로드', '구독', '댓글']

// Extracteur générique : on aplatit la page en lignes et on garde celles qui
// ressemblent à de la prose coréenne. Aucun sélecteur propre à un journal, donc
// rien à réparer quand un site refait sa maquette.
function bodyFrom(html, korean = true) {
  const lines = html
    .replace(/<(script|style|noscript)[\s\S]*?<\/\1>/gi, ' ')
    .replace(/<br\s*\/?>|<\/(p|div|li|h[1-6]|section|article)>/gi, '\n')
    .split('\n')
    .map((l) => unent(strip(l)).replace(/\s+/g, ' ').trim())
  const script = korean ? /[가-힣]/ : /[A-Za-z]{3}/
  const ok = (t) => t.length > 45 && script.test(t) &&
    /[.?!"'”’\]]$|다\.?$/.test(t) && !JUNK.some((j) => t.includes(j))
  return [...new Set(lines.filter(ok))]
    .map((t) => t.replace(/^\([^)]{2,30}\)\s*[^=]{0,20}=\s*/, ''))
}

const SKIP = /날씨|부고|프로야구|프로축구|증시|환율|종합\s*\d|일지|인사|동정|사진|영상/
const PRESS_RELEASE =
  /[가-힣]+(군|시|도|청|공사|공단|재단)[,\s].*(확정|추진|착수|개최|위촉|기탁|협약|간담회|워크숍|선정|준공|개소|출범|시행|모집)/
const GOSSIP = /연예|배우|가수|아이돌|드라마|예능|열애|결혼설|불화설|이혼|팬미팅|컴백|소속사/

// Le choix du sujet est confié au modèle plutôt qu'à des expressions
// régulières. Les filtres attrapent les cas connus ; ils ne sauront jamais
// qu'un article sur la mascotte d'un canton n'a rien à faire en « Tech ». Une
// liste de titres et une question suffisent, et c'est l'étape 2 de la spec §9.
const CHOOSE = (slot, items) => `Voici les titres du jour. Choisis le SEUL qui mérite d'être lu par ${slot.interest}.

${items.map((it, i) => `${i}. ${it.title}`).join('\n')}

Écarte sans hésiter : les communiqués d'entreprise et de collectivité, les remises de prix,
les annonces de festivals ou d'événements locaux, les mascottes, le publireportage, les
brèves sans substance, et tout ce qui ne se raconterait pas à quelqu'un autour d'un café.

Le critère est unique : « l'aurait-il lu si c'était dans sa langue ? »

Réponds en JSON : {"indexes": [<le meilleur>, <le deuxième>, <le troisième>], "why": "une phrase en français sur le premier"}
Classe-les du meilleur au moins bon. Si moins de trois titres passent le critère, n'en donne que ceux-là. Si aucun ne passe, réponds {"indexes": [], "why": "..."}.`

// On demande un classement plutôt qu'un choix unique : quand la page du premier
// article résiste à l'extraction, un créneau entier ne doit pas disparaître pour
// autant.
async function chooseFrom(slot, items) {
  const shortlist = items.slice(0, 30)
  const pick = await llm(CHOOSE(slot, shortlist), { json: true })
  const idx = (pick.indexes || []).filter((i) => Number.isInteger(i) && i >= 0 && i < shortlist.length)
  if (!idx.length) return []
  log(`    choix : ${pick.why || ''}`)
  return idx.map((i) => shortlist[i])
}

async function pickArticle(slot, used) {
  let items = []
  for (const f of slot.feeds) {
    try {
      const xml = await (await get(f)).text()
      items = [...xml.matchAll(/<item>([\s\S]*?)<\/item>/g)].map((m) => ({
        title: unent((m[1].match(/<title>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/title>/)?.[1] || '').trim()),
        url: (m[1].match(/<link>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/link>/)?.[1] || '').trim(),
      }))
      if (items.length) break
    } catch { /* flux suivant */ }
  }
  // Les filtres mécaniques ne font que dégrossir : ils écartent ce qui n'a
  // jamais d'intérêt, le modèle tranche sur le reste.
  const cands = items
    .filter((i) => i.url && !used.has(i.url))
    .filter((i) => !SKIP.test(i.title) && !PRESS_RELEASE.test(i.title) && !GOSSIP.test(i.title))
    .filter((i) => !/\/(Entertainment|Sports|Photo)\//i.test(i.url))
  if (!cands.length) return null

  // Si le modèle ne trouve rien de lisible, on ne force pas : mieux vaut deux
  // bons textes que trois dont un sans intérêt (spec §12).
  for (const c of await chooseFrom(slot, cands)) {
    try {
      const paras = bodyFrom(await (await get(c.url)).text())
      if (paras.join(' ').length >= 700) return { ...c, paras }
    } catch { /* candidat suivant */ }
    await new Promise((r) => setTimeout(r, 400))
  }
  return null
}

// Slot 1 : sources internationales. Hacker News donne le sujet, l'article lié
// donne la matière, et le modèle écrit en coréen. C'est ce qui fait de ce slot
// « le cerveau » plutôt qu'une troisième dose d'actualité coréenne.
async function pickHackerNews(slot, used) {
  const ids = (await (await get('https://hacker-news.firebaseio.com/v0/topstories.json')).json()).slice(0, 40)
  const stories = []
  for (const id of ids) {
    try {
      const it = await (await get(`https://hacker-news.firebaseio.com/v0/item/${id}.json`)).json()
      // Pas de Show/Ask/offres d'emploi : il faut un article extérieur à lire.
      if (it?.url && it?.title && !/^(Show|Ask) HN/i.test(it.title) && !used.has(it.url)) {
        stories.push({ title: it.title, url: it.url })
      }
    } catch { /* histoire suivante */ }
    if (stories.length >= 30) break
  }
  if (!stories.length) return null

  for (const c of await chooseFrom(slot, stories)) {
    try {
      const paras = bodyFrom(await (await get(c.url)).text(), false)
      if (paras.join(' ').length >= 900) return { ...c, paras }
    } catch { /* paywall, JS, PDF… candidat suivant */ }
  }
  return null
}

// ── génération ───────────────────────────────────────────────────────────────

const FROM_ARTICLE = (slot, a) => `Tu réécris un article de presse coréen pour un lecteur étranger de niveau intermédiaire-avancé qui vit en Corée depuis huit ans et travaille dans la tech.

ARTICLE SOURCE
Titre : ${a.title}

${a.paras.join('\n\n').slice(0, 4500)}

CONSIGNES
- Réécris les faits de cet article en coréen, en **16 à 20 phrases**, chacune de 12 à 20 어절. C'est une contrainte ferme : la durée annoncée à l'utilisateur en dépend, et c'est ce contrat de durée qui le fait revenir. Si l'article source est long, choisis ce qui compte et laisse le reste.
- N'invente AUCUN fait. Tout ce que tu écris doit venir de l'article ci-dessus. Si un détail manque, ne le comble pas.
- Registre : ${slot.register}.
- Vocabulaire de niveau intermédiaire-avancé. Évite les termes rares et le jargon inutile.
- Le résultat doit sonner comme du coréen écrit par un Coréen. Pas de 번역투, pas de calque de structure anglaise.
- Phrases de longueur variée. Collocations naturelles.
- Réponds UNIQUEMENT avec le texte coréen. Pas de titre, pas de commentaire, pas de balisage.`

const FROM_SITUATION = (situation) => `Écris une courte scène en coréen pour un lecteur étranger de niveau intermédiaire-avancé qui vit à Séoul depuis huit ans.

SITUATION
${situation}

CONSIGNES
- **16 à 20 phrases**, chacune de 12 à 20 어절. Contrainte ferme.
- Registre parlé naturel, 해요체. C'est une situation de la vie quotidienne, pas un article.
- Le vocabulaire doit être celui qu'on emploie VRAIMENT dans cette situation à Séoul aujourd'hui — les mots qu'on lit sur les papiers, qu'on entend au guichet.
- Enseigne les collocations en les employant, pas en les expliquant.
- Ça doit être utile le soir même : des phrases réutilisables telles quelles.
- Écris un RÉCIT en prose, pas un script de dialogue. Les répliques sont intégrées dans les phrases (« … 라고 물어봤어요 »), jamais alignées une par ligne.
- N'invente pas de règles administratives ou de tarifs précis. Reste sur ce qui est vrai en général.
- Réponds UNIQUEMENT avec le texte coréen. Pas de titre, pas de commentaire.`

const TRIM = (ko) => `Réécris ce texte coréen en **exactement 16 à 18 phrases**, chacune de 12 à 20 어절.

${ko}

Garde les faits essentiels et abandonne franchement les détails secondaires — mieux vaut couvrir moins et rester lisible. Même registre, même ton. Ne conclus pas par un résumé.

Réponds UNIQUEMENT avec le texte coréen réécrit.`

const SPLIT = (ko) => `Voici un texte coréen. Découpe-le en phrases, traduis chaque phrase en anglais, et propose un titre en anglais pour l'ensemble.

TEXTE
${ko}

Réponds en JSON strict :
{"title":"An English title, 4 to 9 words, factual, no clickbait",
 "sentences":[{"ko":"la phrase coréenne exacte, inchangée","en":"its English translation"}]}

Règles :
- Reprends les phrases coréennes mot pour mot, sans les modifier ni les corriger.
- Une phrase par entrée. Ne fusionne pas, ne saute rien.
- Traduis en anglais naturel et fidèle. Si le coréen est maladroit, laisse-le voir.`

// ── voix ─────────────────────────────────────────────────────────────────────

const ssmlEscape = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')

/// Synthétise une phrase et rend, en plus du son, l'instant où commence chaque
/// 어절.
///
/// On insère un marqueur SSML muet devant chaque mot et on demande à l'API de
/// nous dire quand il est atteint. C'est ce qui permet de surligner le mot en
/// cours plutôt que la phrase entière — l'idée du parking §15 de la spec.
async function speak(text) {
  const words = text.trim().split(/\s+/)
  const ssml = '<speak>' +
    words.map((w, i) => `<mark name="w${i}"/>${ssmlEscape(w)}`).join(' ') +
    '</speak>'

  const r = await fetch(
    `https://texttospeech.googleapis.com/v1beta1/text:synthesize?key=${env.GOOGLE_TTS_API_KEY}`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        input: { ssml },
        voice: { languageCode: 'ko-KR', name: VOICE },
        audioConfig: { audioEncoding: 'MP3', speakingRate: 0.95 },
        enableTimePointing: ['SSML_MARK'],
      }),
    },
  )
  const j = await r.json()
  if (!r.ok || j.error) throw new Error(j.error?.message || `HTTP ${r.status}`)

  // Les repères reviennent dans l'ordre des marqueurs, mais on les réordonne
  // sur le nom : un décalage silencieux ferait dériver tout le surlignage.
  const marks = new Map((j.timepoints || []).map((t) => [t.markName, t.timeSeconds]))
  const starts = words.map((_, i) => marks.get(`w${i}`))
  const complete = starts.every((t) => typeof t === 'number')

  return {
    buf: Buffer.from(j.audioContent, 'base64'),
    // Incomplet : on ne publie pas de repères à moitié faux, l'app retombera
    // proprement sur le surlignage par phrase.
    words: complete ? words.map((w, i) => ({ w, t: Number(starts[i].toFixed(3)) })) : null,
  }
}

// ── un texte, de bout en bout ────────────────────────────────────────────────

async function buildText(slot, date, used, outDir) {
  let korean
  let source = null
  if (slot.situations) {
    // Pas de hasard non reproductible : la situation dérive de la date, donc
    // relancer la même journée redonne la même scène (idempotence, spec §9).
    const i = [...date].reduce((a, c) => a + c.charCodeAt(0), 0) % SITUATIONS.length
    log(`    situation : ${SITUATIONS[i].slice(0, 60)}…`)
    korean = await llm(FROM_SITUATION(SITUATIONS[i]))
  } else {
    const a = slot.hackerNews ? await pickHackerNews(slot, used) : await pickArticle(slot, used)
    if (!a) throw new Error('aucun sujet retenu')
    used.add(a.url)
    source = { title: a.title, url: a.url }
    log(`    source : ${a.title.slice(0, 58)}`)
    korean = await llm(FROM_ARTICLE(slot, a))
  }

  // Contrôle déterministe de la longueur, dans l'esprit de l'étape 5 : on ne
  // demande pas au modèle s'il a respecté la consigne, on compte. Le contrat de
  // durée annoncé sur la carte n'a de valeur que s'il est vrai.
  const count = (t) => t.trim().split(/\s+/).length
  const before = count(korean)
  // Un modèle ne resserre que d'environ 10 % par passage : une seule tentative
  // ne suffit jamais quand il a débordé de moitié. On boucle, et on abandonne
  // le slot plutôt que de publier un texte qui ment sur sa durée (spec §12).
  for (let i = 0; i < 3 && count(korean) > MAX_EOJEOL; i++) {
    korean = await llm(TRIM(korean))
  }
  if (count(korean) !== before) log(`    longueur : ${before} → ${count(korean)} 어절`)
  if (count(korean) > MAX_EOJEOL) {
    throw new Error(`trop long après resserrage (${count(korean)} 어절)`)
  }

  const split = await llm(SPLIT(korean), { json: true })
  const sentences = (split.sentences || []).filter((s) => s?.ko?.trim() && s?.en?.trim())
  // Trop peu : le texte est tronqué. Trop : le modèle a écrit un script de
  // dialogue au lieu d'un récit, et chaque réplique deviendrait une piste audio.
  if (sentences.length < 8 || sentences.length > 35) {
    throw new Error(`découpage aberrant (${sentences.length} phrases)`)
  }

  // Une piste par phrase : c'est ce qui rend le surlignage trivial côté app.
  const audioDir = join(outDir, 'audio')
  mkdirSync(audioDir, { recursive: true })
  let bytes = 0
  for (const [i, s] of sentences.entries()) {
    const file = `${date}-${slot.id}-${pad(i + 1)}.mp3`
    const { buf, words } = await speak(s.ko)
    writeFileSync(join(audioDir, file), buf)
    s.audio = `audio/${file}`
    if (words) s.words = words
    bytes += buf.length
  }

  // La durée annoncée vient du son réel, pas d'une estimation au nombre de mots.
  // Le débit est constant, donc les octets suffisent — et les repères SSML
  // servent de contre-mesure indépendante : s'ils divergent, c'est que le débit
  // a changé sous nos pieds, et la carte se mettrait à mentir en silence.
  const seconds = Math.round(bytes / (MP3_KBPS * 1000 / 8))
  const marked = sentences.reduce((a, s) => a + (s.words?.at(-1)?.t ?? 0) + 0.6, 0)
  if (marked > 0 && Math.abs(seconds - marked) / seconds > 0.25) {
    log(`    ⚠ durée douteuse : ${seconds}s par les octets, ${Math.round(marked)}s par les repères`)
  }
  return {
    slot: slot.id,
    universe: slot.universe,
    title: split.title || '(untitled)',
    minutes: Math.max(1, Math.round(seconds / 60)),
    seconds,
    source,
    sentences,
  }
}

// ── main ─────────────────────────────────────────────────────────────────────

const date = arg('date', new Date().toISOString().slice(0, 10))
const outDir = arg('out', join(ROOT, 'pipeline', 'out'))
const t0 = Date.now()

for (const k of ['OPENROUTER_API_KEY', 'GOOGLE_TTS_API_KEY']) {
  if (!env[k]) { console.error(`✕ ${k} manquante dans .env`); process.exit(1) }
}

log(`\nMolago — fabrication du ${date}\n`)
mkdirSync(outDir, { recursive: true })

const used = new Set()
const texts = []
for (const slot of SLOTS) {
  log(`  ▸ ${slot.universe}`)
  try {
    const t = await buildText(slot, date, used, outDir)
    texts.push(t)
    log(`    ✓ « ${t.title} » — ${t.sentences.length} phrases, ${t.minutes} min\n`)
  } catch (e) {
    // Un texte raté ne fait pas échouer la journée : on en publie deux.
    // « Deux bons textes valent mieux que trois dont un mauvais » (spec §12).
    log(`    ✕ ${e.message}\n`)
  }
}

if (!texts.length) { console.error('✕ aucun texte produit — rien n\'est publié.'); process.exit(1) }

// Écriture atomique : l'app ne peut jamais lire un fichier à moitié écrit.
const day = { date, generatedAt: new Date().toISOString(), model: MODEL, voice: VOICE, texts }
const final = join(outDir, `${date}.json`)
writeFileSync(`${final}.tmp`, JSON.stringify(day, null, 2))
renameSync(`${final}.tmp`, final)

log(`✓ ${texts.length}/${SLOTS.length} textes · ${((Date.now() - t0) / 1000).toFixed(0)} s`)
log(`  ${final}\n`)
