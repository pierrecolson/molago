import test from 'node:test'
import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs'
import { createServer as createTCPServer } from 'node:net'
import { createServer } from 'node:http'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))

const freePort = () => new Promise((resolve) => {
  const server = createTCPServer().listen(0, '127.0.0.1', () => {
    const port = server.address().port
    server.close(() => resolve(port))
  })
})

const waitForServer = async (base) => {
  for (let attempt = 0; attempt < 40; attempt++) {
    try {
      if ((await fetch(`${base}/health`)).ok) return
    } catch {}
    await new Promise((resolve) => setTimeout(resolve, 25))
  }
  throw new Error('server did not start')
}

/// Les deux fournisseurs, joués en local : aucun test n'ouvre de connexion
/// sortante, et `outage` rejoue une panne de Supadata sans attendre la vraie.
const startProviders = async ({ outage = false } = {}) => {
  const port = await freePort()
  const calls = { transcript: 0, llm: 0 }
  const server = createServer((req, res) => {
    const url = new URL(req.url, 'http://localhost')
    if (url.pathname === '/transcript') calls.transcript++
    // Le modèle, joué en local : il rend l'anglais demandé, numéroté comme il
    // faut, en relisant les numéros du prompt.
    if (url.pathname === '/chat/completions') {
      calls.llm++
      let raw = ''
      req.on('data', (c) => { raw += c })
      return req.on('end', () => {
        const prompt = JSON.parse(raw).messages[0].content
        const numbers = [...prompt.matchAll(/^(\d+)\. (.+)$/gm)].map((m) => Number(m[1]))
        res.writeHead(200, { 'content-type': 'application/json' })
        res.end(JSON.stringify({
          choices: [{ message: { content: JSON.stringify({ t: numbers.map((i) => ({ i, e: `line ${i}` })) }) } }],
        }))
      })
    }
    const body = url.pathname === '/transcript'
      ? { lang: 'ko', content: [{ text: '안녕하세요', offset: 6000, duration: 4000, lang: 'ko' }] }
      : { items: [{
        snippet: {
          title: 'A Korean video',
          channelTitle: 'Didi',
          thumbnails: { high: { url: 'https://i.ytimg.com/test.jpg' } },
        },
        contentDetails: { duration: 'PT2M' },
      }] }
    if (outage && url.pathname === '/transcript') {
      res.writeHead(429, { 'content-type': 'application/json' })
      return res.end(JSON.stringify({ error: 'rate limited for key sd_live_secret' }))
    }
    res.writeHead(200, { 'content-type': 'application/json' })
    res.end(JSON.stringify(body))
  })
  await new Promise((resolve) => server.listen(port, '127.0.0.1', resolve))
  return { server, calls, base: `http://127.0.0.1:${port}` }
}

const startAPI = async (t, { data, user, providers }) => {
  const port = await freePort()
  const child = spawn(process.execPath, [join(here, 'server.mjs')], {
    env: {
      ...process.env,
      PORT: String(port),
      DATA_DIR: data,
      MOLAGO_USER_ID: user,
      MOLAGO_TZ: 'Asia/Seoul',
      SUPADATA_URL: `${providers}/transcript`,
      YOUTUBE_API_URL: `${providers}/videos`,
      OPENROUTER_URL: `${providers}/chat/completions`,
      OPENROUTER_API_KEY: 'test',
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  })
  t.after(() => child.kill('SIGTERM'))
  const base = `http://127.0.0.1:${port}`
  await waitForServer(base)
  return base
}

const post = (base, path, body) => fetch(`${base}${path}`, {
  method: 'POST',
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify(body),
})

test('serves a timed transcript and lists only imports', async (t) => {
  const root = mkdtempSync(join(tmpdir(), 'molago-api-'))
  const data = join(root, 'data')
  const user = 'testuser1'
  mkdirSync(join(data, 'u', user), { recursive: true })
  writeFileSync(join(data, 'u', user, '2026-08-16.json'), JSON.stringify({
    date: '2026-08-16',
    texts: [
      { slot: 'news', title: 'Generated news', sentences: [] },
      { slot: 'capture-old', title: 'My photographed notice', minutes: 2, sentences: [] },
    ],
  }))

  const providers = await startProviders()
  t.after(() => {
    providers.server.close()
    rmSync(root, { recursive: true, force: true })
  })
  const base = await startAPI(t, { data, user, providers: providers.base })

  const rejected = await post(base, `/u/${user}/transcript`, { url: 'https://example.com/not-youtube' })
  assert.equal(rejected.status, 400)
  assert.match((await rejected.json()).error, /YouTube/)

  const response = await post(base, `/u/${user}/transcript`, { url: 'https://youtu.be/42M_DVvzye8' })
  assert.equal(response.status, 200)
  const video = await response.json()
  assert.equal(video.videoID, '42M_DVvzye8')
  assert.equal(video.title, 'A Korean video')
  assert.equal(video.channel, 'Didi')
  assert.equal(video.duration, 120)
  assert.deepEqual(video.cues, [{ start: 6, end: 10, ko: '안녕하세요' }])

  // Un crédit Supadata par vidéo, pas par import : la deuxième demande sort du
  // cache disque. C'est ce qui rend un réessai gratuit.
  assert.equal(providers.calls.transcript, 1)
  const again = await post(base, `/u/${user}/transcript`, { url: 'https://www.youtube.com/watch?v=42M_DVvzye8' })
  assert.deepEqual(await again.json(), video)
  assert.equal(providers.calls.transcript, 1)

  // La traduction se demande à part, par tranches, et ne se repaye pas.
  const first = await post(base, `/u/${user}/translation`, { url: 'https://youtu.be/42M_DVvzye8', from: 0, to: 1 })
  assert.equal(first.status, 200)
  assert.deepEqual(await first.json(), { from: 0, to: 1, total: 1, en: ['line 0'] })
  assert.equal(providers.calls.llm, 1)

  const twice = await post(base, `/u/${user}/translation`, { url: 'https://youtu.be/42M_DVvzye8', from: 0, to: 1 })
  assert.deepEqual((await twice.json()).en, ['line 0'])
  assert.equal(providers.calls.llm, 1, 'ce qui est traduit ne se retraduit pas')

  // Le serveur ne garde rien : c'est l'appareil qui range l'import.
  const library = await fetch(`${base}/u/${user}/library`)
  assert.deepEqual((await library.json()).items.map((item) => item.text.title), ['My photographed notice'])

  // L'ancienne route yt-dlp n'existe plus.
  assert.equal((await post(base, `/u/${user}/youtube`, { url: 'https://youtu.be/42M_DVvzye8' })).status, 404)
})

test('a provider outage is a 503, and says nothing of the provider', async (t) => {
  const root = mkdtempSync(join(tmpdir(), 'molago-api-'))
  const data = join(root, 'data')
  const user = 'testuser1'
  mkdirSync(join(data, 'u', user), { recursive: true })

  const providers = await startProviders({ outage: true })
  t.after(() => {
    providers.server.close()
    rmSync(root, { recursive: true, force: true })
  })
  const base = await startAPI(t, { data, user, providers: providers.base })

  const response = await post(base, `/u/${user}/transcript`, { url: 'https://youtu.be/42M_DVvzye8' })
  assert.equal(response.status, 503)
  const { error } = await response.json()
  assert.doesNotMatch(error, /sd_live_secret|429/)
})
