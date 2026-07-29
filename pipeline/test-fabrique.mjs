#!/usr/bin/env node
// Les deux mécaniques de la fabrique qui peuvent mentir en silence.
//
//   node pipeline/test-fabrique.mjs
//
// Aucun réseau, aucune API, aucun framework : le fichier se lance et se tait
// s'il est content. Il ne couvre volontairement que ce qui casserait sans
// prévenir — le reste de la fabrique échoue bruyamment tout seul.
//
//   1. La table des caractères doit rendre DEUX FOIS LA MÊME RÉPONSE. C'est
//      toute sa raison d'être : le carnet regroupe les mots par caractère, et un
//      hanja qui change d'une nuit à l'autre défait ce regroupement.
//   2. La durée doit rester juste après le changement de voix. Elle est affichée
//      sur la carte, et c'est ce contrat de durée qui fait revenir le lecteur —
//      la version précédente l'a annoncée au double pendant une soirée, faute
//      d'avoir vu que le débit du MP3 avait changé avec la voix.

import { strict as assert } from 'node:assert'
import { mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

const { readHanjaTable, saveHanjaTable, cleanRoot, mp3Seconds, estimateWords } =
  await import('./build-day.mjs')

const dir = mkdtempSync(join(tmpdir(), 'molago-'))
const table = join(dir, 'hanja.json')

// ── 1 · la table rend la même chose deux fois ────────────────────────────────

const reponse = { i: 0, h: '管理費', m: 'management fee', f: [{ k: '관리하다', h: '管理', e: 'to manage' }] }
const propre = cleanRoot(reponse)
assert.equal(propre.h, '管理費')

// Première nuit : le mot est inconnu, on interroge, on écrit. 쓰레기 a été
// interrogé aussi et n'a pas de hanja — c'est cette entrée négative qui empêche
// de le redemander chaque nuit jusqu'à la fin des temps.
saveHanjaTable({ 관리비: propre, 쓰레기: null }, table)

const nuit1 = readHanjaTable(table)
const nuit2 = readHanjaTable(table)
assert.deepEqual(nuit1, nuit2, 'la table doit rendre la même chose à chaque lecture')
assert.deepEqual(nuit1['관리비'], propre)

// Deuxième nuit : les deux mots sont connus, donc rien à demander au modèle.
// C'est le coût qui tend vers zéro, et c'est la réponse qui cesse de bouger.
const lemmes = ['관리비', '쓰레기', '전세']
const inconnus = lemmes.filter((l) => !(l in nuit1))
assert.deepEqual(inconnus, ['전세'], 'seul le mot jamais vu doit être redemandé')

// Un mot appris ailleurs pendant qu'on travaillait ne doit pas être écrasé :
// la table est relue avant d'être écrite.
saveHanjaTable({ 전세: cleanRoot({ h: '傳貰', m: 'lease deposit', f: [] }) }, table)
const nuit3 = readHanjaTable(table)
assert.deepEqual(nuit3['관리비'], propre, 'la fusion ne doit rien perdre')
assert.equal(nuit3['쓰레기'], null)
assert.equal(nuit3['전세'].h, '傳貰')

// Ce qui n'a pas la forme attendue ne doit jamais entrer : une table est pour
// toujours, une réponse malformée s'y installerait définitivement.
assert.equal(cleanRoot({ h: '관리비' }), null, 'du hangul n\'est pas un hanja')
assert.equal(cleanRoot({ h: '', f: [] }), null)
assert.equal(cleanRoot(null), null)
assert.deepEqual(cleanRoot({ h: '酒', f: ['소주'] }).f, [], 'une famille en chaînes est jetée, le hanja reste')

// ── 2 · la durée, avec l'ancien débit comme avec le nouveau ──────────────────

/// Un MP3 crédible : un en-tête ID3 à ignorer, puis une trame Layer III.
const mp3 = (kbps, octets) => {
  const V2 = [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160]
  const buf = Buffer.alloc(octets + 10)
  buf.write('ID3', 0, 'latin1')
  buf[10] = 0xff
  buf[11] = 0xf3                                   // MPEG-2, Layer III
  buf[12] = (V2.indexOf(kbps) << 4) | 0x04         // débit, 24 000 Hz
  return buf
}

// Neural2 : 79 872 octets de 64 kbps font 9,98 s — c'est exactement ce que
// donnait la constante qu'on vient de supprimer. Le lecteur d'en-tête ne change
// donc rien à ce qui a déjà été fabriqué.
assert.equal(Math.round(mp3Seconds(mp3(64, 79872)) * 100) / 100, 9.98)

// Chirp3-HD : moitié moins d'octets pour la même seconde. C'est là que la carte
// se serait mise à mentir avec une constante en dur.
assert.equal(mp3Seconds(mp3(32, 40000)), mp3Seconds(mp3(64, 80000)))
assert.equal(mp3Seconds(mp3(32, 40000)), 10)
assert.equal(mp3Seconds(Buffer.alloc(4096)), 0, 'pas de synchro, pas de durée inventée')

// ── 3 · les repères estimés restent dans la phrase ───────────────────────────

const phrase = '오늘 아침에 관리비 고지서를 받았는데 금액이 평소보다 훨씬 많았어요'
const mots = estimateWords(phrase, 10)
assert.equal(mots.length, phrase.split(' ').length, 'un repère par 어절, comme le glossaire les attend')
assert.equal(mots[0].t, 0)
for (const m of mots) assert.equal(typeof m.t, 'number', 'un t manquant rend la journée entière indécodable')
for (let i = 1; i < mots.length; i++) {
  assert.ok(mots[i].t > mots[i - 1].t, 'les repères doivent avancer')
}
assert.ok(mots.at(-1).t < 10, 'le dernier mot commence avant la fin du son')

rmSync(dir, { recursive: true, force: true })
console.log('✓ table stable, durée juste aux deux débits, repères dans la phrase')
