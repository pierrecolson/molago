#!/usr/bin/env node
// Banc d'essai de l'appariement des icônes.
//
// Il travaille sur une journée **déjà fabriquée** : aucun texte n'est regénéré,
// aucune voix n'est synthétisée. Vérifier une règle d'appariement passe donc de
// douze minutes et 0,84 $ à quelques secondes et deux centimes.
//
// C'est l'outil qui manquait : j'ai relancé dix fabrications complètes pour
// régler des icônes, ce qui a consommé l'essentiel du crédit du projet.
//
//   docker run --rm -v /root/molago:/w -w /w \
//     --add-host host.docker.internal:host-gateway --env-file /root/molago/.env \
//     -e THIINGS_URL=http://host.docker.internal:3088 \
//     node:22-slim node bench.mjs <fichier-du-jour.json>

import { readFileSync, existsSync } from 'node:fs'

const env = (() => {
  const out = { ...process.env }
  for (const p of ['/w/.env', '/root/molago/.env', new URL('../../.env', import.meta.url).pathname]) {
    if (!existsSync(p)) continue
    for (const l of readFileSync(p, 'utf8').split('\n')) {
      const m = l.match(/^\s*([A-Z_][A-Z0-9_]*)\s*=\s*(.*)$/)
      if (m && m[2].trim()) out[m[1]] ||= m[2].trim().replace(/^["']|["']$/g, '')
    }
    break
  }
  return out
})()

const THIINGS = env.THIINGS_URL || 'http://localhost:3088'
const CLERK = 'openai/gpt-5-mini'
let cost = 0

const file = process.argv[2]
if (!file) { console.error('usage: node bench.mjs <fichier-du-jour.json>'); process.exit(1) }
const day = JSON.parse(readFileSync(file, 'utf8'))

// ── les mêmes règles que la fabrique, isolées pour être éprouvées ────────────

const OBJECTS = (rows) => `Voici des noms coréens avec leur sens. Pour chacun, dis s'il désigne un **objet physique qu'on pourrait poser sur une table ou photographier**.

${rows.map((r, i) => `${i}. ${r.lemma} — ${r.meaning}`).join('\n')}

Si oui, nomme cet objet en un ou deux mots anglais, comme on l'étiquetterait dans une bibliothèque d'icônes 3D d'objets du quotidien.

Réponds « non » pour tout le reste, et le reste est la majorité :
- les idées, relations, quantités, processus, qualités
- les termes techniques abstraits (plateforme, type, ligne de traitement, version)
- les actions, les états, les périodes
- les institutions et les concepts juridiques ou administratifs

Ne te laisse jamais guider par le mot anglais du sens : « platform » la plateforme logicielle n'est pas un quai, « goal » l'objectif n'est pas un but de football, « scale » l'échelle n'est pas une balance.

Réponds en JSON : {"o":[{"i":<numéro>,"n":"the object in one or two words"}]}`

async function llm(prompt) {
  const r = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      authorization: `Bearer ${env.OPENROUTER_API_KEY}`,
      'content-type': 'application/json',
      'x-title': 'Molago icon bench',
    },
    body: JSON.stringify({
      model: CLERK,
      messages: [{ role: 'user', content: prompt }],
      max_tokens: 3000,
      response_format: { type: 'json_object' },
    }),
  })
  const j = await r.json()
  if (!r.ok || j.error) throw new Error(j.error?.message || `HTTP ${r.status}`)
  if (typeof j.usage?.cost === 'number') cost += j.usage.cost
  const out = (j.choices?.[0]?.message?.content || '').trim().replace(/^```(?:json)?\s*|\s*```$/g, '')
  return JSON.parse(out.slice(out.indexOf('{'), out.lastIndexOf('}') + 1))
}

async function titlesFor(name) {
  const r = await fetch(`${THIINGS}/icons?search=${encodeURIComponent(name)}&limit=20`, {
    headers: { authorization: `Bearer ${env.THIINGS_API_KEY}` },
    signal: AbortSignal.timeout(8000),
  })
  if (!r.ok) return []
  const b = await r.json()
  return (Array.isArray(b) ? b : (b.icons || b.data || [])).map((i) => i.title)
}

// ── essai ────────────────────────────────────────────────────────────────────

for (const text of day.texts) {
  const wanted = new Map()
  for (const s of text.sentences) {
    for (const w of s.words ?? []) {
      if (w.pos === 'noun' && w.en && w.lemma && !wanted.has(w.lemma)) wanted.set(w.lemma, w.en)
    }
  }
  const rows = [...wanted].map(([lemma, meaning]) => ({ lemma, meaning }))
  if (!rows.length) continue

  const out = await llm(OBJECTS(rows))
  const named = (out.o || []).filter((x) => rows[x.i] && x.n)

  console.log(`\n▸ ${text.universe} — ${rows.length} noms, ${named.length} nommés comme objets`)
  for (const x of named) {
    const name = String(x.n).trim().toLowerCase()
    const titles = await titlesFor(name)
    const exact = titles.find((t) => t.toLowerCase() === name)
    console.log(`   ${exact ? '✓' : '·'} ${rows[x.i].lemma.padEnd(12)} ${rows[x.i].meaning.slice(0, 26).padEnd(28)} → ${name.padEnd(18)} ${exact ?? '(' + (titles[0] ?? 'rien') + ')'}`)
  }
}

console.log(`\ncoût de cet essai : ${cost.toFixed(4)} $`)
