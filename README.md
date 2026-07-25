# Molago 2.0

Le brief coréen du matin : un texte quotidien en coréen gradué (300–400 mots, 8–12 minutes),
généré la nuit, calibré sur le vocabulaire réellement connu — l'apprentissage vient tout seul.

- `docs/research/` — base de connaissances (7 rapports) et synthèse des 10 principes de design.
- `archive/v1/` — l'ancienne application (flashcards / ajout de mots), conservée pour référence.

## Architecture

| Pièce | Où | Quoi |
|---|---|---|
| App | `src/` | Next.js 16, mobile-first PWA : lecture karaoké, tap-to-gloss, quiz cloze, placement, /progres |
| Pipeline nocturne | `pipeline/` | GitHub Actions (02:05 KST + rattrapage 05:30) : sélection FSRS → génération Claude → vérification de couverture ≥ 96 % (Kiwi) → réécriture → réviseur natif → glossaire krdict → TTS + timings |
| Données | `supabase/migrations/` | lexemes, lexeme_state (FSRS + stealth assessment), series, episodes, sentences, events |
| Lexique | `data/` | Liste « vie d'expat » commitée + listes NIKL à fournir (voir `data/README.md`) |

## Mise en route

1. **Supabase** : créer un projet, exécuter `supabase/migrations/001_init.sql` dans le SQL Editor.
2. **Secrets** : copier `.env.example` → `.env` (app : Vercel env vars ; pipeline : GitHub Actions secrets).
3. **Lexique** : déposer `data/nikl-vocab.csv` (+ `data/nikl-freq.csv` si possible), puis `npm run seed`.
4. **Profil** : ouvrir l'app → test de placement (~10 min, une fois). Ou `npm run seed -- --prior` pour partir de l'hypothèse NIKL A+B.
5. **Premier brief** : `npm run pipeline` en local, ou l'action « Brief nocturne » (workflow_dispatch).

## Commandes

```bash
npm run dev        # app en local
npm run pipeline   # générer le brief du jour (-- --date=YYYY-MM-DD --force)
npm run seed       # seed du lexique (-- --prior pour initialiser le profil)
npm test           # tests (vérificateur de couverture)
```

## Principes non négociables (résumé)

Contenu captivant d'abord ; couverture lexicale 96–98 % vérifiée hors LLM ; répétition espacée
invisible (tissée dans les textes, jamais en cartes) ; zéro dette, zéro streak, zéro gamification ;
récupération active minimale mais présente (mots masqués 2 s, quiz cloze) ; chunks parlés en 해요체
naturel ; mini-séries à cliffhanger ; stealth assessment ; glossaire ancré krdict ; rituel fini.
Détails : `docs/research/00-synthese-principes-design.md`.
