import test from 'node:test'
import assert from 'node:assert/strict'
import { writeFile } from 'node:fs/promises'
import { dirname, join } from 'node:path'

import { alignEnglish, extractYouTube, parseVTT, parseYouTubeURL } from './youtube.mjs'

test('accepts only YouTube video URLs', () => {
  assert.equal(parseYouTubeURL('https://youtu.be/42M_DVvzye8').hostname, 'youtu.be')
  assert.equal(parseYouTubeURL('https://www.youtube.com/watch?v=42M_DVvzye8').hostname, 'www.youtube.com')
  assert.throws(() => parseYouTubeURL('https://example.com/watch?v=42M_DVvzye8'), /YouTube/)
  assert.throws(() => parseYouTubeURL('not a link'), /YouTube/)
})

test('parses timed WebVTT cues and removes markup', () => {
  const source = `WEBVTT

00:00:06.214 --> 00:00:10.301 align:start position:0%
<c.colorCCCCCC>안녕하세요</c>

00:00:10.301 --> 00:00:12.000
여러분 &amp; 반가워요
`

  assert.deepEqual(parseVTT(source), [
    { start: 6.214, end: 10.301, text: '안녕하세요' },
    { start: 10.301, end: 12, text: '여러분 & 반가워요' },
  ])
})

test('aligns English captions by overlap instead of exact timestamps', () => {
  const korean = [
    { start: 6, end: 10, text: '안녕하세요' },
    { start: 10, end: 14, text: '반가워요' },
  ]
  const english = [
    { start: 6.1, end: 9.9, text: 'Hello' },
    { start: 10.2, end: 13.8, text: 'Nice to meet you' },
  ]

  assert.deepEqual(alignEnglish(korean, english), [
    { start: 6, end: 10, ko: '안녕하세요', en: 'Hello' },
    { start: 10, end: 14, ko: '반가워요', en: 'Nice to meet you' },
  ])
})

test('removes the duplicated Korean line from YouTube auto-translated captions', () => {
  const korean = [{ start: 6, end: 10, text: '안녕하세요' }]
  const english = [{ start: 6, end: 10, text: '안녕하세요 Hello and welcome.' }]

  assert.equal(alignEnglish(korean, english)[0].en, 'Hello and welcome.')
})

test('keeps Korean captions when the optional English download fails', async () => {
  const video = await extractYouTube('https://youtu.be/zC4aRaHI-yw', {
    execute: async (_command, args) => {
      if (!args.includes('--ignore-errors')) throw new Error('English captions returned HTTP 429')
      const directory = dirname(args[args.indexOf('--output') + 1])
      await writeFile(join(directory, 'zC4aRaHI-yw.ko.vtt'), `WEBVTT

00:00:01.000 --> 00:00:03.000
마일리지 전환은 어떻게?
`)
      return { stdout: JSON.stringify({
        id: 'zC4aRaHI-yw',
        title: '대한항공-아시아나 합병',
        channel: '14F',
        duration: 138,
        webpage_url: 'https://www.youtube.com/watch?v=zC4aRaHI-yw',
      }) }
    },
    translate: async (sentences) => sentences.map(() => 'How will mileage transfer?'),
  })

  assert.deepEqual(video.cues, [{
    start: 1,
    end: 3,
    ko: '마일리지 전환은 어떻게?',
    en: 'How will mileage transfer?',
  }])
})
