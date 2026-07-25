/**
 * TTS phrase par phrase (OpenAI gpt-4o-mini-tts) → durées exactes via ffprobe →
 * concat ffmpeg en un seul mp3. Les offsets cumulés donnent les timings karaoké
 * sans aucun forced alignment.
 */
import OpenAI from 'openai';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const TTS_MODEL = process.env.MOLAGO_TTS_MODEL ?? 'gpt-4o-mini-tts';
const TTS_VOICE = process.env.MOLAGO_TTS_VOICE ?? 'nova';
const TTS_INSTRUCTIONS =
  'Voix chaleureuse de conteur coréen, rythme naturel de conversation, ' +
  'ni lent ni scolaire. Ton 해요체 amical, comme un podcast du matin.';
const GAP_MS = 80; // respiration entre phrases

let client: OpenAI | null = null;
function openai(): OpenAI {
  if (!client) client = new OpenAI();
  return client;
}

export interface TtsResult {
  mp3: Buffer;
  durationMs: number;
  timings: { startMs: number; endMs: number }[]; // par phrase, offsets dans le mp3 final
}

function probeDurationMs(path: string): number {
  const out = execFileSync('ffprobe', [
    '-v', 'error',
    '-show_entries', 'format=duration',
    '-of', 'default=noprint_wrappers=1:nokey=1',
    path,
  ]).toString().trim();
  return Math.round(parseFloat(out) * 1000);
}

export async function synthesizeEpisode(sentences: string[]): Promise<TtsResult> {
  const dir = mkdtempSync(join(tmpdir(), 'molago-tts-'));
  const paths: string[] = [];
  const durations: number[] = [];

  for (let i = 0; i < sentences.length; i++) {
    const res = await openai().audio.speech.create({
      model: TTS_MODEL,
      voice: TTS_VOICE as 'nova',
      input: sentences[i],
      instructions: TTS_INSTRUCTIONS,
      response_format: 'mp3',
    });
    const path = join(dir, `s${String(i).padStart(3, '0')}.mp3`);
    writeFileSync(path, Buffer.from(await res.arrayBuffer()));
    paths.push(path);
    durations.push(probeDurationMs(path));
  }

  // Silence de GAP_MS entre les phrases (généré une fois, ré-encodé au même format).
  const gapPath = join(dir, 'gap.mp3');
  execFileSync('ffmpeg', [
    '-f', 'lavfi', '-i', 'anullsrc=r=24000:cl=mono',
    '-t', String(GAP_MS / 1000),
    '-q:a', '9', '-acodec', 'libmp3lame', gapPath, '-y',
  ], { stdio: 'pipe' });
  const gapMs = probeDurationMs(gapPath);

  const listPath = join(dir, 'list.txt');
  const listLines: string[] = [];
  paths.forEach((p, i) => {
    listLines.push(`file '${p}'`);
    if (i < paths.length - 1) listLines.push(`file '${gapPath}'`);
  });
  writeFileSync(listPath, listLines.join('\n'));

  const outPath = join(dir, 'episode.mp3');
  execFileSync('ffmpeg', ['-f', 'concat', '-safe', '0', '-i', listPath, '-c', 'copy', outPath, '-y'], {
    stdio: 'pipe',
  });

  const timings: { startMs: number; endMs: number }[] = [];
  let cursor = 0;
  for (let i = 0; i < durations.length; i++) {
    timings.push({ startMs: cursor, endMs: cursor + durations[i] });
    cursor += durations[i] + (i < durations.length - 1 ? gapMs : 0);
  }

  return { mp3: readFileSync(outPath), durationMs: cursor, timings };
}
