import { execFile } from 'node:child_process'
import { mkdtemp, readdir, readFile, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { promisify } from 'node:util'

const run = promisify(execFile)
const YOUTUBE_HOSTS = new Set([
  'youtube.com',
  'www.youtube.com',
  'm.youtube.com',
  'music.youtube.com',
  'youtu.be',
])

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

const inputError = (message = 'Enter a valid YouTube link.') =>
  Object.assign(new Error(message), { statusCode: 400 })

const seconds = (stamp) => {
  const parts = stamp.replace(',', '.').split(':').map(Number)
  if (parts.length === 2) return parts[0] * 60 + parts[1]
  return parts[0] * 3600 + parts[1] * 60 + parts[2]
}

const plainText = (value) => value
  .replace(/<[^>]*>/g, '')
  .replace(/&nbsp;/g, ' ')
  .replace(/&amp;/g, '&')
  .replace(/&lt;/g, '<')
  .replace(/&gt;/g, '>')
  .replace(/&quot;/g, '"')
  .replace(/&#39;/g, "'")
  .replace(/\s+/g, ' ')
  .trim()

export function parseVTT(source) {
  const cues = []
  for (const block of String(source).replace(/\r/g, '').split(/\n{2,}/)) {
    const lines = block.split('\n')
    const timing = lines.findIndex((line) => line.includes('-->'))
    if (timing < 0) continue
    const match = lines[timing].match(/((?:\d{2}:)?\d{2}:\d{2}[.,]\d{3})\s+-->\s+((?:\d{2}:)?\d{2}:\d{2}[.,]\d{3})/)
    if (!match) continue
    const text = plainText(lines.slice(timing + 1).join(' '))
    if (!text) continue
    const cue = { start: seconds(match[1]), end: seconds(match[2]), text }
    const previous = cues.at(-1)
    if (previous?.text === cue.text && cue.start <= previous.end + 0.05) previous.end = Math.max(previous.end, cue.end)
    else cues.push(cue)
  }
  return cues
}

export function alignEnglish(korean, english) {
  return korean.map((cue) => {
    const matches = english.filter((candidate) =>
      Math.min(cue.end, candidate.end) - Math.max(cue.start, candidate.start) > 0)
    const seen = new Set()
    const en = matches.map((match) => match.text
      .split(/\s+/).filter((token) => !/[가-힣]/.test(token)).join(' ').trim())
      .filter(Boolean).filter((text) => {
      if (seen.has(text)) return false
      seen.add(text)
      return true
    }).join(' ')
    return { start: cue.start, end: cue.end, ko: cue.text, en }
  })
}

const captionFile = (files, language) => files.find((file) =>
  new RegExp(`\\.${language}(?:[-_.][A-Za-z]+)?\\.vtt$`, 'i').test(file))

export async function extractYouTube(value, options = {}) {
  const url = parseYouTubeURL(value)
  const directory = await mkdtemp(join(tmpdir(), 'molago-youtube-'))
  const execute = options.execute || run
  try {
    const { stdout } = await execute('yt-dlp', [
      '--no-playlist',
      '--skip-download',
      '--no-simulate',
      '--dump-single-json',
      '--write-subs',
      '--write-auto-subs',
      '--sub-langs', 'ko,en',
      '--sub-format', 'vtt',
      '--output', join(directory, '%(id)s.%(ext)s'),
      url.href,
    ], { maxBuffer: 20 * 1024 * 1024 })

    const metadata = JSON.parse(stdout.trim().split('\n').at(-1))
    const files = await readdir(directory)
    const koFile = captionFile(files, 'ko')
    const enFile = captionFile(files, 'en')
    const korean = koFile ? parseVTT(await readFile(join(directory, koFile), 'utf8')) : []
    const english = enFile ? parseVTT(await readFile(join(directory, enFile), 'utf8')) : []
    let cues = alignEnglish(korean, english)

    if (korean.length && !english.length && options.translate) {
      const translated = await options.translate(korean.map((cue) => cue.text))
      cues = cues.map((cue, index) => ({ ...cue, en: translated[index] || '' }))
    }
    if (options.annotate) cues = await options.annotate(cues)

    return {
      videoID: String(metadata.id),
      title: String(metadata.title || 'YouTube video').trim(),
      channel: String(metadata.channel || metadata.uploader || 'YouTube').trim(),
      duration: Math.max(0, Math.round(Number(metadata.duration) || 0)),
      thumbnail: typeof metadata.thumbnail === 'string' ? metadata.thumbnail : null,
      sourceURL: metadata.webpage_url || url.href,
      cues,
    }
  } finally {
    await rm(directory, { recursive: true, force: true })
  }
}
