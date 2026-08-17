import test from 'node:test'
import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { chmodSync, mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs'
import { createServer } from 'node:net'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))

const freePort = () => new Promise((resolve) => {
  const server = createServer().listen(0, '127.0.0.1', () => {
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

test('lists only imports and stores a YouTube video', async (t) => {
  const root = mkdtempSync(join(tmpdir(), 'molago-api-'))
  const data = join(root, 'data')
  const bin = join(root, 'bin')
  const user = 'testuser1'
  mkdirSync(join(data, 'u', user), { recursive: true })
  mkdirSync(bin)

  writeFileSync(join(data, 'u', user, '2026-08-16.json'), JSON.stringify({
    date: '2026-08-16',
    texts: [
      { slot: 'news', title: 'Generated news', sentences: [] },
      { slot: 'capture-old', title: 'My photographed notice', minutes: 2, sentences: [] },
    ],
  }))

  const fake = join(bin, 'yt-dlp')
  writeFileSync(fake, `#!/usr/bin/env node
const fs = require('node:fs')
const path = require('node:path')
const args = process.argv.slice(2)
const output = args[args.indexOf('--output') + 1]
const dir = path.dirname(output)
const vtt = 'WEBVTT\\n\\n00:00:06.000 --> 00:00:10.000\\n안녕하세요\\n'
fs.writeFileSync(path.join(dir, '42M_DVvzye8.ko.vtt'), vtt)
fs.writeFileSync(path.join(dir, '42M_DVvzye8.en.vtt'), vtt.replace('안녕하세요', 'Hello'))
console.log(JSON.stringify({ id: '42M_DVvzye8', title: 'A Korean video', channel: 'Didi', duration: 120, thumbnail: 'https://i.ytimg.com/test.jpg', webpage_url: 'https://youtu.be/42M_DVvzye8' }))
`)
  chmodSync(fake, 0o755)

  const port = await freePort()
  const child = spawn(process.execPath, [join(here, 'server.mjs')], {
    env: {
      ...process.env,
      PORT: String(port),
      DATA_DIR: data,
      MOLAGO_USER_ID: user,
      MOLAGO_TZ: 'Asia/Seoul',
      PATH: `${bin}:${process.env.PATH}`,
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  })
  t.after(() => {
    child.kill('SIGTERM')
    rmSync(root, { recursive: true, force: true })
  })
  const base = `http://127.0.0.1:${port}`
  await waitForServer(base)

  const rejected = await fetch(`${base}/u/${user}/youtube`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ url: 'https://example.com/not-youtube' }),
  })
  assert.equal(rejected.status, 400)
  assert.match((await rejected.json()).error, /YouTube/)

  const before = await fetch(`${base}/u/${user}/library`)
  assert.equal(before.status, 200)
  assert.deepEqual((await before.json()).items.map((item) => item.text.title), ['My photographed notice'])

  const added = await fetch(`${base}/u/${user}/youtube`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ url: 'https://youtu.be/42M_DVvzye8' }),
  })
  assert.equal(added.status, 200)
  assert.equal((await added.json()).slot, 'youtube-42M_DVvzye8')

  const after = await fetch(`${base}/u/${user}/library`)
  const items = (await after.json()).items
  assert.equal(items.length, 2)
  assert.equal(items[0].text.videoID, '42M_DVvzye8')
  assert.equal(items[0].text.sentences[0].ko, '안녕하세요')
  assert.equal(items[0].text.sentences[0].en, 'Hello')
})
