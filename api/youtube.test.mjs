import test from 'node:test'
import assert from 'node:assert/strict'

import { alignEnglish, parseVTT, parseYouTubeURL } from './youtube.mjs'

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
