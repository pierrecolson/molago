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
//   · contrôle de niveau (Kiwi)  → il n'y a pas encore de profil de vocabulaire
//     à comparer, ni de liste de fréquence coréenne sous la main.
//   · quiz                        → M4, dernier jalon.

import { writeFileSync, mkdirSync, existsSync, readFileSync, renameSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { DOMAINS } from './domains.mjs'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')
const UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'

// Écrire du coréen qui sonne juste est la seule tâche qui justifie le modèle
// cher (decisions.md §32). Tout le reste est mécanique — donner la forme de
// dictionnaire de 파일로, lister les mots qui partagent 酒, nommer l'objet d'un
// texte — et se fait très bien à un cinquième du prix.
//
// Mesuré avant le partage : 0,28 $ par texte, dont 0,20 $ pour le glossaire et
// les familles seuls.
const WRITER = 'openai/gpt-5.1'                   // decisions.md §32
// Un modèle **sans raisonnement**, et c'est le point. Mesuré sur quatre mots :
// gpt-5-mini consomme 1 283 tokens de réflexion pour 500 caractères de réponse,
// ce qui vide le plafond avant d'écrire et rend des réponses vides ou tronquées.
// Celui-ci en consomme 161 pour le même travail, à un sixième du prix. Le
// glossaire et les familles n'ont rien à réfléchir : ils recopient et traduisent.
const CLERK = 'google/gemini-3.5-flash-lite'

// Ce que la nuit a coûté, en dollars. On mesure au lieu d'estimer : l'écart
// entre les deux a été d'un facteur vingt.
const spent = { writer: 0, clerk: 0 }
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

// L'API Thiings tourne sur la même machine : 9 000 icônes 3D, interrogeables en
// local. On ne présélectionne donc rien — l'icône d'un mot est résolue le jour
// où le mot apparaît, et copiée dans un dossier PARTAGÉ : le mot est global,
// son icône aussi (decisions.md §37). Résolue une fois, servie à tout le monde.
// Lu au moment de s'en servir, pas ici : `env` est construit plus bas, et une
// constante qui l'utilise trop tôt fait planter le module au chargement.
const thiingsURL = () => env.THIINGS_URL || 'http://host.docker.internal:3088'
const ICONS_OUT = '/icons-out'

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

async function llm(prompt, { json = false, model = WRITER, maxTokens = 8000 } = {}) {
  const r = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      authorization: `Bearer ${env.OPENROUTER_API_KEY}`,
      'content-type': 'application/json',
      'x-title': 'Molago pipeline',
    },
    body: JSON.stringify({
      model,
      messages: [{ role: 'user', content: prompt }],
      // Un plafond propre à chaque appel plutôt qu'un plafond unique très haut.
      // Il n'augmente pas la facture — on paie ce qui est produit — mais
      // OpenRouter réserve le crédit dessus, et un 32 000 partout empêchait de
      // lancer quoi que ce soit dès que le solde baissait.
      max_tokens: maxTokens,
      ...(json ? { response_format: { type: 'json_object' } } : {}),
    }),
  })
  const j = await r.json()
  if (!r.ok || j.error) throw new Error(j.error?.message || `HTTP ${r.status}`)
  if (typeof j.usage?.cost === 'number') {
    spent[model === WRITER ? 'writer' : 'clerk'] += j.usage.cost
  }
  let out = (j.choices?.[0]?.message?.content || '').trim()
  if (!out) throw new Error('réponse vide')
  if (json) {
    out = out.replace(/^```(?:json)?\s*|\s*```$/g, '')
    return JSON.parse(out.slice(out.indexOf('{'), out.lastIndexOf('}') + 1))
  }
  return out
}

/// Comme `llm`, mais retente une fois quand le JSON revient malformé.
///
/// Le modèle bon marché glisse parfois un guillemet typographique là où il
/// faudrait un guillemet droit — `"s": “미토스` — et tout l'appel est perdu.
/// C'est rare et sans motif, donc une seconde tentative suffit : elle coûte
/// deux centimes et évite de perdre le glossaire d'un texte entier.
async function llmJSON(prompt, options = {}) {
  try {
    return await llm(prompt, { ...options, json: true })
  } catch (e) {
    if (!(e instanceof SyntaxError)) throw e
    log(`    ↻ JSON malformé, seconde tentative`)
    return await llm(prompt, { ...options, json: true })
  }
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
  const pick = await llmJSON(CHOOSE(slot, shortlist), { model: CLERK, maxTokens: 1000 })
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

// L'étape 7 de la spec : rendre chaque mot tappable.
//
// Le glossaire se greffe sur le découpage en 어절 que les repères SSML ont déjà
// produit — une seule structure, deux usages. On demande le lemme parce que
// c'est lui qu'on cherche dans un dictionnaire : taper 관리비를 doit donner
// 관리비, pas la forme fléchie avec sa particule.
const GLOSS = (words) => `Voici les 어절 d'un texte coréen, numérotés. Pour chacun, donne sa forme de dictionnaire et son sens.

${words.map((w, i) => `${i}. ${w}`).join('\n')}

Réponds en JSON strict :
{"g":[{"i":0,"s":"le 어절 tel qu'il apparaît ci-dessus","l":"la forme de dictionnaire","p":"noun|verb|adjective|adverb|particle|number|name|other","e":"le sens en anglais, court"}]}

Règles :
- **Un objet par 어절, tous, dans l'ordre, sans en sauter.** Recopie \`s\` à l'identique : c'est ce qui permet de vérifier l'alignement.
- \`l\` est la forme qu'on chercherait dans un dictionnaire : 관리비를 → 관리비, 올랐어요 → 오르다, 갔습니다 → 가다.
- \`e\` est le sens de **\`l\`**, la forme de dictionnaire — jamais celui de la forme fléchie. 소주랑 donne \`l\`: 소주, \`e\`: "soju" et non "soju and" ; 파일들과 donne "file" et non "files and" ; 버튼이 donne "button" et non "button as subject". La particule ne fait pas partie du mot et n'a rien à faire dans sa traduction.
- Deux à cinq mots. Le sens qu'a ce mot **dans cette phrase** quand il en a plusieurs, mais le sens du mot, pas celui du groupe.
- Quand le 어절 est lui-même une particule ou un mot grammatical isolé, \`e\` explique alors sa fonction : 를 → "object marker".`

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

// ── icônes ───────────────────────────────────────────────────────────────────

// La question n'est pas « quelle icône ressemble à ce sens ? » mais
// « ce mot désigne-t-il un objet, et lequel ? ».
//
// L'ordre inverse a été essayé deux fois et échoue toujours de la même façon :
// on cherche l'icône à partir du sens anglais, puis on demande au modèle de
// valider. Il valide alors des homonymes — 목표 « objectif » devient un but de
// football, 플랫폼 « plateforme logicielle » un quai de gare, 권력 « pouvoir »
// une centrale nucléaire. Devant une liste de titres qui contiennent tous le
// bon mot anglais, le réflexe de refus s'éteint.
//
// En demandant d'abord **quel objet le mot désigne**, l'homonymie disparaît :
// un mot abstrait n'a pas d'objet, le modèle le dit, et rien n'est cherché.
const OBJECTS = (lemmas) => `Voici des noms coréens avec leur sens. Pour chacun, dis s'il désigne un **objet physique qu'on pourrait poser sur une table ou photographier**.

${lemmas.map((l, i) => `${i}. ${l.lemma} — ${l.meaning}`).join('\n')}

Si oui, nomme cet objet en un ou deux mots anglais, comme on l'étiquetterait dans une bibliothèque d'icônes 3D d'objets du quotidien.

Réponds « non » pour tout le reste, et le reste est la majorité :
- les idées, relations, quantités, processus, qualités (objectif, pouvoir, échelle, exécution, ambiance)
- les termes techniques abstraits (plateforme, type, ligne de traitement, version)
- les actions, les états, les périodes
- les institutions et les concepts juridiques ou administratifs

Ne te laisse jamais guider par le mot anglais du sens : « platform » la plateforme logicielle n'est pas un quai, « goal » l'objectif n'est pas un but de football, « scale » l'échelle n'est pas une balance. Si l'objet ne se photographie pas, la réponse est non.

Réponds en JSON : {"o":[{"i":<numéro>,"n":"the object in one or two words"}]}
N'inclus que les mots qui désignent vraiment un objet.`

/// Résout les icônes des noms d'un texte et les dépose dans le dossier partagé.
///
/// Deux temps : le modèle nomme l'objet quand il y en a un, puis on vérifie que
/// la bibliothèque a une icône **portant exactement ce nom**. La chaîne de
/// caractères ne fait plus que confirmer, elle ne propose plus rien.
async function attachIcons(sentences) {
  if (!env.THIINGS_API_KEY) return 0

  const wanted = new Map()
  for (const s of sentences) {
    for (const w of s.words ?? []) {
      if (w.pos === 'noun' && w.en && w.lemma && !wanted.has(w.lemma)) wanted.set(w.lemma, w.en)
    }
  }
  if (!wanted.size) return 0

  let objects = []
  try {
    const rows = [...wanted].map(([lemma, meaning]) => ({ lemma, meaning }))
    const out = await llmJSON(OBJECTS(rows), { model: CLERK, maxTokens: 3000 })
    objects = (out.o || [])
      .filter((x) => rows[x.i] && typeof x.n === 'string' && x.n.trim())
      .map((x) => ({ lemma: rows[x.i].lemma, name: x.n.trim().toLowerCase() }))
  } catch {
    return 0
  }
  if (!objects.length) return 0

  const found = []
  for (let i = 0; i < objects.length; i += 8) {
    const batch = await Promise.all(objects.slice(i, i + 8).map(async (o) => {
      try {
        const r = await fetch(`${thiingsURL()}/icons?search=${encodeURIComponent(o.name)}&limit=20`, {
          headers: { authorization: `Bearer ${env.THIINGS_API_KEY}` },
          signal: AbortSignal.timeout(8000),
        })
        if (!r.ok) return null
        const body = await r.json()
        const items = Array.isArray(body) ? body : (body.icons || body.data || [])
        // Titre identique, rien d'autre. « receipt » doit trouver « Receipt »,
        // pas « Receipt Printer » et surtout pas « Shoebill ».
        const exact = items.find((x) => String(x.title || '').toLowerCase() === o.name)
        return exact ? { lemma: o.lemma, slug: exact.slug } : null
      } catch { return null }
    }))
    found.push(...batch.filter(Boolean))
  }

  for (const c of found) {
    const dest = join(ICONS_OUT, `${c.slug}.png`)
    if (!existsSync(dest)) {
      try {
        const img = await fetch(`${thiingsURL()}/icons/${c.slug}/image?size=256`, {
          headers: { authorization: `Bearer ${env.THIINGS_API_KEY}` },
          signal: AbortSignal.timeout(15000),
        })
        if (img.ok) writeFileSync(dest, Buffer.from(await img.arrayBuffer()))
        else continue
      } catch { continue }
    }
    for (const s of sentences) {
      for (const w of s.words ?? []) if (w.lemma === c.lemma) w.icon = c.slug
    }
  }
  log(`    icônes    : ${found.length} posées · ${objects.length} objets nommés sur ${wanted.size} noms`)
  return found.length
}

/// L'icône qui représente le texte entier, pour sa carte dans la Library.
///
/// Le caractère chinois qui l'occupait était décoratif : l'univers est déjà dit
/// par la couleur de la carte et par son étiquette. Une image du sujet, elle,
/// apprend quelque chose avant même d'avoir lu le titre.
const COVER = (title, first) => `Voici un article. Nomme **l'objet unique** qui le représenterait le mieux sur une vignette.

Titre : ${title}
Début : ${first}

Un ou deux mots anglais, comme on l'étiquetterait dans une bibliothèque d'icônes 3D d'objets du quotidien. Un procès → "gavel". Un dîner d'entreprise → "restaurant". Un compilateur → "code".

Choisis quelque chose de **concret et photographiable**. Pas de concept, pas de symbole abstrait.

Réponds en JSON : {"n":"the object"}`

async function attachCover(text, sentences) {
  if (!env.THIINGS_API_KEY) return
  try {
    const { n } = await llmJSON(
      COVER(text.title, sentences.slice(0, 2).map((s) => s.en).join(' ')),
      { model: CLERK, maxTokens: 300 },
    )
    const name = String(n || '').trim().toLowerCase()
    if (name.length < 3) return

    const r = await fetch(`${thiingsURL()}/icons?search=${encodeURIComponent(name)}&limit=20`, {
      headers: { authorization: `Bearer ${env.THIINGS_API_KEY}` },
      signal: AbortSignal.timeout(8000),
    })
    if (!r.ok) return
    const body = await r.json()
    const items = Array.isArray(body) ? body : (body.icons || body.data || [])
    // Titre exact, ou titre dont le nom est un **mot entier**. La simple
    // sous-chaîne ne suffit pas : elle a donné « Grillz » — des bijoux
    // dentaires — pour un dîner au barbecue, parce que « grillz » contient
    // « grill ». À défaut, la carte garde son hanja, ce qui n'est pas grave.
    const words = (t) => String(t || '').toLowerCase().split(/[^a-z0-9]+/).filter(Boolean)
    const hit = items.find((i) => String(i.title || '').toLowerCase() === name)
      ?? items.filter((i) => name.split(' ').every((n) => words(i.title).includes(n)))
        .sort((a, b) => String(a.title).length - String(b.title).length)[0]
    if (!hit) return

    const dest = join(ICONS_OUT, `${hit.slug}.png`)
    if (!existsSync(dest)) {
      const img = await fetch(`${thiingsURL()}/icons/${hit.slug}/image?size=256`, {
        headers: { authorization: `Bearer ${env.THIINGS_API_KEY}` },
        signal: AbortSignal.timeout(15000),
      })
      if (!img.ok) return
      writeFileSync(dest, Buffer.from(await img.arrayBuffer()))
    }
    text.icon = hit.slug
    log(`    vignette  : ${hit.title}`)
  } catch { /* la carte gardera son hanja */ }
}

// ── domaines ─────────────────────────────────────────────────────────────────

// Les 의존명사 et autres mots-outils : ils ont la forme d'un nom mais ne
// désignent rien. 것 « chose, fait » recevait un cerveau parce qu'il avait été
// rangé dans « pensée » — ce n'est pas faux, c'est vide de sens.
//
// C'est le seul cas où la tuile typographique vaut mieux qu'une image : elle
// dit « ce mot ne montre rien », ce qui est l'information juste. Une liste fixe
// plutôt qu'une consigne au modèle, parce qu'elle est courte, connue, et qu'un
// filtre déterministe ne se trompe jamais deux fois de la même façon.
const EMPTY_WORDS = new Set([
  '것', '거', '수', '데', '바', '줄', '리', '터', '나름', '따름', '뿐', '채', '만큼',
  '대로', '등', '및', '점', '중', '내', '간', '측', '쪽', '편', '경우', '자', '분',
  '개', '명', '번', '차', '째', '여', '무렵', '즈음', '통', '탓', '덕분', '때문',
])

const CLASSIFY = (rows) => `Classe chaque mot coréen dans **un seul** domaine parmi cette liste.

DOMAINES
${DOMAINS.map((d, i) => `${i}. ${d.id} — ${d.label}`).join('\n')}

MOTS
${rows.map((r, i) => `${i}. ${r.lemma} — ${r.meaning}`).join('\n')}

Choisis le domaine dont le mot **parle**, même quand il est abstrait : 분위기 « ambiance » va dans emotion, 확인 « vérification » dans rules, 규모 « échelle » dans quantity, 퇴근하다 « quitter le travail » dans work.

Chaque mot doit recevoir un domaine — **sauf** ceux qui n'ont pas de sens propre : les mots grammaticaux, les noms dépendants, les unités de comptage, les mots qui ne servent qu'à construire la phrase. Pour ceux-là, ne renvoie rien du tout : une image leur prêterait un sens qu'ils n'ont pas.

En cas d'hésitation entre deux domaines, prends le plus concret des deux.

Réponds en JSON : {"c":[{"i":<numéro du mot>,"d":<numéro du domaine>}]}`

/// Range chaque mot dans un domaine, et lui donne l'icône du domaine à défaut
/// d'en avoir une propre.
///
/// Un mot concret garde la sienne : 소주 montre une bouteille, pas l'icône
/// générique « boissons ». Le domaine ne sert qu'à ce qui n'a pas d'objet — et
/// c'est la majorité du vocabulaire d'un texte d'actualité ou de technique.
async function attachDomains(sentences) {
  const wanted = new Map()
  for (const s of sentences) {
    for (const w of s.words ?? []) {
      if (!w.en || !w.lemma || EMPTY_WORDS.has(w.lemma)) continue
      if (!wanted.has(w.lemma)) wanted.set(w.lemma, w.en)
    }
  }
  if (!wanted.size) return 0

  const rows = [...wanted].map(([lemma, meaning]) => ({ lemma, meaning }))
  let byLemma = new Map()
  try {
    const out = await llmJSON(CLASSIFY(rows), { model: CLERK, maxTokens: 16000 })
    for (const c of out.c || []) {
      const row = rows[c.i]
      const domain = DOMAINS[c.d]
      if (row && domain) byLemma.set(row.lemma, domain)
    }
  } catch (e) {
    log(`    ⚠ domaines indisponibles (${e.message.slice(0, 40)})`)
    return 0
  }

  let placed = 0
  for (const s of sentences) {
    for (const w of s.words ?? []) {
      const d = byLemma.get(w.lemma)
      if (!d) continue
      // Le domaine sert aussi à la recherche du carnet : taper « housing »
      // doit retrouver tous les mots du logement (spec §5.5).
      w.domain = d.id
      if (!w.icon) { w.icon = d.icon; placed++ }
    }
  }
  log(`    domaines  : ${byLemma.size}/${rows.length} classés · ${placed} icônes de domaine`)
  return placed
}

// ── famille de racine ────────────────────────────────────────────────────────

const ROOTS = (lemmas) => `Voici des mots coréens. Pour ceux qui sont **sino-coréens**, donne leurs hanja et la famille de mots qui partage la même racine.

${lemmas.map((l, i) => `${i}. ${l}`).join('\n')}

**Règle impérative** : le regroupement se fait sur le **caractère chinois réel**, jamais sur la syllabe hangul. 사회 et 사장 partagent une syllabe et rien d'autre — les regrouper produirait des familles absurdes.

Réponds en JSON :
{"r":[{"i":0,"h":"管理費","m":"le sens de la racine partagée, en anglais, 2 à 5 mots","f":[{"k":"관리하다","h":"管理","e":"to manage, look after"}]}]}

- N'inclus **que** les mots réellement sino-coréens. Un mot d'origine coréenne pure ou un emprunt à l'anglais n'a pas de hanja : saute-le.
- \`f\` : trois à cinq mots courants de la même famille, le mot lui-même exclu.
- Le lecteur ne lit pas le chinois : ce qui compte est le **sens partagé**, le caractère reste discret.`

/// L'étage 3 du panneau de mot : découvrir que 관리자 et 관리하다, employés tous
/// les jours, sont le même bloc que le mot sur lequel on séchait. C'est là que
/// le rangement mental se fait (spec §5.3).
async function attachRoots(sentences) {
  // Seulement les noms, et pas plus de quarante. On produisait cent cinquante
  // familles par nuit pour que l'utilisateur en voie cinq — celles des mots
  // qu'il garde. Les verbes sino-coréens sont presque tous des noms + 하다,
  // donc la famille du nom les couvre déjà.
  const lemmas = [...new Set(
    sentences.flatMap((s) => s.words ?? [])
      .filter((w) => w.pos === 'noun' && w.lemma && w.lemma.length >= 2)
      .map((w) => w.lemma),
  )].slice(0, 40)
  if (!lemmas.length) return 0

  let found = 0
  try {
    const out = await llmJSON(ROOTS(lemmas), { model: CLERK, maxTokens: 12000 })
    const byLemma = new Map()
    for (const r of out.r || []) {
      const lemma = lemmas[r.i]
      if (!lemma || typeof r.h !== 'string' || !Array.isArray(r.f)) continue
      // On vérifie la forme de chaque entrée au lieu de la supposer : une seule
      // famille rendue en tableau plutôt qu'en objet a suffi à rendre toute une
      // journée indécodable côté app. Ce qui sort d'un modèle se contrôle.
      const family = r.f.filter((x) =>
        x && typeof x === 'object' && !Array.isArray(x)
        && typeof x.k === 'string' && x.k.trim()
        && typeof x.e === 'string' && x.e.trim(),
      ).map((x) => ({ k: x.k.trim(), h: typeof x.h === 'string' ? x.h : undefined, e: x.e.trim() }))
      if (family.length) {
        byLemma.set(lemma, { hanja: r.h, rootMeaning: typeof r.m === 'string' ? r.m : '', family: family.slice(0, 5) })
      }
    }
    for (const s of sentences) {
      for (const w of s.words ?? []) {
        const r = byLemma.get(w.lemma)
        if (r) { w.hanja = r.hanja; w.root = r.rootMeaning; w.family = r.family; found++ }
      }
    }
    log(`    racines   : ${byLemma.size} mots sino-coréens sur ${lemmas.length}`)
  } catch (e) {
    log(`    ⚠ racines indisponibles (${e.message.slice(0, 40)})`)
  }
  return found
}

// ── un texte, de bout en bout ─// ── un texte, de bout en bout ────────────────────────────────────────────────

async function buildText(slot, date, used, outDir) {
  let korean
  let situation = null
  let source = null
  // L'article complet est gardé sous la main : le repli en cas de resserrage
  // impossible réécrit depuis la source, et il lui faut le texte, pas
  // seulement le titre et l'adresse.
  let article = null
  if (slot.situations) {
    // Pas de hasard non reproductible : la situation dérive de la date, donc
    // relancer la même journée redonne la même scène (idempotence, spec §9).
    const i = [...date].reduce((a, c) => a + c.charCodeAt(0), 0) % SITUATIONS.length
    situation = SITUATIONS[i]
    log(`    situation : ${situation.slice(0, 60)}…`)
    korean = await llm(FROM_SITUATION(situation))
  } else {
    const a = slot.hackerNews ? await pickHackerNews(slot, used) : await pickArticle(slot, used)
    if (!a) throw new Error('aucun sujet retenu')
    used.add(a.url)
    article = a
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
  for (let i = 0; i < 2 && count(korean) > MAX_EOJEOL; i++) {
    korean = await llm(TRIM(korean))
  }
  // Le resserrage échoue parfois complètement — mesuré : 406 → 409 어절. Plutôt
  // que de perdre un univers entier de la journée, on réécrit depuis la source
  // avec une consigne plus serrée. Un créneau vide se voit ; un texte un peu
  // plus court, non.
  // Le resserrage échoue parfois complètement — mesuré : 406 → 409 어절. On
  // réécrit alors depuis la source plutôt que d'abandonner l'univers. Le
  // créneau « vie quotidienne » n'a pas d'article : c'est sa situation qu'on
  // réécrit, sinon il tombait à chaque fois qu'un texte débordait.
  if (count(korean) > MAX_EOJEOL) {
    log(`    resserrage sans effet (${count(korean)} 어절) — réécriture depuis la source`)
    const tighter = (p) => p
      .replace('en **16 à 20 phrases**', 'en **13 à 15 phrases**')
      .replace('**16 à 20 phrases**', '**13 à 15 phrases**')
    korean = article
      ? await llm(tighter(FROM_ARTICLE(slot, article)))
      : await llm(tighter(FROM_SITUATION(situation)))
  }
  if (count(korean) !== before) log(`    longueur : ${before} → ${count(korean)} 어절`)
  if (count(korean) > MAX_EOJEOL) {
    throw new Error(`trop long après resserrage (${count(korean)} 어절)`)
  }

  const split = await llmJSON(SPLIT(korean), { model: CLERK, maxTokens: 12000 })
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

  // Le glossaire : un appel pour tout le texte, aligné sur le découpage en
  // 어절 déjà fait pour les repères. Un mot sans glose reste lisible, il n'est
  // simplement pas tappable — mieux que de publier une traduction fausse.
  const allWords = sentences.flatMap((s) => (s.words ?? []).map((w) => w.w))
  if (allWords.length) {
    try {
      const g = await llmJSON(GLOSS(allWords), { model: CLERK, maxTokens: 24000 })
      const byIndex = new Map((g.g || []).map((x) => [x.i, x]))
      let matched = 0, cursor = 0
      for (const sentence of sentences) {
        for (const word of sentence.words ?? []) {
          const entry = byIndex.get(cursor)
          // On ne fait confiance qu'aux entrées dont la forme correspond :
          // un glossaire décalé d'un cran donnerait à chaque mot le sens du
          // voisin, et l'utilisateur apprendrait faux sans jamais s'en douter.
          if (entry && entry.s === word.w) {
            word.lemma = entry.l
            word.pos = entry.p
            word.en = entry.e
            matched++
          }
          cursor++
        }
      }
      log(`    glossaire : ${matched}/${allWords.length} mots`)
      try {
        await attachIcons(sentences)
      } catch (e) {
        log(`    ⚠ icônes indisponibles (${e.message.slice(0, 40)})`)
      }
      await attachRoots(sentences)
      await attachDomains(sentences)
    } catch (e) {
      log(`    ⚠ glossaire indisponible (${e.message.slice(0, 40)}) — les mots ne seront pas tappables`)
    }
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
  const text = {
    slot: slot.id,
    universe: slot.universe,
    title: split.title || '(untitled)',
    minutes: Math.max(1, Math.round(seconds / 60)),
    seconds,
    source,
    sentences,
  }
  await attachCover(text, sentences)
  return text
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
const day = { date, generatedAt: new Date().toISOString(), model: WRITER, voice: VOICE, texts }
const final = join(outDir, `${date}.json`)
writeFileSync(`${final}.tmp`, JSON.stringify(day, null, 2))
renameSync(`${final}.tmp`, final)

const total = spent.writer + spent.clerk
log(`✓ ${texts.length}/${SLOTS.length} textes · ${((Date.now() - t0) / 1000).toFixed(0)} s`)
log(`  coût : ${total.toFixed(3)} $ (écriture ${spent.writer.toFixed(3)} · reste ${spent.clerk.toFixed(3)}) → ${(total * 30).toFixed(2)} $/mois`)
log(`  ${final}\n`)
