import { existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from 'node:fs'
import { dirname } from 'node:path'

const read = (file) => {
  try { return JSON.parse(readFileSync(file, 'utf8')) } catch { return {} }
}

export const lexiconCache = (file) => ({
  async remember(key, generate) {
    const entries = read(file)
    if (Object.hasOwn(entries, key)) return entries[key]

    const value = await generate()
    entries[key] = value
    mkdirSync(dirname(file), { recursive: true })
    writeFileSync(`${file}.tmp`, JSON.stringify(entries))
    renameSync(`${file}.tmp`, file)
    return value
  },
})

export const selectFamily = (morphemes, candidates) => {
  let selected = { root: null, family: [] }
  for (const morpheme of morphemes) {
    const family = candidates.filter((word) => word.h.includes(morpheme.h))
    if (family.length > selected.family.length) selected = { root: morpheme.e, family }
  }
  return selected
}
