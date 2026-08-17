import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

test('reuses a stored word enrichment instead of producing it again', async (t) => {
  const module = await import('./lexicon.mjs').catch(() => null)
  assert.ok(module, 'lexicon cache is not implemented yet')

  const root = mkdtempSync(join(tmpdir(), 'molago-lexicon-'))
  t.after(() => rmSync(root, { recursive: true, force: true }))
  const cache = module.lexiconCache(join(root, 'lexicon.json'))
  let generations = 0
  const generate = async () => {
    generations++
    return { lemma: '관리비', hanja: '管理費' }
  }

  const first = await cache.remember('관리비', generate)
  const second = await cache.remember('관리비', generate)

  assert.deepEqual(first, { lemma: '관리비', hanja: '管理費' })
  assert.deepEqual(second, first)
  assert.equal(generations, 1)
})

test('keeps only the largest family sharing one exact Hanja root', async () => {
  const { selectFamily } = await import('./lexicon.mjs')
  const selected = selectFamily(
    [
      { k: '관', h: '管', e: 'manage' },
      { k: '리', h: '理', e: 'organize' },
      { k: '비', h: '費', e: 'fee, expense' },
    ],
    [
      { k: '관리', h: '管理', e: 'management' },
      { k: '회비', h: '會費', e: 'membership fee' },
      { k: '교통비', h: '交通費', e: 'transport costs' },
      { k: '식비', h: '食費', e: 'food expenses' },
    ],
  )

  assert.equal(selected.root, 'fee, expense')
  assert.deepEqual(selected.family.map((word) => word.k), ['회비', '교통비', '식비'])
})
