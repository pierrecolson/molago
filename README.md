# Molago

Une bibliothèque personnelle pour apprendre le coréen à partir de ce qu’on rencontre réellement.

Molago ne génère aucun article automatiquement. L’utilisateur choisit une photo ou une vidéo YouTube ; l’app conserve le contenu coréen, sa traduction et son contexte pour le retrouver et garder ses mots.

## Produit

- **Library** : les trois derniers imports dans des cartes riches, puis les plus anciens en lignes.
- **Capture** : photo, photothèque ou URL YouTube collée directement.
- **YouTube** : lecteur intégré, transcript synchronisé et traduction anglaise à la demande.
- **Wordbook** : mots gardés avec leur contexte, leur décomposition Hanja et une famille de mots quand elle existe.
- **Hors ligne** : les imports et transcripts déjà chargés restent lisibles.

La spécification de cette évolution est dans [`docs/plans/2026-08-17-import-only-library-design.md`](docs/plans/2026-08-17-import-only-library-design.md).

## Structure

| Dossier | Contenu |
|---|---|
| `app/` | Application iOS native SwiftUI |
| `api/` | API Node : captures, imports YouTube et bibliothèque |
| `deploy/` | Déploiement Docker sur le VPS |
| `pipeline/` | Ancienne fabrique quotidienne, conservée comme archive mais plus déployée |
| `docs/` | Spécifications, décisions et recherche produit |

## Vérification locale

```bash
node --test api/*.test.mjs
cd app && xcodegen && ./run.sh
```

## Déploiement

```bash
./deploy/push.sh --build
```

La stack active contient seulement `files` et `api`. L’ancien cron du VPS qui lançait `pipeline` doit être supprimé lors du premier déploiement de cette version.
