# Molago

Apprendre le coréen avec du contenu qui m'intéresse vraiment — la vie de tous les
jours en Corée, l'actualité, les sujets dont je parlerais de toute façon.

**État : phase produit. Aucun code.** On définit d'abord ce que l'application fait,
pour qui, et comment on s'en sert. Le code viendra après.

## Ce qu'il y a dans le repo

| Dossier | Contenu |
|---|---|
| **`docs/product-spec.md`** | **La spécification produit — le point d'entrée.** Parcours, écrans, moteur de vocabulaire, chaîne de fabrication, modèle de données, coûts, risques. |
| `docs/decisions.md` | Le journal des 31 décisions, avec leurs raisons. À lire quand on se demande « pourquoi ce choix ? ». |
| `docs/wireframes/` | Maquettes fil de fer. Structure et comportement, pas direction visuelle. |
| `docs/research/` | Base de recherche : science de l'acquisition du vocabulaire, spécificités du coréen, motivation, paysage concurrentiel, vocabulaire de la vie d'expat, contenu généré par IA. La synthèse (`00`) est le point d'entrée. |
| `docs/archive/` | Anciens plans, conservés pour référence. Décisions techniques obsolètes. |
| `data/expat-lexicon.json` | Liste manuelle de mots et expressions de la vie quotidienne en Corée, sous-représentés dans les listes officielles. |
| `public/` | Logo et icônes. |

## La prochaine étape

**Un essai comparatif à l'aveugle**, avant toute ligne de code : le même article réécrit
en coréen par plusieurs modèles, le même paragraphe lu par plusieurs voix, présentés sans
dire lequel est lequel. Ça tranche le choix du générateur et de la voix — et surtout, ça
répond à la seule question qui décide de la viabilité : *est-ce que ce coréen sonne
juste ?* Voir `docs/product-spec.md` §14.

Ensuite : la direction visuelle, puis le plan d'implémentation.

## Historique

- **v1** — dictionnaire personnel / fiches de vocabulaire. Abandonnée.
- **v2 (premier essai)** — application web Next.js + Supabase, jamais exécutée.
  Supprimée. Récupérable via le tag git `archive/pre-reset`.
- **maintenant** — retour à la planification produit.

## Direction technique pressentie

Rien n'est arrêté, mais les contraintes connues :

- **Front** : application native Apple (Swift).
- **Backend** : VPS personnel — Postgres + API en Docker, sur le modèle du projet `to-day`.
- **LLM** : OpenRouter.
- **Voix** : à déterminer (ElevenLabs ou équivalent).
