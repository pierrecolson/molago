// La traduction d'un transcript, côté serveur.
//
// Elle vivait sur l'iPhone, par Apple Translation : gratuit, hors ligne, et
// **inutilisable**. Mesuré sur un iPhone 15 Pro Max : 0,55 seconde par ligne,
// sans démarrage lent — une vidéo d'une heure, 879 répliques, demandait
// 8 minutes 40 écran allumé et l'app au premier plan, iOS suspendant la
// traduction dès qu'on en sort. Des lots plus gros ne vont pas plus vite : à
// deux cents lignes, l'app tombe.
//
// Ici, les tranches partent en parallèle et l'heure de vidéo est traduite en
// une trentaine de secondes. Comme le transcript, la traduction est gardée sur
// disque : on ne la paye qu'une fois par vidéo, jamais par import.

// Une tranche par appel au modèle, plusieurs appels de front. Cinquante
// répliques tiennent largement dans une réponse et gardent au modèle assez de
// contexte pour ne pas traduire chaque ligne dans le vide.
const CHUNK = 50

const PROMPT = (lines, first) => `Voici les répliques successives d'une vidéo en coréen, numérotées.

${lines.map((line, i) => `${first + i}. ${line}`).join('\n')}

Traduis chaque réplique en anglais.

Règles :
- Une réplique donne exactement une traduction, dans le même ordre. Ne fusionne rien, ne saute rien, n'ajoute rien.
- Ce sont des sous-titres : la coupure tombe souvent au milieu d'une phrase. Traduis le morceau tel qu'il est, sans le compléter.
- Anglais parlé et naturel, pas de calque mot à mot, pas de commentaire.
- Une réplique vide de sens rend une chaîne vide.

Réponds en JSON strict : {"t":[{"i":<numéro>,"e":"la traduction"}]}`

/// Traduit `lines` et rend un tableau de la même longueur. Une tranche qui
/// échoue deux fois rend des chaînes vides plutôt que de perdre les autres :
/// une réplique sans anglais reste lisible en coréen, un import perdu non.
export async function translateLines(lines, options = {}) {
  const ask = options.llm
  if (!ask) throw new Error('translateLines: il faut un modèle')
  const out = Array(lines.length).fill('')

  const chunks = []
  for (let start = 0; start < lines.length; start += CHUNK) {
    chunks.push({ start, slice: lines.slice(start, start + CHUNK) })
  }

  await Promise.all(chunks.map(async ({ start, slice }) => {
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        const reply = await ask(PROMPT(slice, start))
        const rows = Array.isArray(reply) ? reply : reply?.t
        if (!Array.isArray(rows)) throw new Error('réponse sans tableau')
        let placed = 0
        for (const row of rows) {
          const i = Number(row?.i)
          if (!Number.isInteger(i) || i < start || i >= start + slice.length) continue
          out[i] = String(row.e ?? '').trim()
          placed++
        }
        // Une tranche à moitié rendue est une tranche ratée : le modèle a
        // décroché en route, et garder la moitié désaligne la lecture.
        if (placed < slice.length) throw new Error(`${placed}/${slice.length} rendues`)
        return
      } catch {
        for (let i = start; i < start + slice.length; i++) out[i] = ''
      }
    }
  }))

  return out
}
