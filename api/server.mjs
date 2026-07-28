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
//
// Pas de framework : `node:http` suffit pour deux routes, et une dépendance de
// moins est une dépendance de moins à tenir à jour sur un VPS.
//
// L'identité est le chemin `/u/:id`, exactement comme pour les fichiers. Le
// jour où Google OAuth arrivera, seule la façon de prouver qu'on est cet
// utilisateur changera — pas les routes, pas l'app.

import { createServer } from 'node:http'
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs'
import { join } from 'node:path'

const PORT = Number(process.env.PORT || 8080)
const DATA = process.env.DATA_DIR || '/data'
const CLERK = 'google/gemini-3.5-flash-lite'
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

async function llm(prompt) {
  const r = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      authorization: `Bearer ${process.env.OPENROUTER_API_KEY}`,
      'content-type': 'application/json',
      'x-title': 'Molago capture',
    },
    body: JSON.stringify({
      model: CLERK,
      messages: [{ role: 'user', content: prompt }],
      max_tokens: 4000,
      response_format: { type: 'json_object' },
    }),
  })
  const j = await r.json()
  if (!r.ok || j.error) throw new Error(j.error?.message || `HTTP ${r.status}`)
  const out = (j.choices?.[0]?.message?.content || '').trim().replace(/^```(?:json)?\s*|\s*```$/g, '')
  return JSON.parse(out.slice(out.indexOf('{'), out.lastIndexOf('}') + 1))
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

const capturesFile = (user) => join(DATA, 'u', user, 'captures.json')

// ── routes ───────────────────────────────────────────────────────────────────

createServer(async (req, res) => {
  try {
    const url = new URL(req.url, 'http://localhost')
    const m = url.pathname.match(/^\/u\/([A-Za-z0-9_-]{8,64})\/(gloss|captures)$/)

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

      const out = await llm(GLOSS(tokens))
      const words = (out.w || [])
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
      return json(res, 200, { words })
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
