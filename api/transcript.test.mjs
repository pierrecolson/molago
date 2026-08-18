import test from 'node:test'
import assert from 'node:assert/strict'

import { fetchTranscript, parseYouTubeURL, secondsFromISO } from './transcript.mjs'

const SUPADATA = {
  lang: 'ko',
  content: [
    { text: '마일리지 전환은 어떻게?', offset: 18800, duration: 1000, lang: 'ko' },
    { text: '', offset: 20000, duration: 500, lang: 'ko' },
  ],
}

const METADATA = {
  items: [{
    snippet: {
      title: '대한항공-아시아나 합병',
      channelTitle: '14F 일사에프',
      thumbnails: { high: { url: 'https://i.ytimg.com/vi/zC4aRaHI-yw/hqdefault.jpg' } },
    },
    contentDetails: { duration: 'PT4M13S' },
  }],
}

/// Un `fetch` de test : chaque hôte répond ce que le cas veut, et rien ne sort.
const stub = (replies) => async (url) => {
  const key = new URL(url).hostname.includes('supadata') ? 'captions' : 'metadata'
  const reply = replies[key]
  if (typeof reply === 'function') return reply()
  return { ok: true, status: 200, json: async () => reply }
}

test('accepts only YouTube video URLs', () => {
  assert.equal(parseYouTubeURL('https://youtu.be/42M_DVvzye8').hostname, 'youtu.be')
  assert.equal(parseYouTubeURL('https://www.youtube.com/watch?v=42M_DVvzye8').hostname, 'www.youtube.com')
  assert.equal(parseYouTubeURL('https://www.youtube.com/shorts/42M_DVvzye8').pathname, '/shorts/42M_DVvzye8')
  assert.throws(() => parseYouTubeURL('https://example.com/watch?v=42M_DVvzye8'), /YouTube/)
  assert.throws(() => parseYouTubeURL('https://www.youtube.com/@channel'), /channel/)
  assert.throws(() => parseYouTubeURL('not a link'), /YouTube/)
})

test('reads an ISO 8601 duration in seconds', () => {
  assert.equal(secondsFromISO('PT4M13S'), 253)
  assert.equal(secondsFromISO('PT1H2M3S'), 3723)
  assert.equal(secondsFromISO('PT45S'), 45)
  assert.equal(secondsFromISO(undefined), 0)
})

test('maps milliseconds to seconds and keeps the metadata', async () => {
  const video = await fetchTranscript('https://youtu.be/zC4aRaHI-yw', {
    fetch: stub({ captions: SUPADATA, metadata: METADATA }),
  })

  assert.equal(video.videoID, 'zC4aRaHI-yw')
  assert.equal(video.title, '대한항공-아시아나 합병')
  assert.equal(video.channel, '14F 일사에프')
  assert.equal(video.duration, 253)
  assert.equal(video.thumbnail, 'https://i.ytimg.com/vi/zC4aRaHI-yw/hqdefault.jpg')
  assert.equal(video.sourceURL, 'https://www.youtube.com/watch?v=zC4aRaHI-yw')
  assert.deepEqual(video.cues, [{ start: 18.8, end: 19.8, ko: '마일리지 전환은 어떻게?' }])
})

test('a video without Korean captions is still a video', async () => {
  const video = await fetchTranscript('https://www.youtube.com/watch?v=zC4aRaHI-yw', {
    fetch: stub({ captions: { lang: 'ko', content: [] }, metadata: METADATA }),
  })

  assert.deepEqual(video.cues, [])
  assert.equal(video.duration, 253)
})

test('missing metadata never loses a transcript', async () => {
  const video = await fetchTranscript('https://youtu.be/zC4aRaHI-yw', {
    fetch: stub({
      captions: SUPADATA,
      metadata: () => { throw new Error('googleapis unreachable') },
    }),
  })

  assert.equal(video.title, 'YouTube video')
  assert.equal(video.channel, 'YouTube')
  assert.equal(video.duration, 20)
  assert.equal(video.thumbnail, 'https://i.ytimg.com/vi/zC4aRaHI-yw/hqdefault.jpg')
  assert.equal(video.cues.length, 1)
})

test('decodes the HTML entities YouTube encodes twice', async () => {
  const video = await fetchTranscript('https://youtu.be/zC4aRaHI-yw', {
    fetch: stub({
      captions: {
        content: [{ text: '&amp;#39;안녕&amp;#39; &amp; 여러분', offset: 0, duration: 1000 }],
      },
      metadata: METADATA,
    }),
  })

  assert.equal(video.cues[0].ko, "'안녕' & 여러분")
})

test('a track labelled Korean but returned in English is no transcript', async () => {
  const video = await fetchTranscript('https://youtu.be/dQw4w9WgXcQ', {
    fetch: stub({
      captions: {
        lang: 'ko',
        content: [{ text: 'We&amp;#39;re no strangers to love', offset: 18800, duration: 7160 }],
      },
      metadata: METADATA,
    }),
  })

  assert.deepEqual(video.cues, [])
})

test('a provider failure carries neither key nor raw body', async () => {
  const failing = fetchTranscript('https://youtu.be/zC4aRaHI-yw', {
    fetch: stub({
      captions: () => ({
        ok: false,
        status: 402,
        json: async () => ({ error: 'quota exceeded for key sd_live_secret' }),
      }),
      metadata: METADATA,
    }),
  })

  const error = await failing.then(() => null, (e) => e)
  assert.equal(error.statusCode, 503)
  assert.doesNotMatch(error.message, /sd_live_secret|402|quota/)
})

test('a bad link never reaches the provider', async () => {
  await assert.rejects(
    fetchTranscript('https://example.com/watch?v=zC4aRaHI-yw', {
      fetch: () => { throw new Error('the network was touched') },
    }),
    /YouTube/,
  )
})
