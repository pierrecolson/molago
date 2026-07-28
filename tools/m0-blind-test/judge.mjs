#!/usr/bin/env node
// M0, second temps — traduire et faire juger.
//
// La page d'origine demandait à Pierre de noter la naturalité du coréen. Il ne
// peut pas : c'est précisément ce que le produit doit lui apporter. On répartit
// donc les questions selon qui peut y répondre :
//
//   · le niveau et l'intérêt  → Pierre, avec la traduction anglaise sous chaque phrase
//   · la naturalité           → des modèles coréens natifs, en aveugle
//
// Relit docs/m0/run.json (écrit par run.mjs), n'appelle rien à nouveau côté
// génération, et réécrit docs/m0/index.html.
//
//   node tools/m0-blind-test/judge.mjs

import { readFileSync, writeFileSync, existsSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..')
const OUT = join(ROOT, 'docs', 'm0')

// Deux juges, deux maisons. Solar est aussi candidat : un modèle qui se note
// lui-même est un biais connu, donc on regarde surtout où les deux s'accordent.
const JUDGES = [
  { id: 'upstage/solar-pro-3', label: 'Solar Pro 3 (coréen natif)', selfInterest: true },
  { id: 'google/gemini-3.1-pro-preview', label: 'Gemini 3.1 Pro', selfInterest: true },
  // Ne figure pas parmi les candidats : aucun intérêt propre, donc c'est lui
  // qui départage quand les deux autres se contredisent.
  { id: 'qwen/qwen3-max', label: 'Qwen3 Max (neutre)', selfInterest: false },
]
const TRANSLATOR = 'anthropic/claude-opus-4.5'
// Un juge interrogé deux fois sur les mêmes textes ne rend pas le même verdict :
// mesuré sur ce corpus, Solar a noté un texte 4/10 puis 9/10. Un seul appel est
// du bruit, pas une mesure. On répète et on moyenne.
const PASSES = 3

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

const log = (...a) => console.log(...a)
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')

async function ask(model, prompt, { json = false } = {}) {
  const r = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      authorization: `Bearer ${env.OPENROUTER_API_KEY}`,
      'content-type': 'application/json',
      'x-title': 'Molago M0 judge',
    },
    body: JSON.stringify({
      model,
      messages: [{ role: 'user', content: prompt }],
      max_tokens: 12000,
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

// ── traduction alignée phrase par phrase ─────────────────────────────────────

const TRANSLATE = (ko) => `Voici un texte coréen. Découpe-le en phrases et donne la traduction anglaise de chacune.

TEXTE
${ko}

Réponds en JSON strict, sans commentaire :
{"sentences":[{"ko":"la phrase coréenne exacte, inchangée","en":"its English translation"}]}

Règles :
- Reprends les phrases coréennes mot pour mot, sans les modifier ni les corriger.
- Traduis en anglais naturel et fidèle. N'embellis pas : si le coréen est maladroit, l'anglais doit le laisser voir.
- Ne saute aucune phrase.`

// ── jugement de naturalité ───────────────────────────────────────────────────

const JUDGE = (texts) => `당신은 한국어 원어민 편집자입니다. 아래 ${texts.length}개의 글은 같은 기사를 각각 다시 쓴 것입니다.

${texts.map((t) => `### ${t.label}\n${t.text}`).join('\n\n')}

각 글을 "한국인이 직접 쓴 글처럼 읽히는가"를 기준으로만 평가하세요. 사실 정확성이나 길이는 보지 마세요.

특히 다음을 찾아내세요:
- 번역투 (영어나 일본어 문장 구조를 그대로 옮긴 듯한 표현)
- 어색한 연어(collocation) — 한국인이라면 쓰지 않을 단어 조합
- 문체나 격식의 불일치
- 지나치게 딱딱하거나 어색하게 격식을 차린 표현

반드시 아래 JSON 형식으로만 답하세요:
{"ranking":[{"label":"A","rank":1,"score":8,"verdict":"한 문장 평가 (한국어)","issues":[{"quote":"어색한 부분을 글에서 그대로 인용","why":"왜 어색한지 (한국어)"}]}]}

- rank: 1이 가장 자연스러움
- score: 1(번역기 같음) ~ 10(한국인이 씀)
- issues: 글마다 0~3개. 정말 어색한 것만.`

// ── page ─────────────────────────────────────────────────────────────────────

function page(d) {
  const scoreOf = (label, jid) =>
    d.judgments[jid]?.ranking?.find((r) => r.label === label)

  const cards = d.texts.map((t) => {
    const lines = (t.sentences || []).map((s) => `
      <div class="sent"><p class="ko">${esc(s.ko)}</p><p class="en">${esc(s.en)}</p></div>`).join('')

    const verdicts = JUDGES.map((j) => {
      const v = scoreOf(t.label, j.id)
      if (!v) return ''
      const issues = (v.issues || []).map((i) =>
        `<li><b>${esc(i.quote)}</b> — ${esc(i.why)}</li>`).join('')
      return `<div class="jv"><span class="jn">${esc(j.label)}</span>
        <span class="js">${v.score}/10 · rang ${v.rank}</span>
        <p>${esc(v.verdict || '')}</p>${issues ? `<ul>${issues}</ul>` : ''}</div>`
    }).join('')

    return `
    <section class="cand" id="t-${t.label}">
      <div class="cand-h">
        <span class="badge">${t.label}</span>
        <span class="asks">
          <label class="ask"><input type="checkbox"> Lu sans m'arrêter</label>
          <label class="ask"><input type="checkbox"> Je l'aurais lu en français</label>
        </span>
      </div>
      <div class="sents">${lines || `<p class="ko">${esc(t.text)}</p>`}</div>
      <div class="reveal" hidden>
        <div class="model">${esc(t.model)}</div>
        ${verdicts}
      </div>
    </section>`
  }).join('')

  // Tableau de synthèse des juges, caché jusqu'à la révélation.
  const rows = d.texts.map((t) => {
    const cells = JUDGES.map((j) => {
      const v = scoreOf(t.label, j.id)
      return `<td>${v ? `${v.score}<span class="sm">/10</span>` : '—'}</td>`
    }).join('')
    const scores = JUDGES.map((j) => scoreOf(t.label, j.id)?.score).filter((n) => typeof n === 'number')
    const avg = scores.length ? (scores.reduce((a, b) => a + b, 0) / scores.length).toFixed(1) : '—'
    return `<tr><td><b>${t.label}</b></td><td class="mdl">${esc(t.model)}</td>${cells}<td><b>${avg}</b></td></tr>`
  }).join('')

  return `<!doctype html>
<html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Molago — M0, l'essai à l'aveugle</title>
<style>
:root{--ink:#171614;--ink2:#5c574f;--ink3:#8d8579;--paper:#f4f1ea;--paper2:#fbf9f5;--line:#ddd7cb;--orange:#d2601a;--green:#3f6b4a}
*{box-sizing:border-box}
body{margin:0;background:var(--paper);color:var(--ink);font:17px/1.55 -apple-system,BlinkMacSystemFont,"SF Pro Text",system-ui,sans-serif;-webkit-font-smoothing:antialiased}
.wrap{max-width:800px;margin:0 auto;padding:0 24px 110px}
h1{font-size:40px;line-height:1.08;letter-spacing:-.025em;margin:0}
h2{font-size:25px;letter-spacing:-.02em;margin:0}
.eyebrow{font-size:12px;letter-spacing:.16em;text-transform:uppercase;color:var(--orange);font-weight:660;margin:64px 0 18px}
.lede{margin-top:20px;color:var(--ink2)}
.split{margin-top:28px;display:grid;grid-template-columns:1fr 1fr;gap:16px}
@media(max-width:680px){.split{grid-template-columns:1fr}}
.box{border:1px solid var(--line);border-radius:16px;padding:20px 22px;background:var(--paper2)}
.box h3{margin:0 0 10px;font-size:16px;font-weight:660}
.box p{margin:0;font-size:15px;color:var(--ink2)}
.box.you{border-color:color-mix(in srgb,var(--orange) 50%,var(--line))}
.box.you h3{color:var(--orange)}
.box.them{border-color:color-mix(in srgb,var(--green) 45%,var(--line))}
.box.them h3{color:var(--green)}
.src{margin-top:30px;border:1px solid var(--line);border-radius:16px;padding:20px 22px;background:var(--paper2)}
.src .lbl{font-size:11px;font-weight:700;letter-spacing:.12em;text-transform:uppercase;color:var(--ink3)}
.src h3{margin:9px 0 0;font-size:18px;font-weight:640;line-height:1.3}
.src a{font-size:13px;color:var(--ink3)}
.head{margin-top:72px;padding-top:24px;border-top:1px solid var(--line)}
.head p{color:var(--ink2);margin:12px 0 0}
.cand{margin-top:20px;border:1px solid var(--line);border-radius:16px;padding:18px 22px;background:var(--paper2)}
.cand-h{display:flex;align-items:center;justify-content:space-between;gap:14px;flex-wrap:wrap;margin-bottom:6px}
.badge{display:grid;place-items:center;width:32px;height:32px;border-radius:999px;background:var(--orange);color:#fff;font-weight:700;font-size:15px}
.asks{display:flex;gap:16px;flex-wrap:wrap}
.ask{font-size:13px;color:var(--ink2);display:flex;align-items:center;gap:6px;cursor:pointer}
.sent{padding:11px 0;border-bottom:1px solid color-mix(in srgb,var(--line) 60%,transparent)}
.sent:last-child{border-bottom:0}
.ko{margin:0;font-size:19px;line-height:1.75;word-break:keep-all}
.en{margin:5px 0 0;font-size:14px;line-height:1.5;color:var(--ink3)}
.reveal{margin-top:14px;padding-top:14px;border-top:1px dashed var(--line)}
.model{font-size:14px;font-weight:660;color:var(--orange)}
.jv{margin-top:12px;padding-left:12px;border-left:2px solid var(--line)}
.jn{font-size:12px;font-weight:700;letter-spacing:.06em;text-transform:uppercase;color:var(--ink3)}
.js{font-size:12px;font-weight:700;color:var(--green);margin-left:8px}
.jv p{margin:5px 0 0;font-size:14px;color:var(--ink2)}
.jv ul{margin:7px 0 0;padding-left:18px;font-size:13.5px;color:var(--ink2)}
.jv li{margin-bottom:4px}
.jv li b{color:var(--ink)}
table{width:100%;border-collapse:collapse;margin-top:16px;font-size:14px}
th,td{text-align:left;padding:9px 10px;border-bottom:1px solid var(--line)}
th{font-size:11px;letter-spacing:.08em;text-transform:uppercase;color:var(--ink3);font-weight:700}
td.mdl{color:var(--ink2);font-size:13px}
.sm{font-size:11px;color:var(--ink3)}
audio{width:100%;margin-top:10px}
.done{display:inline-block;font-size:11px;font-weight:700;letter-spacing:.08em;text-transform:uppercase;color:#fff;background:var(--green);padding:4px 10px;border-radius:999px}
.bar{position:fixed;left:0;right:0;bottom:0;padding:14px 24px;background:var(--paper2);border-top:1px solid var(--line);display:flex;justify-content:center}
button{font:inherit;font-weight:640;font-size:15px;padding:11px 26px;border-radius:999px;border:0;background:var(--orange);color:#fff;cursor:pointer}
button:disabled{background:var(--ink3);cursor:default}
</style></head><body><div class="wrap">

<div class="eyebrow">Molago · M0 · spec §14</div>
<h1>Deux questions,<br>deux juges différents.</h1>
<p class="lede">La spec supposait que tu pouvais juger si le coréen sonne juste. Tu ne peux pas —
c'est exactement ce que le produit doit t'apporter. On répartit donc les questions selon qui
peut y répondre.</p>

<div class="split">
  <div class="box you"><h3>Ce que tu juges</h3>
    <p><b>Le niveau</b> — arrives-tu au bout sans t'arrêter ? La traduction anglaise est sous
    chaque phrase : lis le coréen d'abord, l'anglais seulement quand tu bloques.<br><br>
    <b>L'intérêt</b> — l'aurais-tu lu si c'était en français ? C'est le test de validation du produit.</p></div>
  <div class="box them"><h3>Ce que les modèles jugent</h3>
    <p><b>La naturalité</b> — « un Coréen dirait-il ça ? ». Deux juges de maisons différentes ont
    classé les cinq textes à l'aveugle et cité ce qui sonne faux. Leur verdict apparaît à la
    révélation, pour ne pas influencer ta lecture.</p></div>
</div>

<div class="src">
  <div class="lbl">L'article source — écrit par un humain</div>
  <h3>${esc(d.article.title)}</h3>
  <a href="${esc(d.article.url)}" target="_blank" rel="noopener">${esc(d.article.url)}</a>
  <p style="margin:12px 0 0;font-size:14px;color:var(--ink3)">Registre journalistique complet, plus dur
  que ce qu'on vise — normal que tu ne le lises pas. Il est là pour situer d'où partent les modèles.</p>
</div>

<div class="head"><h2>Les cinq textes</h2>
<p>Le même article, réécrit pour un niveau intermédiaire-avancé. Ordre mélangé.
Coche ce qui est vrai pour chacun.</p></div>
${cards}

<div class="head"><h2>La voix</h2>
<p><span class="done">Tranché</span> &nbsp;Google Chirp3-HD — meilleur à ton oreille, et
<b>0 $/mois</b> : Molago consomme ~93 000 caractères/mois, le palier gratuit est à 1 million.
ElevenLabs coûterait 22 $/mois pour un résultat que tu as jugé moins bon.</p>
${(d.clips || []).map((c) => `<div class="cand"><div class="cand-h"><span class="badge">${esc(c.label[0])}</span>
  <span style="font-size:13px;color:var(--ink3)">${esc(c.label)} — ${esc(c.detail)}</span></div>
  <audio controls preload="none" src="audio/${esc(c.file)}"></audio></div>`).join('')}

<div class="reveal" hidden id="summary">
  <div class="head"><h2>Le verdict des juges</h2>
  <p>Score de naturalité, 1 (sonne traduit) à 10 (un Coréen a écrit ça).</p></div>
  <table><thead><tr><th></th><th>Modèle</th>${JUDGES.map((j) => `<th>${esc(j.label.split(' (')[0])}</th>`).join('')}<th>Moyenne</th></tr></thead>
  <tbody>${rows}</tbody></table>
  <p style="margin-top:14px;font-size:13.5px;color:var(--ink3)">Biais à garder en tête : les deux juges
  figurent aussi parmi les cinq candidats. Ce qui compte est donc là où les deux s'accordent, pas
  la note qu'un modèle se donne à lui-même.</p>
</div>

<div class="bar"><button id="go">Révéler qui est qui, et l'avis des juges</button></div>
<script>
document.getElementById('go').addEventListener('click', (e) => {
  document.querySelectorAll('.reveal').forEach(n => n.hidden = false)
  e.target.textContent = 'Révélé'; e.target.disabled = true
})
</script>
</div></body></html>`
}

// ── main ─────────────────────────────────────────────────────────────────────

const runPath = join(OUT, 'run.json')
if (!existsSync(runPath)) {
  console.error(`✕ ${runPath} absent — lance d'abord : node tools/m0-blind-test/run.mjs`)
  process.exit(1)
}
const d = JSON.parse(readFileSync(runPath, 'utf8'))
log(`\nM0 — traduction et jugement\n· ${d.texts.length} textes · « ${d.article.title} »\n`)

for (const t of d.texts) {
  // Les traductions sont conservées dans run.json : on ne les repaie pas à
  // chaque fois qu'on ajoute un juge ou qu'on retouche la page.
  if (t.sentences?.length) { log(`  ⇄ traduction ${t.label} · déjà faite`); continue }
  process.stdout.write(`  ⇄ traduction ${t.label} `)
  try {
    const j = await ask(TRANSLATOR, TRANSLATE(t.text), { json: true })
    t.sentences = (j.sentences || []).filter((s) => s?.ko && s?.en)
    log(`✓ ${t.sentences.length} phrases`)
  } catch (e) { log(`✕ ${e.message.slice(0, 60)}`) }
}

d.judgments = {}
for (const j of JUDGES) {
  const runs = []
  process.stdout.write(`  ⚖ ${j.label} `)
  for (let p = 0; p < PASSES; p++) {
    try {
      const r = await ask(j.id, JUDGE(d.texts), { json: true })
      if (r?.ranking?.length) { runs.push(r); process.stdout.write('·') }
    } catch { process.stdout.write('✕') }
  }
  // Moyenne par texte, plus l'écart entre le meilleur et le pire passage :
  // un écart large veut dire que ce juge ne mesure rien de stable.
  const merged = d.texts.map((t) => {
    const got = runs.map((r) => r.ranking.find((x) => x.label === t.label)).filter(Boolean)
    const scores = got.map((g) => Number(g.score)).filter(Number.isFinite)
    const mean = scores.length ? scores.reduce((a, b) => a + b, 0) / scores.length : null
    return {
      label: t.label,
      score: mean === null ? null : Math.round(mean * 10) / 10,
      spread: scores.length > 1 ? Math.max(...scores) - Math.min(...scores) : 0,
      passes: scores.length,
      verdict: got[0]?.verdict || '',
      issues: got.flatMap((g) => g.issues || []).slice(0, 3),
    }
  })
  merged.sort((a, b) => (b.score ?? -1) - (a.score ?? -1)).forEach((m, i) => { m.rank = i + 1 })
  d.judgments[j.id] = { ranking: merged, passes: runs.length }
  const sp = Math.max(...merged.map((m) => m.spread))
  log(` ✓ ${runs.length}/${PASSES} passages · dispersion max ${sp} pts`)
}

writeFileSync(runPath, JSON.stringify(d, null, 2))
writeFileSync(join(OUT, 'index.html'), page(d))
log(`\n✓ page réécrite\n\n  open docs/m0/index.html\n`)
