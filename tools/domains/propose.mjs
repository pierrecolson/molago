#!/usr/bin/env node
// Propose une icône Thiings pour chaque domaine sémantique.
//
// Le raisonnement : un modèle sait mal nommer l'objet que désigne un mot — il
// se fait piéger par l'homonymie anglaise — mais il sait très bien **classer**
// dans une liste fixe. On renverse donc encore une fois : au lieu de chercher
// une icône par mot, on fixe une cinquantaine de domaines, on choisit une icône
// par domaine une fois pour toutes, et chaque mot hérite de celle de son
// domaine. Les mots vraiment concrets gardent leur icône propre, plus précise.
//
//   node tools/domains/propose.mjs > tools/domains/candidates.json
//
// Tourne sur le VPS (l'API Thiings n'écoute qu'en local).

import { readFileSync, existsSync } from 'node:fs'

const env = (() => {
  const out = { ...process.env }
  for (const p of ['/root/molago/.env', new URL('../../.env', import.meta.url).pathname]) {
    if (!existsSync(p)) continue
    for (const l of readFileSync(p, 'utf8').split('\n')) {
      const m = l.match(/^\s*([A-Z_][A-Z0-9_]*)\s*=\s*(.*)$/)
      if (m && m[2].trim()) out[m[1]] ||= m[2].trim().replace(/^["']|["']$/g, '')
    }
    break
  }
  return out
})()

const URL_ = env.THIINGS_URL || 'http://localhost:3088'

// Les domaines viennent de la vie réelle d'un étranger à Séoul et des trois
// univers de la spec — le cerveau, la conversation, la vie. Chacun porte
// plusieurs termes de recherche : le premier qui trouve une icône gagne.
const DOMAINS = [
  // ── la vie quotidienne ────────────────────────────────────────────────────
  ['housing', 'logement, appartement, loyer', ['apartment building', 'house', 'apartment']],
  ['bills', 'factures, charges, échéances', ['invoice', 'receipt', 'bill']],
  ['money', 'argent, prix, paiement', ['money', 'coins', 'wallet']],
  ['banking', 'banque, compte, virement', ['bank', 'credit card', 'atm']],
  ['admin', 'démarches, papiers, guichet', ['document', 'stamp', 'folder']],
  ['health', 'santé, symptômes, médecin', ['stethoscope', 'first aid kit', 'hospital']],
  ['pharmacy', 'pharmacie, médicaments', ['pharmacy', 'pills', 'medicine bottle']],
  ['food', 'nourriture, plats, cuisine', ['shakshuka', 'bowl of rice', 'noodles']],
  ['drinks', 'boissons, alcool', ['soju', 'coffee', 'beer']],
  ['restaurant', 'restaurant, commande, service', ['restaurant', 'menu', 'table']],
  ['groceries', 'courses alimentaires, supérette', ['bag of groceries', 'grocery bag', 'shopping cart']],
  ['shopping', 'magasins, achats, boutiques', ['shopping bag', 'store', 'price tag']],
  ['social', 'sortir, voir du monde, se retrouver', ['group of people', 'crowd of people', 'two people']],
  ['delivery', 'livraison, colis', ['delivery box', 'package', 'parcel']],
  ['transport', 'métro, bus, trajets', ['subway train', 'bus', 'train']],
  ['driving', 'voiture, taxi, route', ['taxi', 'car', 'steering wheel']],
  ['phone', 'téléphone, forfait, appels', ['smartphone', 'phone', 'sim card']],
  ['internet', 'internet, applis, sites', ['wifi router', 'globe', 'browser window']],
  ['neighbourhood', 'quartier, voisins, immeuble', ['neighborhood', 'mailbox', 'front door']],
  ['weather', 'météo, saisons', ['umbrella', 'sun', 'snowflake']],
  ['clothing', 'vêtements, taille', ['t-shirt', 'jacket', 'shoes']],
  ['family', 'famille, relations, amis', ['family', 'two people', 'heart']],
  ['home-life', 'ménage, objets du quotidien', ['broom', 'washing machine', 'chair']],

  // ── le travail ────────────────────────────────────────────────────────────
  ['work', 'bureau, entreprise, collègues', ['office building', 'briefcase', 'desk']],
  ['hierarchy', 'titres, ancienneté, respect', ['business suit', 'name tag', 'crown']],
  ['meetings', 'réunions, rendez-vous', ['calendar', 'meeting room', 'clock']],
  ['salary', 'salaire, contrat, emploi', ['paycheck', 'contract', 'handshake']],
  ['education', 'études, examens, école', ['graduation cap', 'school', 'pencil']],

  // ── l'actualité coréenne ──────────────────────────────────────────────────
  ['law', 'justice, tribunaux, procès', ['gavel', 'scales of justice', 'courthouse']],
  ['crime', 'police, enquête, délits', ['police badge', 'handcuffs', 'police car']],
  ['politics', 'gouvernement, élections', ['elected official', 'ballot box', 'government building']],
  ['military', 'armée, service, sécurité', ['military helmet', 'tank', 'soldier']],
  ['economy', 'économie, marchés, inflation', ['stock chart', 'graph', 'briefcase']],
  ['business', 'entreprises, secteurs', ['factory', 'skyscraper', 'handshake']],
  ['realestate', 'immobilier, jeonse, marché', ['for sale sign', 'house key', 'blueprint']],
  ['society', 'société, population, tendances', ['crowd of people', 'city', 'group']],
  ['media', 'presse, télévision, culture', ['television', 'newspaper', 'microphone']],
  ['sports', 'sport, compétitions', ['soccer ball', 'trophy', 'stopwatch']],
  ['travel', 'voyage, tourisme, aéroport', ['suitcase', 'airplane', 'passport']],

  // ── la tech et la science ─────────────────────────────────────────────────
  ['software', 'logiciel, code, développement', ['code', 'laptop', 'terminal']],
  ['hardware', 'matériel, puces, appareils', ['computer chip', 'server', 'circuit board']],
  ['ai', 'intelligence artificielle, données', ['robot', 'brain', 'database']],
  ['science', 'recherche, découvertes', ['microscope', 'test tube', 'telescope']],
  ['energy', 'énergie, environnement, climat', ['light bulb', 'solar panel', 'battery']],
  ['space', 'espace, astronomie', ['rocket', 'planet', 'satellite']],

  // ── ce qui n'est pas une chose ────────────────────────────────────────────
  // Ces domaines-là couvrent l'abstrait, et c'est justement eux qui faisaient
  // tomber les mots dans la tuile typographique. Une icône de domaine n'y
  // prétend pas montrer le mot : elle dit de quoi il parle.
  ['speech', 'parler, dire, demander', ['speech bubble', 'megaphone', 'microphone']],
  ['thought', 'penser, croire, comprendre', ['brain', 'light bulb', 'thought bubble']],
  ['emotion', 'sentiments, humeur, ambiance', ['heart', 'smiley face', 'mood ring']],
  ['time', 'temps, durée, moments', ['clock', 'hourglass', 'calendar']],
  ['quantity', 'nombres, mesures, degrés', ['ruler', 'scale', 'calculator']],
  ['change', 'évolution, hausse, baisse', ['upward arrow', 'chart', 'arrows']],
  ['comparison', 'comparer, semblable, différent', ['balance scale', 'two arrows', 'equals sign']],
  ['movement', 'aller, venir, déplacements', ['footprints', 'arrow', 'road']],
  ['rules', 'règles, obligations, permissions', ['checklist', 'clipboard', 'rulebook']],
  ['problem', 'problèmes, erreurs, risques', ['warning sign', 'error', 'exclamation mark']],
]

async function search(q) {
  const r = await fetch(`${URL_}/icons?search=${encodeURIComponent(q)}&limit=12`, {
    headers: { authorization: `Bearer ${env.THIINGS_API_KEY}` },
    signal: AbortSignal.timeout(10000),
  })
  if (!r.ok) return []
  const b = await r.json()
  return (Array.isArray(b) ? b : (b.icons || b.data || []))
}

const out = []
for (const [id, label, terms] of DOMAINS) {
  let picks = []
  for (const t of terms) {
    const items = await search(t)
    // Titre identique d'abord, sinon le plus court qui contient le terme —
    // le plus court est le plus générique, donc le plus juste pour un domaine.
    const exact = items.find((i) => String(i.title || '').toLowerCase() === t)
    const loose = items
      .filter((i) => String(i.title || '').toLowerCase().includes(t.split(' ').at(-1)))
      .sort((a, b) => String(a.title).length - String(b.title).length)[0]
    const hit = exact || loose
    if (hit) picks.push({ term: t, slug: hit.slug, title: hit.title })
    if (picks.length >= 3) break
  }
  out.push({ id, label, picks })
  process.stderr.write(`${picks.length ? '✓' : '✕'} ${id}\n`)
}

console.log(JSON.stringify(out, null, 2))
