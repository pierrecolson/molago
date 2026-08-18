import test from 'node:test'
import assert from 'node:assert/strict'
import { translateLines } from './translate.mjs'

const numbersIn = (prompt) => [...prompt.matchAll(/^(\d+)\. (.+)$/gm)].map((m) => Number(m[1]))
const lines = (n) => Array.from({ length: n }, (_, i) => `줄 ${i}`)

test('each line gets its own translation, in order, across chunks', async () => {
  const seen = []
  const out = await translateLines(lines(120), {
    llm: async (prompt) => {
      const numbers = numbersIn(prompt)
      seen.push(numbers.length)
      return { t: numbers.map((i) => ({ i, e: `line ${i}` })) }
    },
  })

  assert.equal(out.length, 120)
  assert.equal(out[0], 'line 0')
  assert.equal(out[119], 'line 119')
  assert.deepEqual(seen.sort((a, b) => b - a), [50, 50, 20], 'découpé en tranches de cinquante')
})

test('a chunk the model half-answers is retried, then given up on — never misaligned', async () => {
  let attempts = 0
  const out = await translateLines(lines(60), {
    llm: async (prompt) => {
      const numbers = numbersIn(prompt)
      // La première tranche décroche à mi-chemin, les deux fois.
      if (numbers[0] === 0) {
        attempts++
        return { t: numbers.slice(0, 20).map((i) => ({ i, e: `line ${i}` })) }
      }
      return { t: numbers.map((i) => ({ i, e: `line ${i}` })) }
    },
  })

  assert.equal(attempts, 2, 'réessayé une fois')
  assert.deepEqual(out.slice(0, 50), Array(50).fill(''), 'rien de la tranche ratée ne passe')
  assert.equal(out[50], 'line 50', 'les autres tranches sont intactes')
})

test('a model that answers with a bare array still lands', async () => {
  const out = await translateLines(lines(3), {
    llm: async (prompt) => numbersIn(prompt).map((i) => ({ i, e: `line ${i}` })),
  })
  assert.deepEqual(out, ['line 0', 'line 1', 'line 2'])
})
