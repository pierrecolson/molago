/**
 * Wrapper Kiwi (analyse morphologique coréenne) via le build WASM officiel `kiwi-nlp`.
 * Les fichiers modèles ne sont pas distribués sur npm : ils sont téléchargés au premier
 * run depuis une release GitHub de Kiwi (KIWI_MODEL_URL) et mis en cache sur disque
 * (KIWI_MODEL_DIR, par défaut .kiwi-model/ — caché par actions/cache en CI).
 */
import { createWriteStream, existsSync, mkdirSync, readdirSync, readFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pipeline as streamPipeline } from 'node:stream/promises';
import { Readable } from 'node:stream';
import { execFileSync } from 'node:child_process';

export interface KiwiToken {
  str: string;       // forme du morphème (lemme pour les morphèmes flexionnels)
  tag: string;       // tag POS Kiwi
  position: number;  // offset caractère dans la phrase
  length: number;
}

export interface Analyzer {
  /** Analyse une phrase et rend les morphèmes dans l'ordre. */
  analyze(text: string): Promise<KiwiToken[]>;
}

const DEFAULT_MODEL_URL =
  'https://github.com/bab2min/Kiwi/releases/download/v0.21.0/kiwi_model_v0.21.0_base.tgz';

async function ensureModelDir(): Promise<string> {
  const dir = resolve(process.env.KIWI_MODEL_DIR ?? '.kiwi-model');
  if (existsSync(dir) && readdirSync(dir).length > 0) return findModelRoot(dir);

  const url = process.env.KIWI_MODEL_URL ?? DEFAULT_MODEL_URL;
  console.log(`[kiwi] téléchargement du modèle : ${url}`);
  mkdirSync(dir, { recursive: true });
  const archive = join(dir, 'model.tgz');
  const res = await fetch(url, { redirect: 'follow' });
  if (!res.ok || !res.body) throw new Error(`[kiwi] téléchargement modèle échoué : HTTP ${res.status}`);
  await streamPipeline(Readable.fromWeb(res.body as import('node:stream/web').ReadableStream), createWriteStream(archive));
  execFileSync('tar', ['-xzf', archive, '-C', dir]);
  return findModelRoot(dir);
}

/** L'archive peut contenir un sous-dossier (ex: ModelGenerator/…) : trouve le dossier
 * contenant les fichiers modèles (repérés par sj.morph / default.dict / *.mdl). */
function findModelRoot(dir: string): string {
  const isModelDir = (d: string) =>
    readdirSync(d).some((f) => /\.(mdl|morph|dict|knlm)$|combiningRule/.test(f));
  if (isModelDir(dir)) return dir;
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      const sub = join(dir, entry.name);
      if (isModelDir(sub)) return sub;
      for (const e2 of readdirSync(sub, { withFileTypes: true })) {
        if (e2.isDirectory() && isModelDir(join(sub, e2.name))) return join(sub, e2.name);
      }
    }
  }
  throw new Error(`[kiwi] aucun dossier modèle trouvé sous ${dir}`);
}

let cached: Analyzer | null = null;

export async function getKiwi(): Promise<Analyzer> {
  if (cached) return cached;
  const modelDir = await ensureModelDir();
  const { KiwiBuilder } = await import('kiwi-nlp');
  const wasmPath = require.resolve('kiwi-nlp/dist/kiwi-wasm.wasm');
  const builder = await KiwiBuilder.create(wasmPath);
  const modelFiles: Record<string, Uint8Array> = {};
  for (const f of readdirSync(modelDir)) {
    if (f === 'model.tgz') continue;
    const full = join(modelDir, f);
    try {
      modelFiles[f] = new Uint8Array(readFileSync(full));
    } catch {
      // sous-dossiers ignorés
    }
  }
  const kiwi = await builder.build({ modelFiles });
  cached = {
    async analyze(text: string): Promise<KiwiToken[]> {
      const result = await kiwi.analyze(text);
      // kiwi.analyze rend le meilleur découpage : { tokens: TokenInfo[] } (top-1)
      const tokens = Array.isArray(result) ? result[0]?.tokens ?? [] : result.tokens ?? [];
      return tokens.map((t: { str: string; tag: string; position: number; length: number }) => ({
        str: t.str,
        tag: t.tag,
        position: t.position,
        length: t.length,
      }));
    },
  };
  return cached;
}
