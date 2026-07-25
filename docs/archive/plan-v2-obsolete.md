# Plan — Molago 2.0 : brief matinal coréen généré

## Contexte

Molago v1 (dictionnaire personnel / flashcards) est archivée dans `archive/v1/`. La v2 repart de zéro sur une idée fondatrice : **un brief quotidien matinal en coréen gradué, généré la nuit, où l'apprentissage vient tout seul** — fondé sur la base de recherche `docs/research/` (10 principes : compelling input, couverture lexicale ≥96 % vérifiée algorithmiquement, SRS invisible tissé dans les textes, zéro culpabilité/gamification, récupération active minimale mais obligatoire, chunks parlés, narrow reading en mini-séries, stealth assessment, pipeline qualité pour le coréen généré, rituel fini de 8–12 min).

Décisions produit tranchées avec Pierre :
- **Sujets** : actu Corée & société, tech & science, histoire & culture coréenne.
- **Format** : mix alterné feuilleton fictif (해요체 parlé) / actu & chroniques (couche sino-coréenne), mini-séries 3–5 épisodes avec cliffhanger.
- **Objectif** : compréhension + production équilibrées. **Budget** : 8–12 min/matin.
- Hanja au tap (discret), TTS karaoké dès la V1, test de placement accepté, **strictement mono-utilisateur**.

## Choix techniques structurants

| Sujet | Choix | Pourquoi |
|---|---|---|
| Stack app | Next.js 16 / React 19 / TS / Supabase / CSS Modules / Phosphor (conventions v1) | Réutilise l'existant, scaffold à la racine |
| Pipeline nocturne | **GitHub Actions cron** (script Node/TS `pipeline/`), 02:05 KST + rattrapage 05:30 KST + `workflow_dispatch` | Durée 2–6 min, ffmpeg dispo, gratuit, relançable ; Vercel cron/Supabase Edge trop limités |
| Analyse morphologique | **`kiwi-nlp` (WASM officiel Kiwi, npm)** dans Node | Référence open source coréenne, zéro dépendance native, logique partagée vérification/annotation/seed |
| LLM génération | API Claude **`claude-opus-5`** (~0,20 $/nuit), sortie structurée ; passe « relecteur natif » = 2ᵉ appel Claude (slot HyperCLOVA X post-V1) | Seuls les modèles frontière tiennent registre + niveau ; naturalité = risque n°1 |
| TTS | **OpenAI `gpt-4o-mini-tts`** phrase par phrase → durées ffprobe → concat ffmpeg | Timings karaoké exacts sans forced alignment ; ~1,5 €/mois |
| Glossaire | **API krdict** (définitions FR réelles, cache DB) ; LLM ne fait que désambiguïser + collocation | P9 : jamais de définitions hallucinées |
| Fréquence/placement | Listes NIKL (어휘 목록 5 965 mots A/B/C + fréquences 2005) + liste manuelle « vie d'expat » (~200 entrées) | Seul référentiel librement réutilisable |
| SRS | **`ts-fsrs`**, planificateur interne invisible | P3 : réinjection dans les textes, jamais de cartes |
| Auth | Cookie secret (`middleware.ts` + `APP_SECRET`), écritures via routes serveur (service role), RLS sans policy anon | Mono-user, pas de colonne user |
| Coût total | ~6–8 €/mois (LLM + TTS), infra gratuite (Vercel hobby + Supabase free + Storage) | |

## Modèle de données (`supabase/migrations/001_init.sql`)

- `lexemes` — mots ET chunks : lemma, pos, kind, freq_rank, nikl_grade, hanja + hanja_family (jsonb), gloss_fr, cache krdict, tags.
- `lexeme_state` — profil (PK = lexeme_id, pas de user_id) : state `unknown|seen|known`, source, champs FSRS (stability, difficulty, due_at, reps, lapses), exposures, exposure_days.
- `series` — kind `feuilleton|actu|chronique`, register, series_bible jsonb (personnages/arc/cliffhangers, allowlist noms propres).
- `episodes` — brief_date UNIQUE (LE brief du jour), status `generating|ready|failed|read`, coverage_pct, audio_path, quiz jsonb, try_today jsonb, generation_meta jsonb (coûts, itérations).
- `sentences` — idx, text_ko, translation_fr, audio_start/end_ms, tokens jsonb (spans avec lexeme_id, role new/review, masked).
- `episode_lexemes` — glossaire par épisode : role, occurrences, gloss_fr, collocation, krdict_sense, hanja_panel.
- `events` — tap_gloss, hanja_open, quiz_answer, episode_completed, flag_awkward, mask_revealed_early…
- `placement_responses` + bucket Storage `audio`.

## Pipeline nocturne (`pipeline/run.ts` + `pipeline/steps/*.ts`, idempotent)

1. **Plan** : série active ou création de la mini-série suivante (LLM planner) ; actu = fetch RSS (Yonhap/KBS, HN pour tech).
2. **Sélection** : ts-fsrs items dus (≤8, dont 2–3 `masked`) + 3–8 nouveaux par triple filtre (fréquence × tags sujet × rendement hanja). Dus non retenus = attendent, zéro backlog.
3. **Génération** Claude : registre 해요체 explicite (checklist inverse KatFishNet : pas de 당신, peu de virgules, phrases verbales courtes), few-shot de vrai coréen parlé (`pipeline/assets/fewshot-haeyo.md`), cibles ≥3 occurrences, 300–400 mots.
4. **Vérification déterministe** (kiwi-nlp) : couverture lemmes de contenu ≥96 % vs (known ∪ seen ∪ prior NIKL ∪ allowlist ∪ noms propres) ; sinon **réécriture ciblée** (max 2 boucles + 1 régénération, pattern SRS-Stories) sinon `failed`.
5. **Révision** relecteur natif → re-vérification couverture.
6. **Annotation** : spans Kiwi + glossaire krdict (fallback gloss LLM marqué `unverified`) + panneau hanja caché.
7. **Quiz** : 3–5 cloze construits déterministiquement, distracteurs même POS/bande.
8. **TTS** phrase par phrase → offsets cumulés → concat → Storage.
9. **Commit** transactionnel + init due_at des nouveaux.

## UI (mobile-first, PWA, conventions v1 : composant .tsx + .module.css, bottom sheets)

- `/` brief du jour : header (titre, durée, épisode X/N) → `KaraokeReader` (audio, surlignage phrase active via timeupdate, tap = seek, 0.8×/1×) → `ClozeQuiz` (correction immédiate, pas de note) → `ExitCard` (1–2 « à essayer aujourd'hui » + teaser demain). Profil vide → `/placement`. Échec génération → état dégradé + bouton relance.
- `TokenSpan` tappable sans marquage visuel des nouveaux (flow) ; `MaskedToken` : 2–3 items en révision floutés, révélés après 2 s (tap anticipé = event).
- `GlossSheet` : gloss FR + collocation + bouton hanja → `HanjaPanel` (pattern `WordFamily` v1) + flag « 🚩 sonne bizarre ».
- `/placement`, `/progres` (purement informationnel), API : `/api/events` (batch sendBeacon), `/api/quiz`, `/api/flag`, `/api/placement`, `/api/admin/generate`.

## Stealth assessment (`src/lib/assessment.ts`, côté serveur)

tap → unknown→seen (sur known : rétrograde + FSRS Again) ; quiz correct → Good, raté → Again + réinjection surlendemain ; episode_completed → occurrences non tappées = review passive Good ; promotion seen→known : ≥5 expositions sans tap sur ≥3 jours distincts. `due_at` jamais affiché.

## Placement (~10 min, une fois)

10 bandes de rang (~8 mots/bande, ~80 jugements binaires connu/inconnu, deux gros boutons) → interpolation logistique par bande : p≥0,85 = known, zone grise = seen, au-delà = unknown. Imprécision acceptée 2 semaines, corrigée par les taps.

## Jalons (exécution séquentielle)

- **J0 Fondations** : scaffold racine (ts-fsrs, kiwi-nlp, @anthropic-ai/sdk, openai), middleware, migration 001, `scripts/seed-lexicon.ts`, PWA shell.
- **J1 Boucle bout en bout** : profil grossier (NIKL A+B = known), pipeline simple (feuilleton seul) exécutable local + GH Actions, UI brief + karaoké + tap-to-gloss + events. → un vrai brief lisible/écoutable chaque matin.
- **J2 Profil & FSRS** : /placement, ts-fsrs, stealth assessment, triple filtre, MaskedToken.
- **J3 Rituel complet** : quiz cloze + réinjection, ExitCard, planner mini-séries, alternance feuilleton/actu (RSS), passe réviseur.
- **J4 Finitions** : HanjaPanel, flag, /progres, rattrapage + états dégradés, polish PWA.

## Exclu de la V1

STT/retelling, flashcards optionnelles (V1.5), HyperCLOVA X (slot prévu), multi-user/Auth, notifications push, heatmap, missions scriptées, archive navigable, offline complet, réglages.

## Risques clés

1. Naturalité du coréen → few-shot réel + réviseur + flag humain, itérer le prompt.
2. **Écarts lemmes Kiwi ↔ NIKL** (하다-verbes, contractions → faux inconnus, boucle qui ne converge pas) → normalisation au seed, allowlist mots-outils, **tests `pipeline/__tests__/verify.test.ts` sur textes réels avant J1**.
3. Nuit sans brief → retries, job de rattrapage, relance en un tap.
4. Coût → plafond réécritures, coûts tracés dans generation_meta.
5. krdict incomplet → fallback gloss `unverified`.

## Vérification

- **Pipeline** : `npx tsx pipeline/run.ts --date=YYYY-MM-DD` en local (secrets en .env) → épisode `ready` en DB, mp3 dans Storage, coverage_pct ≥96 dans generation_meta ; tests unitaires du vérificateur kiwi-nlp sur textes coréens réels ; run `workflow_dispatch` GH Actions vert.
- **App** : `npm run dev` → /placement puis / : lecture karaoké synchronisée, tap-to-gloss ouvre le gloss FR, quiz, ExitCard ; events visibles en DB ; `npm run build` + lint verts.
- **Boucle complète** : générer deux briefs consécutifs et vérifier que les items tappés le jour 1 sont réinjectés/masqués le jour 2.
