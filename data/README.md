# Données lexicales

## Fichiers attendus

### `expat-lexicon.json` (inclus dans le repo)
Liste manuelle « vie d'expat » : mots et chunks sous-représentés dans les listes
officielles (backchannels, contractions, collocations, vocabulaire pratique).
Extensible librement — relancer `npm run seed` après modification.

### `nikl-vocab.csv` (à fournir, non commité)
La liste **한국어 학습용 어휘 목록** du NIKL (~5 965 mots, grades A/B/C).

- Source : https://www.korean.go.kr → 자료 → 연구 자료 → 한국어 학습용 어휘 목록
  (fichier hwp/xls officiel ; des conversions CSV existent aussi sur GitHub).
- Format attendu (en-tête inclus) :

```csv
lemma,pos,grade
가다,동사,A
가게,명사,A
```

`pos` accepte les catégories coréennes du fichier officiel (명사, 동사, 형용사,
부사, 대명사, 수사, 관형사, 감탄사, 의존명사…) — le seed les mappe vers les tags Kiwi.
Les numéros d'homographe (`가다01`) sont nettoyés automatiquement.

### `nikl-freq.csv` (à fournir, optionnel)
Rangs de fréquence issus du **현대 국어 사용 빈도 조사** (NIKL, 2005).

```csv
lemma,pos,rank
것,명사,1
하다,동사,2
```

Si absent, les lexèmes sont seedés sans `freq_rank` (le placement utilise alors
les grades A/B/C comme bandes approximatives).

## Usage

```bash
# Seed complet (upsert idempotent)
npm run seed

# Avec initialisation du profil « prior NIKL » (grades A+B → known)
npm run seed -- --prior
```
