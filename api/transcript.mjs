// Le transcript minuté d'une vidéo YouTube, et rien d'autre.
//
// `yt-dlp` depuis le VPS reçoit « Sign in to confirm you're not a bot » : c'est
// la réputation de l'adresse IP qui décide, et un centre de données perd à tous
// les coups. Aucun réglage ne répare ça — il fallait sortir du scraping.
//
// Deux fournisseurs, pour deux raisons distinctes :
//   Supadata          → les sous-titres coréens minutés (100 crédits gratuits/mois)
//   YouTube Data API  → le titre, la chaîne, la durée, la miniature (1 unité sur
//                       10 000 par jour, et la seule route officielle du dossier)
//
// Un second endpoint Supadata pour les métadonnées coûterait un crédit, donc la
// moitié du quota mensuel. Les deux appels partent en parallèle : ni l'un ni
// l'autre n'a besoin du résultat de son voisin.
//
// **L'app ne connaît qu'une adresse.** Tout ce qui touche à un fournisseur vit
// dans ce fichier : en changer ne touche pas une version déjà publiée. C'est la
// seule assurance qui vaille contre la disparition d'un fournisseur.

// Surchargeables pour les tests de route, qui pointent les deux vers un stub
// local — un test qui aurait besoin du réseau serait un test à corriger.
const SUPADATA_URL = process.env.SUPADATA_URL || 'https://api.supadata.ai/v1/transcript'
const YOUTUBE_API_URL = process.env.YOUTUBE_API_URL || 'https://www.googleapis.com/youtube/v3/videos'

const YOUTUBE_HOSTS = new Set([
  'youtube.com',
  'www.youtube.com',
  'm.youtube.com',
  'music.youtube.com',
  'youtu.be',
])

const inputError = (message = 'Enter a valid YouTube link.') =>
  Object.assign(new Error(message), { statusCode: 400 })

// Rien du fournisseur ne remonte : ni sa clé, ni son corps de réponse, ni son
// code HTTP. L'app affiche une phrase, pas une panne.
const providerError = () =>
  Object.assign(new Error('The transcript service is unavailable.'), { statusCode: 503 })

export function parseYouTubeURL(value) {
  let url
  try { url = new URL(String(value || '').trim()) } catch { throw inputError() }
  if (!['http:', 'https:'].includes(url.protocol) || !YOUTUBE_HOSTS.has(url.hostname.toLowerCase())) {
    throw inputError()
  }
  const videoPath = url.hostname.toLowerCase() === 'youtu.be'
    ? url.pathname.length > 1
    : url.searchParams.has('v') || /^\/(shorts|live|embed)\//.test(url.pathname)
  if (!videoPath) throw inputError('Enter a YouTube video link, not a channel.')
  return url
}

export function videoIDFrom(url) {
  const segments = url.pathname.split('/').filter(Boolean)
  const id = url.hostname.toLowerCase() === 'youtu.be'
    ? segments[0]
    : url.searchParams.get('v') || segments[1]
  if (!/^[A-Za-z0-9_-]{11}$/.test(id || '')) throw inputError()
  return id
}

/// `PT4M13S` → 253. La YouTube Data API ne rend la durée que comme ça.
export function secondsFromISO(value) {
  const m = String(value || '').match(/^P(?:\d+D)?T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$/)
  if (!m) return 0
  return Number(m[1] || 0) * 3600 + Number(m[2] || 0) * 60 + Number(m[3] || 0)
}

// Supadata rend le texte tel que YouTube l'encode, parfois encodé deux fois :
// `We&amp;#39;re` pour `We're`. Le chemin VTT décodait déjà ces entités ; les
// perdre aurait mis `&#39;` sous les yeux du lecteur.
const decode = (value) => {
  let text = value
  for (let pass = 0; pass < 2 && /&[#\w]+;/.test(text); pass++) {
    text = text.replace(/&#(\d+);/g, (_, code) => String.fromCharCode(Number(code)))
      .replace(/&nbsp;/g, ' ').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"').replace(/&#?39;/g, "'").replace(/&amp;/g, '&')
  }
  return text.replace(/\s+/g, ' ').trim()
}

async function captions(id, call) {
  const url = new URL(SUPADATA_URL)
  url.searchParams.set('url', `https://www.youtube.com/watch?v=${id}`)
  url.searchParams.set('lang', 'ko')
  // Épinglé : le mode `auto` laisserait Supadata *générer* les sous-titres par
  // IA, facturés 2 crédits par minute de vidéo. Ça ne part jamais tout seul.
  url.searchParams.set('mode', 'native')

  const response = await call(url.href, { headers: { 'x-api-key': process.env.SUPADATA_API_KEY || '' } })
  if (!response.ok) throw providerError()
  const body = await response.json()
  const cues = (Array.isArray(body?.content) ? body.content : [])
    .map((cue) => ({
      start: Number(cue.offset || 0) / 1000,
      end: (Number(cue.offset || 0) + Number(cue.duration || 0)) / 1000,
      ko: decode(String(cue?.text || '')),
    }))
    .filter((cue) => cue.ko)

  // Supadata étiquette `ko` une piste que YouTube lui a rendue en anglais : la
  // vidéo de référence anglaise revient ainsi, mot pour mot en anglais, sous
  // une étiquette coréenne. Sans coréen dedans, il n'y a pas de transcript —
  // et une vidéo sans transcript reste importable et regardable, vide.
  return cues.some((cue) => /[가-힣]/.test(cue.ko)) ? cues : []
}

async function metadata(id, call) {
  const url = new URL(YOUTUBE_API_URL)
  url.searchParams.set('part', 'snippet,contentDetails')
  url.searchParams.set('id', id)
  url.searchParams.set('key', process.env.YOUTUBE_API_KEY || '')

  const response = await call(url.href)
  if (!response.ok) throw providerError()
  const item = (await response.json())?.items?.[0]
  if (!item) return null
  const thumbnails = item.snippet?.thumbnails || {}
  return {
    title: String(item.snippet?.title || '').trim(),
    channel: String(item.snippet?.channelTitle || '').trim(),
    duration: secondsFromISO(item.contentDetails?.duration),
    thumbnail: (thumbnails.maxres || thumbnails.standard || thumbnails.high || {}).url || null,
  }
}

export async function fetchTranscript(value, options = {}) {
  // D'abord l'URL : un mauvais lien ne doit jamais dépenser un crédit.
  const url = parseYouTubeURL(value)
  const id = videoIDFrom(url)
  const call = options.fetch || fetch

  // Les métadonnées sont un bonus. Un titre manquant ne doit pas perdre un
  // transcript — c'est le transcript qu'on est venu chercher.
  const [cues, about] = await Promise.all([
    captions(id, call),
    metadata(id, call).catch(() => null),
  ])

  return {
    videoID: id,
    title: about?.title || 'YouTube video',
    channel: about?.channel || 'YouTube',
    duration: about?.duration || Math.round(cues.at(-1)?.end || 0),
    thumbnail: about?.thumbnail || `https://i.ytimg.com/vi/${id}/hqdefault.jpg`,
    sourceURL: `https://www.youtube.com/watch?v=${id}`,
    cues,
  }
}
