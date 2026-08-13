#!/usr/bin/env node
// La première vraie API de Molago — deux routes, et c'est tout.
//
// Jusqu'ici le serveur ne faisait que servir des fichiers fabriqués la nuit.
// La capture change ça : la spec §5.7 veut qu'un mot photographié montre son
// sens **immédiatement** — « on capture souvent parce qu'on a besoin de
// comprendre maintenant, devant sa facture ». Il faut donc quelqu'un à qui
// demander.
//
//   POST /u/:id/gloss     { text }   → les mots du texte, avec leur sens
//   POST /u/:id/captures  { words }  → ce qui est gardé, pour la nuit suivante
//   POST /u/:id/document  { lines }  → un document photographié, rendu lisible
//
// Pas de framework : `node:http` suffit pour deux routes, et une dépendance de
// moins est une dépendance de moins à tenir à jour sur un VPS.
//
// L'identité est le chemin `/u/:id`, exactement comme pour les fichiers. Le
// jour où Google OAuth arrivera, seule la façon de prouver qu'on est cet
// utilisateur changera — pas les routes, pas l'app.

import { createServer } from 'node:http'
import { readFileSync, writeFileSync, existsSync, mkdirSync, renameSync } from 'node:fs'
import { join } from 'node:path'

const PORT = Number(process.env.PORT || 8080)
const DATA = process.env.DATA_DIR || '/data'
const CLERK = 'google/gemini-3.5-flash-lite'
// Remettre en ordre un document photographié n'est pas mécanique : l'OCR rend
// des lignes dans le désordre visuel, coupées par les colonnes et les encadrés,
// et il faut décider ce qui est un titre, ce qui est une phrase, ce qui est du
// bruit d'en-tête. Le modèle bon marché rend là une bouillie plausible. C'est
// aussi ce qui justifie l'attente qu'on a acceptée : mieux vaut trente secondes
// et un texte juste que deux secondes et un texte faux.
const WRITER = 'openai/gpt-5.1'
const USER = process.env.MOLAGO_USER_ID || process.env.MOLAGO_SECRET_PATH || ''

// ── le glossaire d'un texte capturé ──────────────────────────────────────────

// Les mots arrivent numérotés parce que l'app sait **où** chacun se trouve dans
// l'image : elle en a la boîte, donnée par l'OCR. Répondre par index garde
// l'alignement entre le sens et le rectangle à surligner — un appariement par
// forme se casserait dès qu'un mot apparaît deux fois.
const GLOSS = (tokens) => `Voici les mots d'un texte coréen photographié — une facture, un panneau, un menu, un message —, numérotés dans l'ordre où ils apparaissent.

${tokens.map((t, i) => `${i}. ${t}`).join('\n')}

Retiens **ceux qui valent la peine d'être appris** par un étranger installé à Séoul depuis huit ans : les noms, verbes et adjectifs porteurs de sens. Laisse de côté les particules seules, les nombres, les nombres avec unité, la ponctuation, les noms propres évidents, et les mots trop élémentaires.

Réponds en JSON strict :
{"w":[{"i":<numéro>,"l":"la forme de dictionnaire","p":"noun|verb|adjective|adverb|other","e":"le sens en anglais, 2 à 5 mots"}]}

Règles :
- \`e\` est le sens de \`l\`, jamais celui de la forme fléchie : 관리비를 donne \`l\`: 관리비 et \`e\`: "maintenance fee".
- L'OCR se trompe. Si un mot est manifestement mal reconnu et ne veut rien dire, saute-le plutôt que d'inventer.
- Au plus 30 mots, et seulement ceux qui apprennent vraiment quelque chose.`

const DOCUMENT = (lines) => `Voici les lignes d'un document coréen photographié — une affiche, une facture, un panneau, un avis de copropriété. Elles arrivent dans l'ordre où la reconnaissance de texte les a vues, ce qui n'est pas toujours l'ordre de lecture : les colonnes, les encadrés et les tableaux la désorientent.

${lines.map((l, i) => `${i}. ${l}`).join('\n')}

Rends ce document lisible comme un article.

- Remets les phrases dans l'ordre où un humain les lirait.
- Recolle ce qu'un retour à la ligne a coupé au milieu d'une phrase.
- Jette les numéros de référence, les tampons, les numéros de téléphone isolés, les mentions légales — ce qui ne se lit pas à voix haute.
- Garde les chiffres, les dates et les montants : c'est souvent l'information qu'on est venu chercher.
- Ne réécris pas le coréen. C'est un document réel, pas un exercice : on le lit tel qu'il est écrit.
- La traduction anglaise est **naturelle**, pas littérale : ce que dirait un anglophone qui explique le document à quelqu'un.

Réponds en JSON :
{"t":"un titre court en anglais, ce que le document est","s":[{"ko":"une phrase coréenne","en":"sa traduction anglaise"}]}`

async function llm(prompt, model = CLERK) {
  const r = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      authorization: `Bearer ${process.env.OPENROUTER_API_KEY}`,
      'content-type': 'application/json',
      'x-title': 'Molago capture',
    },
    body: JSON.stringify({
      model,
      messages: [{ role: 'user', content: prompt }],
      max_tokens: 4000,
      response_format: { type: 'json_object' },
    }),
  })
  const j = await r.json()
  if (!r.ok || j.error) throw new Error(j.error?.message || `HTTP ${r.status}`)
  const out = (j.choices?.[0]?.message?.content || '').trim().replace(/^```(?:json)?\s*|\s*```$/g, '')
  return firstJSON(out)
}

/// La première valeur JSON équilibrée de la réponse, et rien d'autre.
///
/// Même garde-fou que dans la fabrique : le modèle ajoute parfois quelque
/// chose après son JSON, ou répond par un tableau nu là où on demandait un
/// objet — et tout l'appel se perdait dans un `SyntaxError`.
function firstJSON(s) {
  const io = s.indexOf('{'), ia = s.indexOf('[')
  const start = io < 0 ? ia : ia < 0 ? io : Math.min(io, ia)
  if (start < 0) throw new SyntaxError('pas de JSON dans la réponse')
  let depth = 0, inString = false, escaped = false
  for (let i = start; i < s.length; i++) {
    const c = s[i]
    if (escaped) { escaped = false; continue }
    if (c === '\\') { escaped = inString; continue }
    if (c === '"') { inString = !inString; continue }
    if (inString) continue
    if (c === '{' || c === '[') depth++
    else if ((c === '}' || c === ']') && --depth === 0) return JSON.parse(s.slice(start, i + 1))
  }
  return JSON.parse(s.slice(start))
}

// ── plomberie ────────────────────────────────────────────────────────────────

const json = (res, code, body) => {
  const s = JSON.stringify(body)
  res.writeHead(code, { 'content-type': 'application/json; charset=utf-8', 'content-length': Buffer.byteLength(s) })
  res.end(s)
}

async function readBody(req, limit = 200_000) {
  let size = 0
  const chunks = []
  for await (const chunk of req) {
    size += chunk.length
    // Une photo de facture donne quelques milliers de caractères. Au-delà, ce
    // n'est pas une capture, et on ne le met pas en mémoire pour le découvrir.
    if (size > limit) throw new Error('trop volumineux')
    chunks.push(chunk)
  }
  return JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}')
}

/// Les mots qui valent d'être appris parmi `tokens`, avec leur sens.
///
/// Servait déjà la route `gloss` ; la route `document` s'en sert aussi pour
/// que l'article publié ait des mots tappables, comme les textes du matin.
async function glossTokens(tokens) {
  const out = await llm(GLOSS(tokens))
  // `{"w": [...]}` demandé, mais le modèle rend parfois le tableau nu.
  return (Array.isArray(out) ? out : out.w || [])
    .filter((w) => w && Number.isInteger(w.i) && tokens[w.i]
      && typeof w.l === 'string' && w.l.trim()
      && typeof w.e === 'string' && w.e.trim())
    .slice(0, 30)
    .map((w) => ({
      index: w.i,
      surface: tokens[w.i],
      lemma: w.l.trim(),
      pos: typeof w.p === 'string' ? w.p : 'other',
      en: w.e.trim(),
    }))
}

const capturesFile = (user) => join(DATA, 'u', user, 'captures.json')
const dayFile = (user, date) => join(DATA, 'u', user, `${date}.json`)
// Le fuseau du lecteur, comme la fabrique : le serveur tourne en UTC, et à
// 6 h du matin à Séoul c'est déjà le lendemain là-bas mais pas ici.
const READER_TZ = process.env.MOLAGO_TZ || 'Asia/Seoul'

const readDay = (user, date) => {
  try { return JSON.parse(readFileSync(dayFile(user, date), 'utf8')) } catch { return null }
}
/// Écriture atomique : l'app peut lire la journée à l'instant où on la complète,
/// et une journée à moitié écrite ne se décode pas — l'écran afficherait alors
/// « rien ce matin » alors que tout est là.
const writeDay = (user, day) => {
  mkdirSync(join(DATA, 'u', user), { recursive: true })
  const file = dayFile(user, day.date)
  writeFileSync(`${file}.tmp`, JSON.stringify(day))
  renameSync(`${file}.tmp`, file)
}

// ── routes ───────────────────────────────────────────────────────────────────

createServer(async (req, res) => {
  try {
    const url = new URL(req.url, 'http://localhost')
    const m = url.pathname.match(/^\/u\/([A-Za-z0-9_-]{8,64})\/(gloss|captures|document)$/)

    if (url.pathname === '/health') return json(res, 200, { ok: true })
    if (!m) return json(res, 404, { error: 'not found' })
    // L'identifiant tient lieu d'authentification tant qu'il n'y a qu'un
    // utilisateur. On le compare quand même, plutôt que d'accepter n'importe
    // quel chemin bien formé.
    if (USER && m[1] !== USER) return json(res, 404, { error: 'not found' })
    if (req.method !== 'POST') return json(res, 405, { error: 'method not allowed' })

    const [, user, route] = m
    const body = await readBody(req)

    if (route === 'gloss') {
      // L'app envoie les mots que l'OCR a vus, dans l'ordre. Elle accepte aussi
      // un texte brut, pour rester utilisable depuis une ligne de commande.
      const tokens = Array.isArray(body.tokens)
        ? body.tokens.map((t) => String(t).trim()).filter(Boolean).slice(0, 400)
        : String(body.text || '').split(/\s+/).filter(Boolean).slice(0, 400)
      if (tokens.length < 1) return json(res, 400, { error: 'no text' })

      return json(res, 200, { words: await glossTokens(tokens) })
    }

    if (route === 'document') {
      const lines = (Array.isArray(body.lines) ? body.lines : [])
        .map((l) => String(l).trim()).filter(Boolean).slice(0, 300)
      if (lines.length < 1) return json(res, 400, { error: 'no text' })

      const out = await llm(DOCUMENT(lines), WRITER)
      const sentences = (Array.isArray(out) ? out : out.s || [])
        .filter((x) => x && typeof x.ko === 'string' && x.ko.trim()
          && typeof x.en === 'string' && x.en.trim())
        .map((x) => ({ ko: x.ko.trim(), en: x.en.trim() }))
      if (!sentences.length) return json(res, 502, { error: 'unreadable' })

      // Les mots tappables, comme dans les textes du matin : le même découpage
      // en 어절, le même glossaire sélectif que la route `gloss`. Un glossaire
      // qui échoue ne retient pas l'article — il est simplement moins tappable.
      const tokens = sentences.flatMap((s) => s.ko.split(/\s+/))
      let byIndex = new Map()
      try {
        byIndex = new Map((await glossTokens(tokens)).map((w) => [w.index, w]))
      } catch { /* un article sans glossaire vaut mieux que pas d'article */ }

      // La journée du lecteur, pas celle du serveur : c'est la même règle que
      // pour la fabrique nocturne, et pour la même raison — l'app range sa
      // capture dans le jour qu'affiche son téléphone.
      const date = new Date().toLocaleDateString('en-CA', { timeZone: READER_TZ })
      const day = readDay(user, date) || { date, texts: [] }

      // Un identifiant par capture : on en photographie plusieurs par jour, et
      // le slot seul ne suffirait pas à les distinguer.
      const slot = `capture-${Date.now().toString(36)}`
      let cursor = 0
      const text = {
        slot,
        universe: 'Capture',
        title: String(out.t || 'Captured document').trim().slice(0, 90),
        // Le débit de lecture mesuré sur les textes du matin, appliqué au
        // nombre de 어절 : la carte annonce la même durée que les autres, et
        // pour la même raison.
        minutes: Math.max(1, Math.round(sentences.reduce((n, s) => n + s.ko.split(/\s+/).length, 0) / 95)),
        icon: null,
        // Pas de voix pour une capture : on la lit devant son document, pas
        // dans le métro. Le nom de piste reste — il sert d'identifiant de
        // phrase et porte la date — mais aucun fichier n'existe derrière.
        sentences: sentences.map((s, i) => ({
          ...s,
          audio: `${date}-${slot}-${String(i + 1).padStart(2, '0')}.mp3`,
          words: s.ko.split(/\s+/).map((w) => {
            const g = byIndex.get(cursor++)
            return g ? { w, lemma: g.lemma, pos: g.pos, en: g.en } : { w }
          }),
        })),
      }

      day.texts = [...day.texts.filter((t) => t.slot !== slot), text]
      writeDay(user, day)
      return json(res, 200, { date, slot, title: text.title, sentences: sentences.length })
    }

    // Ce que l'utilisateur a gardé. La fabrique de la nuit suivante s'en sert
    // pour le troisième texte : un mot attrapé sur une facture mardi devient le
    // sujet de mercredi (spec §8.2). C'est la boucle qui distingue Molago d'un
    // simple lecteur.
    const incoming = Array.isArray(body.words) ? body.words : []
    mkdirSync(join(DATA, 'u', user), { recursive: true })
    const file = capturesFile(user)
    const existing = existsSync(file) ? JSON.parse(readFileSync(file, 'utf8')) : []
    const seen = new Set(existing.map((c) => c.lemma))
    const added = incoming
      .filter((c) => c && typeof c.lemma === 'string' && c.lemma.trim() && !seen.has(c.lemma))
      .map((c) => ({
        lemma: String(c.lemma).trim(),
        en: String(c.en || '').trim(),
        context: String(c.context || '').trim().slice(0, 300),
        at: new Date().toISOString(),
        used: false,
      }))
    if (added.length) {
      writeFileSync(`${file}.tmp`, JSON.stringify([...existing, ...added], null, 2))
      // Écriture atomique : la fabrique peut lire ce fichier au même moment.
      writeFileSync(file, JSON.stringify([...existing, ...added], null, 2))
    }
    return json(res, 200, { added: added.length, total: existing.length + added.length })
  } catch (e) {
    return json(res, 500, { error: String(e.message || e).slice(0, 200) })
  }
}).listen(PORT, () => console.log(`molago api sur :${PORT}`))
