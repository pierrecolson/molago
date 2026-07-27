#!/usr/bin/env node
// M0 — l'essai comparatif à l'aveugle (product-spec.md §14).
//
// Prend un vrai article coréen du jour, le fait réécrire en ~300 mots par
// plusieurs modèles, fait lire le même paragraphe authentique par plusieurs
// voix, et produit une page locale où tout est mélangé et anonyme.
//
//   node tools/m0-blind-test/run.mjs [--url <article>] [--models a,b,c]
//
// Sortie : docs/m0/index.html  ·  docs/m0/audio/*.mp3  ·  docs/m0/key.json

import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..')
const OUT = join(ROOT, 'docs', 'm0')
// Plusieurs quotidiens : quand l'un coupe la connexion, on passe au suivant.
const FEEDS = [
  { name: 'Donga', url: 'https://rss.donga.com/total.xml' },
  { name: 'Yonhap', url: 'https://www.yna.co.kr/rss/news.xml' },
]
const UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'

// Candidats de génération, par ordre de préférence. Le script garde ceux
// qu'OpenRouter expose réellement au moment où il tourne.
// Un par maison, plus le coréen natif : c'est l'écart entre maisons qui
// renseigne, pas trois variantes du même modèle.
const WANTED = [
  'openai/gpt-5.1',              // le pari de la spec §9.3
  'upstage/solar-pro-3',         // coréen natif, licence commerciale
  'google/gemini-3.1-pro-preview',
  'anthropic/claude-opus-4.5',
  'openai/gpt-5.5',
  'qwen/qwen3-max',
  'google/gemini-2.5-pro',
]
const MAX_MODELS = 5

// ── plomberie ────────────────────────────────────────────────────────────────

const env = (() => {
  const out = { ...process.env }
  const p = join(ROOT, '.env')
  if (existsSync(p)) {
    for (const line of readFileSync(p, 'utf8').split('\n')) {
      const m = line.match(/^\s*([A-Z_][A-Z0-9_]*)\s*=\s*(.*)$/)
      if (m) {
        const v = m[2].trim().replace(/^["']|["']$/g, '')
        if (v) out[m[1]] = v
      }
    }
  }
  return out
})()

const has = (k) => typeof env[k] === 'string' && env[k].length > 8
const arg = (name) => {
  const i = process.argv.indexOf(`--${name}`)
  return i > -1 ? process.argv[i + 1] : null
}
const log = (...a) => console.log(...a)
const strip = (s) => s.replace(/<[^>]+>/g, '')
const unent = (s) =>
  s.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"')
   .replace(/&#39;/g, "'").replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&')
const esc = (s) =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')

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

// Mélange déterministe à partir d'une graine, pour que la page soit
// reproductible si on la régénère avec les mêmes entrées.
function shuffle(arr, seed) {
  const a = [...arr]
  let s = seed
  for (let i = a.length - 1; i > 0; i--) {
    s = (s * 1103515245 + 12345) & 0x7fffffff
    const j = s % (i + 1)
    ;[a[i], a[j]] = [a[j], a[i]]
  }
  return a
}

// ── 1 · l'article source ─────────────────────────────────────────────────────

const JUNK = [
  '연합뉴스만의', '구글 검색', '제보는', '카카오톡', '저작권자', '무단 전재',
  '기사제보', '네이버에서', '이 기사는', '앱 다운로드', '구독', '댓글',
]

// Extracteur générique : aucun sélecteur propre à un journal. On aplatit la
// page en lignes, on ne garde que celles qui ressemblent à de la prose
// coréenne, et on retient la plus longue suite continue — c'est le corps de
// l'article. Les encarts et les listes d'articles liés ne forment jamais de
// suite longue.
function bodyFrom(html) {
  const lines = html
    .replace(/<(script|style|noscript)[\s\S]*?<\/\1>/gi, ' ')
    .replace(/<br\s*\/?>|<\/(p|div|li|h[1-6]|section|article)>/gi, '\n')
    .split('\n')
    .map((l) => unent(strip(l)).replace(/\s+/g, ' ').trim())

  const ok = (t) =>
    t.length > 45 &&
    /[가-힣]/.test(t) &&
    /[.?!"'”’\]]$|다\.?$/.test(t) &&          // une phrase, pas un titre de menu
    !JUNK.some((j) => t.includes(j))

  // On prend toutes les lignes qui passent le filtre, sans exiger qu'elles se
  // suivent : les encarts publicitaires et les images coupent le corps en
  // morceaux, et les titres d'articles liés sont déjà écartés par `ok`.
  return [...new Set(lines.filter(ok))]
    // Yonhap préfixe le chapô de « (수원=연합뉴스) 권준우 기자 = ».
    .map((t) => t.replace(/^\([^)]{2,30}\)\s*[^=]{0,20}=\s*/, ''))
}

async function pickArticle() {
  const forced = arg('url')
  if (forced) {
    const html = await (await get(forced)).text()
    const title = unent((html.match(/<title>([^<]*)<\/title>/) || [, forced])[1]).split('|')[0].trim()
    return { url: forced, title, paras: bodyFrom(html) }
  }

  let items = []
  for (const f of FEEDS) {
    try {
      const xml = await (await get(f.url)).text()
      items = [...xml.matchAll(/<item>([\s\S]*?)<\/item>/g)].map((m) => {
        const t = m[1].match(/<title>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/title>/)
        const l = m[1].match(/<link>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/link>/)
        return { title: unent((t?.[1] || '').trim()), url: (l?.[1] || '').trim() }
      })
      if (items.length) { log(`· flux ${f.name} — ${items.length} articles`); break }
    } catch (e) { log(`· flux ${f.name} indisponible (${e.message.slice(0, 40)})`) }
  }
  if (!items.length) throw new Error('aucun flux joignable')

  // Ce qui ne se raconte pas : météo, sports, carnets, cotations brutes.
  const skip = /날씨|부고|프로야구|프로축구|증시|환율|종합\s*\d|일지|인사|동정|사진|영상/
  // Les communiqués de collectivité sont du coréen formulaire : tous les
  // modèles y sonnent pareil et guindé, donc ils ne départagent rien.
  const pressRelease =
    /[가-힣]+(군|시|도|청|공사|공단|재단)[,\s].*(확정|추진|착수|개최|위촉|기탁|협약|간담회|워크숍|선정|준공|개소|출범|시행|모집)/

  // Les trois univers de Molago : le cerveau, la conversation, la vie. Rien de
  // tout ça n'est du potin de célébrité — et la spec est explicite, la pop
  // culture coréenne n'intéresse pas le lecteur.
  const gossip = /연예|배우|가수|아이돌|드라마|예능|열애|결혼설|불화설|이혼|팬미팅|컴백|소속사/
  const rank = (u) =>
    /\/(Economy|It|Science|Inter)\//i.test(u) ? 0 :
    /\/(Society|Politics|Health)\//i.test(u) ? 1 : 2

  const cands = items
    .filter((i) => i.url && !skip.test(i.title) && !pressRelease.test(i.title))
    .filter((i) => !gossip.test(i.title) && !/\/(Entertainment|Sports|Photo)\//i.test(i.url))
    .sort((a, b) => rank(a.url) - rank(b.url))
    .slice(0, 25)

  // Le flux est trié du plus récent au plus ancien : on prend le premier
  // article d'une longueur racontable, pas le plus long du lot.
  const rejected = []
  for (const c of cands) {
    try {
      const html = await (await get(c.url)).text()
      const paras = bodyFrom(html)
      const len = paras.join(' ').length
      if (len >= 700) return { ...c, paras, len }
      rejected.push(`trop court (${len}) — ${c.title.slice(0, 40)}`)
    } catch (e) {
      rejected.push(`${e.message.slice(0, 40)} — ${c.title.slice(0, 40)}`)
    }
    // Yonhap coupe la connexion si on enchaîne trop vite.
    await new Promise((r) => setTimeout(r, 500))
  }
  throw new Error(
    `aucun article exploitable (${cands.length} candidats)\n  ` + rejected.slice(0, 8).join('\n  '),
  )
}

// ── 2 · génération ───────────────────────────────────────────────────────────

const PROMPT = (title, body) => `Tu réécris un article de presse coréen pour un lecteur étranger de niveau intermédiaire-avancé qui vit en Corée depuis huit ans.

ARTICLE SOURCE
Titre : ${title}

${body}

CONSIGNES
- Réécris les faits de cet article en coréen, en environ 300 mots (어절).
- N'invente aucun fait. Tout ce que tu écris doit venir de l'article ci-dessus.
- Registre : journalistique léger, 해요체 ou 합니다체 selon ce qui sonne le plus naturel.
- Vocabulaire de niveau intermédiaire-avancé. Évite les termes rares et le jargon administratif inutile.
- Le résultat doit sonner comme du coréen écrit par un Coréen, pas comme une traduction. Pas de 번역투.
- Phrases de longueur variée. Collocations naturelles.
- Réponds UNIQUEMENT avec le texte coréen. Pas de titre, pas de commentaire, pas de balisage.`

async function generate(model, title, body) {
  const r = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      authorization: `Bearer ${env.OPENROUTER_API_KEY}`,
      'content-type': 'application/json',
      'x-title': 'Molago M0 blind test',
    },
    body: JSON.stringify({
      model,
      messages: [{ role: 'user', content: PROMPT(title, body) }],
      // Large : les modèles à raisonnement consomment ce budget avant d'écrire
      // un seul caractère, et rendent une réponse vide s'il est trop serré.
      max_tokens: 8000,
    }),
  })
  const j = await r.json()
  if (!r.ok || j.error) throw new Error(j.error?.message || `HTTP ${r.status}`)
  let text = (j.choices?.[0]?.message?.content || '').trim()
  if (text.length < 120) throw new Error('réponse trop courte')

  // Certains modèles remettent le titre en tête malgré la consigne. On le
  // retire : sinon ce texte est reconnaissable d'un coup d'œil et l'aveugle
  // ne tient plus. L'écart est consigné dans key.json, il n'est pas perdu.
  let titled = false
  const first = text.split('\n')[0].trim()
  if (first.length < 90 && !/[.!?]$|다\.$|요\.$/.test(first) && text.includes('\n')) {
    text = text.slice(text.indexOf('\n') + 1).trim()
    titled = true
  }
  return { text, titled, cost: j.usage?.cost ?? null }
}

async function availableModels() {
  const j = await (await get('https://openrouter.ai/api/v1/models')).json()
  const ids = new Set((j.data || []).map((m) => m.id))
  const forced = arg('models')
  if (forced) return forced.split(',').map((s) => s.trim())
  return WANTED.filter((m) => ids.has(m)).slice(0, MAX_MODELS)
}

// ── 3 · voix ─────────────────────────────────────────────────────────────────

async function elevenlabs(text) {
  const vj = await (await get('https://api.elevenlabs.io/v1/voices', {
    'xi-api-key': env.ELEVENLABS_API_KEY,
  })).json()
  const voice = (vj.voices || [])[0]
  if (!voice) throw new Error('aucune voix disponible sur le compte')
  const r = await fetch(
    `https://api.elevenlabs.io/v1/text-to-speech/${voice.voice_id}`,
    {
      method: 'POST',
      headers: { 'xi-api-key': env.ELEVENLABS_API_KEY, 'content-type': 'application/json' },
      body: JSON.stringify({ text, model_id: 'eleven_multilingual_v2' }),
    },
  )
  if (!r.ok) throw new Error(`${r.status} ${(await r.text()).slice(0, 160)}`)
  return { buf: Buffer.from(await r.arrayBuffer()), detail: voice.name }
}

async function googletts(text) {
  const key = env.GOOGLE_TTS_API_KEY
  const vj = await (await get(
    `https://texttospeech.googleapis.com/v1/voices?languageCode=ko-KR&key=${key}`,
  )).json()
  const names = (vj.voices || []).map((v) => v.name)
  const name =
    names.find((n) => n.includes('Chirp3-HD')) ||
    names.find((n) => n.includes('Neural2')) ||
    names.find((n) => n.includes('Wavenet')) ||
    names[0]
  if (!name) throw new Error('aucune voix ko-KR')
  const r = await fetch(
    `https://texttospeech.googleapis.com/v1/text:synthesize?key=${key}`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        input: { text },
        voice: { languageCode: 'ko-KR', name },
        // LINEAR16 et non MP3 : le MP3 de Google sort en 32 kbps, contre 128
      // chez ElevenLabs. À l'aveugle, l'encodage déciderait à la place de la
      // voix. Le navigateur lit le WAV directement.
      audioConfig: { audioEncoding: 'LINEAR16', sampleRateHertz: 24000 },
      }),
    },
  )
  const j = await r.json()
  if (!r.ok || j.error) throw new Error(j.error?.message || `HTTP ${r.status}`)
  return { buf: Buffer.from(j.audioContent, 'base64'), detail: name, ext: 'wav' }
}

async function openaitts(text) {
  const r = await fetch('https://api.openai.com/v1/audio/speech', {
    method: 'POST',
    headers: { authorization: `Bearer ${env.OPENAI_API_KEY}`, 'content-type': 'application/json' },
    body: JSON.stringify({ model: 'gpt-4o-mini-tts', voice: 'alloy', input: text }),
  })
  if (!r.ok) throw new Error(`${r.status} ${(await r.text()).slice(0, 160)}`)
  return { buf: Buffer.from(await r.arrayBuffer()), detail: 'gpt-4o-mini-tts · alloy' }
}

const VOICES = [
  { id: 'elevenlabs', label: 'ElevenLabs', key: 'ELEVENLABS_API_KEY', fn: elevenlabs },
  { id: 'google', label: 'Google Cloud TTS', key: 'GOOGLE_TTS_API_KEY', fn: googletts },
  { id: 'openai', label: 'OpenAI TTS', key: 'OPENAI_API_KEY', fn: openaitts },
]

// ── 4 · la page ──────────────────────────────────────────────────────────────

function page({ article, reference, texts, clips, voiceParagraph }) {
  const textCards = texts.map((t, i) => `
    <section class="cand">
      <div class="cand-h"><span class="badge">${String.fromCharCode(65 + i)}</span>
        <span class="rank">Naturel ?
          <label><input type="radio" name="r${i}" value="1">1</label>
          <label><input type="radio" name="r${i}" value="2">2</label>
          <label><input type="radio" name="r${i}" value="3">3</label>
          <label><input type="radio" name="r${i}" value="4">4</label>
          <label><input type="radio" name="r${i}" value="5">5</label>
        </span></div>
      <p class="ko">${esc(t.text)}</p>
      <div class="reveal" hidden>${esc(t.model)}</div>
    </section>`).join('')

  const clipCards = clips.map((c, i) => `
    <section class="cand">
      <div class="cand-h"><span class="badge">${i + 1}</span>
        <span class="rank">Voix ?
          <label><input type="radio" name="v${i}" value="1">1</label>
          <label><input type="radio" name="v${i}" value="2">2</label>
          <label><input type="radio" name="v${i}" value="3">3</label>
          <label><input type="radio" name="v${i}" value="4">4</label>
          <label><input type="radio" name="v${i}" value="5">5</label>
        </span></div>
      <audio controls preload="none" src="audio/${c.file}"></audio>
      <div class="reveal" hidden>${esc(c.label)} — ${esc(c.detail)}</div>
    </section>`).join('')

  return `<!doctype html>
<html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Molago — M0, l'essai à l'aveugle</title>
<style>
:root{--ink:#171614;--ink2:#5c574f;--ink3:#8d8579;--paper:#f4f1ea;--paper2:#fbf9f5;--line:#ddd7cb;--orange:#d2601a}
*{box-sizing:border-box}
body{margin:0;background:var(--paper);color:var(--ink);font:17px/1.55 -apple-system,BlinkMacSystemFont,"SF Pro Text",system-ui,sans-serif;-webkit-font-smoothing:antialiased}
.wrap{max-width:760px;margin:0 auto;padding:0 24px 100px}
h1{font-size:40px;line-height:1.1;letter-spacing:-.025em;margin:64px 0 0}
h2{font-size:24px;letter-spacing:-.02em;margin:0}
.eyebrow{font-size:12px;letter-spacing:.16em;text-transform:uppercase;color:var(--orange);font-weight:660;margin-bottom:18px}
.lede{margin-top:18px;color:var(--ink2)}
.src{margin-top:34px;border:1px solid var(--line);border-radius:16px;padding:22px 24px;background:var(--paper2)}
.src .lbl{font-size:11px;font-weight:700;letter-spacing:.12em;text-transform:uppercase;color:var(--ink3)}
.src h3{margin:10px 0 0;font-size:19px;font-weight:640;line-height:1.3}
.src a{font-size:13px;color:var(--ink3)}
.ko{font-size:19px;line-height:1.95;margin:16px 0 0;white-space:pre-wrap;word-break:keep-all}
sec-head{display:block}
.head{margin-top:76px;padding-top:26px;border-top:1px solid var(--line)}
.head p{color:var(--ink2);margin:12px 0 0}
.cand{margin-top:22px;border:1px solid var(--line);border-radius:16px;padding:20px 24px;background:var(--paper2)}
.cand-h{display:flex;align-items:center;justify-content:space-between;gap:16px;flex-wrap:wrap}
.badge{display:grid;place-items:center;width:32px;height:32px;border-radius:999px;background:var(--orange);color:#fff;font-weight:700;font-size:15px}
.rank{font-size:12px;color:var(--ink3);display:flex;align-items:center;gap:9px}
.rank label{display:flex;align-items:center;gap:3px;cursor:pointer}
audio{width:100%;margin-top:16px}
.reveal{margin-top:16px;padding-top:14px;border-top:1px dashed var(--line);font-size:14px;font-weight:640;color:var(--orange)}
.bar{position:fixed;left:0;right:0;bottom:0;padding:14px 24px;background:var(--paper2);border-top:1px solid var(--line);display:flex;justify-content:center}
button{font:inherit;font-weight:640;font-size:15px;padding:11px 26px;border-radius:999px;border:0;background:var(--orange);color:#fff;cursor:pointer}
button:hover{background:#a8460f}
.note{margin-top:16px;font-size:14px;color:var(--ink3)}
</style></head><body><div class="wrap">

<div style="padding-top:64px"><div class="eyebrow">Molago · M0 · spec §14</div></div>
<h1>Est-ce que ce coréen sonne juste ?</h1>
<p class="lede">Lis les ${texts.length} textes, écoute les ${clips.length} voix, note-les. Ne révèle qu'à la fin —
la réponse change tout : elle décide du générateur, de la voix, et si un vérificateur coréen natif
est nécessaire du tout.</p>

<div class="src">
  <div class="lbl">La référence — écrit par un humain</div>
  <h3>${esc(article.title)}</h3>
  <a href="${esc(article.url)}" target="_blank" rel="noopener">${esc(article.url)}</a>
  <p class="ko">${esc(reference)}</p>
  <p class="note">C'est l'article source, tel quel. Il est en registre journalistique complet —
  plus dur que ce qu'on vise. Il sert d'étalon de naturalité, pas de niveau.</p>
</div>

<div class="head"><h2>Les textes</h2>
<p>Le même article, réécrit en ~300 mots pour un niveau intermédiaire-avancé.
Ordre mélangé. Note chacun de 1 (sonne traduit) à 5 (un Coréen a écrit ça).</p></div>
${textCards}

<div class="head"><h2>Les voix</h2>
<p>Toutes lisent <b>le même paragraphe de l'article original</b> — donc tu juges la voix seule,
pas la qualité de la rédaction.</p>
<p class="ko" style="font-size:17px">${esc(voiceParagraph)}</p></div>
${clipCards}

<div class="bar"><button id="go">Révéler qui est qui</button></div>
<script>
document.getElementById('go').addEventListener('click', () => {
  document.querySelectorAll('.reveal').forEach(e => e.hidden = false)
  document.getElementById('go').textContent = 'Révélé'
  document.getElementById('go').disabled = true
})
</script>
</div></body></html>`
}

// ── main ─────────────────────────────────────────────────────────────────────

const t0 = Date.now()
log('\nM0 — essai comparatif à l\'aveugle\n')

if (!has('OPENROUTER_API_KEY')) {
  console.error('✕ OPENROUTER_API_KEY manquante dans .env — sans elle il n\'y a rien à comparer.')
  process.exit(1)
}
const voiceProviders = VOICES.filter((v) => has(v.key))
log('clés trouvées :', ['OPENROUTER', ...voiceProviders.map((v) => v.label)].join(', '))
if (voiceProviders.length < 2) {
  log(`⚠ ${voiceProviders.length} fournisseur(s) de voix seulement — la comparaison sera maigre.`)
}

const article = await pickArticle()
const body = article.paras.join('\n\n')
log(`· article : « ${article.title} » (${body.length} car., ${article.paras.length} §)`)

const models = await availableModels()
if (!models.length) { console.error('✕ aucun modèle candidat disponible sur OpenRouter.'); process.exit(1) }
log(`· modèles : ${models.join(', ')}`)

const texts = []
let cost = 0
for (const m of models) {
  process.stdout.write(`  → ${m} `)
  try {
    const { text, titled, cost: c } = await generate(m, article.title, body)
    texts.push({ model: m, text, titled })
    if (c) cost += c
    log(`✓ ${text.length} car.`)
  } catch (e) { log(`✕ ${e.message}`) }
}
if (!texts.length) { console.error('✕ aucune génération n\'a abouti.'); process.exit(1) }

// La voix lit un paragraphe authentique, pas un texte généré.
const voiceParagraph = article.paras.find((p) => p.length > 90 && p.length < 260) || article.paras[0]
mkdirSync(join(OUT, 'audio'), { recursive: true })

const clips = []
for (const v of voiceProviders) {
  process.stdout.write(`  ♪ ${v.label} `)
  try {
    const { buf, detail, ext } = await v.fn(voiceParagraph)
    const file = `${v.id}.${ext || 'mp3'}`
    writeFileSync(join(OUT, 'audio', file), buf)
    clips.push({ label: v.label, detail, file })
    log(`✓ ${(buf.length / 1024).toFixed(0)} Ko`)
  } catch (e) { log(`✕ ${e.message}`) }
}

const seed = Date.now() & 0x7fffffff
const shuffledTexts = shuffle(texts, seed)
const shuffledClips = shuffle(clips, seed + 7)

// Tout ce qui a coûté un appel est conservé : judge.mjs relit ce fichier et
// réécrit la page sans jamais régénérer.
writeFileSync(join(OUT, 'run.json'), JSON.stringify({
  generatedAt: new Date().toISOString(),
  article: { title: article.title, url: article.url, paras: article.paras },
  voiceParagraph,
  texts: shuffledTexts.map((t, i) => ({
    label: String.fromCharCode(65 + i), model: t.model, titled: !!t.titled, text: t.text,
  })),
  clips: shuffledClips,
}, null, 2))

writeFileSync(join(OUT, 'index.html'), page({
  article,
  reference: article.paras.slice(0, 3).join('\n\n'),
  texts: shuffledTexts,
  clips: shuffledClips,
  voiceParagraph,
}))
writeFileSync(join(OUT, 'key.json'), JSON.stringify({
  generatedAt: new Date().toISOString(),
  article: { title: article.title, url: article.url },
  texts: shuffledTexts.map((t, i) => ({
    label: String.fromCharCode(65 + i),
    model: t.model,
    ...(t.titled ? { ecartConsigne: 'a ajouté un titre malgré la consigne — retiré pour l\'aveugle' } : {}),
  })),
  voices: shuffledClips.map((c, i) => ({ label: String(i + 1), provider: c.label, detail: c.detail })),
}, null, 2))

log(`\n✓ ${texts.length} textes · ${clips.length} voix · ${((Date.now() - t0) / 1000).toFixed(0)} s${cost ? ` · ~$${cost.toFixed(3)}` : ''}`)
log(`\n  open docs/m0/index.html\n`)
