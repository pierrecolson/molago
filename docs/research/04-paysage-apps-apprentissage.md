# 04 — Le paysage des applications d'apprentissage des langues basées sur du contenu

*Recherche pour Molago 2.0 — juillet 2026*

---

## Résumé exécutif

Le marché se divise en trois générations : (1) les lecteurs-outils (LingQ, Readlang, Lute) qui excellent au tracking des mots connus mais souffrent d'UX vieillissante et n'apportent pas de contenu adapté ; (2) les bibliothèques de contenu gradué éditorialisé (Du Chinese, Satori Reader, Todaii Easy Korean) — le modèle le plus aimé des utilisateurs, mais limité par le coût de production humaine du contenu ; (3) depuis 2024-2025, les générateurs d'histoires par LLM (Lenguia, Gradia, StoryLing, Story Bot de Readlang) qui promettent du contenu infini personnalisé mais peinent encore sur la qualité et la méthodologie. Les patterns UX gagnants sont constants : dictionnaire au tap, audio synchronisé, tracking mots connus/inconnus, niveaux gradués. La science est claire : ~98 % de couverture lexicale requise (Hu & Nation 2000), 8-10 rencontres d'un mot pour l'acquérir (Webb, Pigada & Schmitt). Le trou de marché exact de Molago existe : **aucune app ne combine proprement contenu quotidien piloté par les centres d'intérêt + injection méthodique de vocabulaire recyclé + SRS discret**, encore moins pour le coréen "vie quotidienne d'expat" hors K-pop. Lenguia (36 langues, 29,99 $/mois) est le concurrent le plus proche conceptuellement — et valide l'idée.

---

## 1. Le socle scientifique : pourquoi l'approche "contenu" fonctionne

Avant de comparer les apps, les chiffres qui gouvernent tout le domaine :

- **Hypothèse de l'input compréhensible (Krashen, 1982/1985)** : on acquiert la langue en comprenant des messages légèrement au-dessus de son niveau (*i+1*). Une étude mixte de 2025 ([Frontiers in Education](https://www.frontiersin.org/journals/education/articles/10.3389/feduc.2025.1614680/full)) a testé l'hypothèse avec de l'input généré par IA et confirme l'effet sur la compétence orale en EFL.
- **Seuil de couverture lexicale : 95-98 %**. L'étude de référence est **Hu & Nation (2000)** : il faut connaître ~98 % des mots d'un texte pour le comprendre sans aide (~1 mot inconnu tous les 20-50 mots). Walker (1997) donne 95 % comme plancher. Pour l'écoute, viser 90-95 % car on ne peut pas relire ([synthèse Gianfranco Conti](https://gianfrancoconti.com/2025/02/27/why-the-input-we-give-our-learners-must-be-95-98-comprehensible-in-order-to-enhance-language-acquisition-the-theory-and-the-research-evidence/)).
- **Nombre de rencontres pour acquérir un mot : 8 à 10**. Nation & Wang : après 10 rencontres, un mot a de fortes chances d'être appris. Pigada & Schmitt, Pellicer-Sánchez & Schmitt, Webb confirment le palier à ~10 expositions. Une étude eye-tracking montre qu'après 8 expositions, les lecteurs L2 reconnaissent la forme de 86 % des mots cibles et le sens de 75 %, mais ne *rappellent* le sens que de 55 % — le rappel actif reste plus dur que la reconnaissance ([Pellicer-Sánchez, Bilingualism: Language and Cognition](https://www.cambridge.org/core/journals/bilingualism-and-cognition/article/abs/incidental-vocabulary-learning-in-a-natural-reading-context-an-eyetracking-study/9DE8BB8989973448A4245C87522D72C1)).
- **TPRS (Teaching Proficiency through Reading and Storytelling)** : la méthode qui formalise "histoires + vocabulaire recyclé". Les études montrent un avantage net sur l'acquisition du vocabulaire et le rythme d'apprentissage ; certains travaux revendiquent un niveau intermédiaire en 60-100 h contre 400-600 h en méthode classique ([Bethel University, revue de littérature](https://spark.bethel.edu/cgi/viewcontent.cgi?article=1185&context=etd)). Le principe clé : **narrow reading** — rester sur des thèmes proches pour que le vocabulaire se recycle naturellement d'un texte à l'autre.

**Conséquence directe pour un générateur de contenu** : un texte quotidien doit contenir ~2-5 % de mots nouveaux maximum, et chaque mot nouveau doit réapparaître ~8-10 fois sur les jours/semaines suivants. C'est exactement ce qu'aucun contenu authentique (news brutes, YouTube) ne garantit, et ce qu'un LLM peut orchestrer.

---

## 2. Génération 1 : les lecteurs-outils (l'utilisateur apporte le contenu)

### LingQ — le pionnier du tracking de mots connus

**Mécanisme** : importer n'importe quel texte/audio ; les mots inconnus apparaissent en bleu, on les "LingQ" (surlignage jaune) avec une définition communautaire, puis on les fait progresser sur une échelle 1→4→"connu". Le compteur de "known words" est la métrique centrale de motivation. Bibliothèque communautaire + mini-stories officielles.

**Pourquoi les utilisateurs restent** : c'est l'implémentation la plus complète de la lecture extensive à la Krashen ; le compteur de mots connus est très motivant ("number go up") ; contenu authentique illimité ; import Netflix/YouTube.

**Pourquoi ils partent** (recoupement Trustpilot, forums, revues) :
- **Bugs chroniques** : "the browser app is full of bugs and the user experience is abysmal" (utilisateur long terme) ; crashs, mode révision cassé, découpage ePub défaillant, mots insélectionnables ([Trustpilot](https://www.trustpilot.com/review/lingq.com), [FluentU review](https://www.fluentu.com/blog/reviews/lingq/)).
- **Prix** (~13 $/mois) jugé élevé face aux alternatives gratuites (Lute, LWT), version gratuite quasi inutilisable (limite de 20 LingQs).
- **UX datée**, support client décrié.
- Le compteur de mots connus devient un **but en soi** (Goodhart) : les utilisateurs "farment" les mots au lieu de lire.
- Ne travaille ni l'expression écrite ni l'orale.

**Leçon pour Molago** : le tracking mots connus/inconnus est LE mécanisme de rétention de cette catégorie — mais il doit être fiable, discret et automatique, pas une corvée de clics.

### Readlang — la version épurée

**Mécanisme** : extension web + lecteur ; clic sur un mot = traduction instantanée + carte SRS créée automatiquement avec le contexte. Créé par un solo-dev (racheté puis re-repris par son créateur). Depuis fin 2024, un **"Story Bot"** génère des histoires par IA pour les premium ([forum Readlang](https://forum.readlang.com/t/new-story-bot-for-ai-generated-stories/1309)) — signe que même les lecteurs-outils historiques pivotent vers la génération de contenu.

**Rétention** : les utilisateurs adorent la friction minimale (un utilisateur : lire des histoires entières sans s'arrêter aux mots inconnus a fait "la différence critique" pour son espagnol). Ils partent à cause de l'absence d'app mobile native, du design vieillissant, et du support coréen moins soigné que pour les langues européennes.

### Lute / LWT (open source)

[Lute v3](https://github.com/jzohrab/lute) (Python/Flask, auto-hébergé) et [LWT fork HugoFara](https://github.com/HugoFara/lwt) reproduisent LingQ gratuitement, avec flux RSS prêts pour 19 langues dont le coréen. Public : bricoleurs. Intérêt pour Molago : **la structure de données de référence** (statuts de mots 0-5, termes multi-mots, parsing par langue) est documentée en open source — utile comme modèle du domaine.

**Échec commun de la génération 1** : elles fournissent l'outil mais pas le contenu au bon niveau. L'utilisateur doit trouver lui-même des textes à ~98 % de couverture — quasi impossible en coréen authentique quand on a 3 000-5 000 mots.

---

## 3. Génération 2 : le contenu gradué éditorialisé (le modèle le plus aimé)

### Du Chinese — la référence UX de la catégorie

**Mécanisme** : +1 900 leçons écrites par des humains, 6 niveaux calés sur le HSK, audio professionnel synchronisé phrase par phrase (karaoké), tap sur un mot = définition + ajout au deck de révision, mots HSK déjà connus grisables. ([LTL review](https://ltl-school.com/du-chinese/), [Ninchanese](https://ninchanese.com/blog/2022/10/18/du-chinese-review-of-a-great-graded-reader/))

**Pourquoi ça marche** : "super high learning value because it combines audio with reading… the app is super slick and works better than anything else out there". La combinaison lecture + audio natif + niveaux stricts + tap-dictionnaire est le package gagnant. C'est l'app que tout le monde cite comme modèle.

**Limite structurelle** : le contenu coûte cher à produire → volume fini, sujets génériques, pas de personnalisation par intérêt. Et ça n'existe pas pour le coréen à ce niveau de qualité.

### Satori Reader (japonais) — le meilleur modèle produit à copier

**Mécanisme** ([Tofugu](https://www.tofugu.com/reviews/satori-reader/), [site officiel](https://www.satorireader.com/how-it-works)) : séries feuilletonnées (42 séries) avec épisodes hebdomadaires, audio natif, annotations rédigées (pas juste un dico : de vraies explications de nuance), et surtout : **le texte s'adapte à ce que vous connaissez** (affichage kanji/kana selon votre profil de connaissances). Les flashcards embarquent la phrase d'origine avec audio, et on peut accumuler plusieurs phrases-contextes par mot. Heatmap de régularité.

**Pourquoi les utilisateurs adorent** : le contenu est *bien écrit et réellement intéressant* (feuilletons avec cliffhangers → on revient pour l'histoire, pas pour l'étude) ; l'annotation humaine explique ce qu'un dictionnaire ne dit pas. C'est l'app la plus proche de l'expérience "Didi Podcast en texte".

**Leçon clé pour Molago** : la sérialisation (histoires à suivre) est un mécanisme de rétention bien plus puissant que le streak — on revient pour connaître la suite.

### Todaii / Todai Easy Korean — les news graduées

**Mécanisme** ([Google Play](https://play.google.com/store/apps/details?id=mobi.eup.easykorean&hl=en_US)) : articles de presse coréens avec audio, vitesse réglable, dico au tap, liste de vocabulaire par article, flashcards. Base : ~1 000 articles, 173 000 entrées de vocabulaire.

**Échec instructif** : avis récent — "il y a 3 ans c'était utile, mais toutes les news datent de 2023, plus aucun article nouveau". **La fraîcheur du contenu est un contrat implicite : une app de news qui cesse d'être quotidienne meurt.** Par ailleurs les articles sont de vraies news simplifiées a minima — trop dures en dessous de TOPIK 4, et non graduées mot à mot.

### Beelinguapp — le contre-exemple

Texte parallèle (L1/L2 côte à côte) + karaoké audio. Verdict des revues 2025-2026 ([Lingopie](https://lingopie.com/blog/beelinguapp-review/)) : "impossible à recommander" — erreurs de traduction, voix IA médiocres, **pas de dictionnaire au tap mot à mot** (seulement la phrase parallèle), contrôle qualité du contenu IA défaillant. Double leçon : (1) le texte parallèle intégral incite à lire la L1 et court-circuite l'acquisition ; (2) du contenu généré par IA **sans pipeline de contrôle qualité** détruit la confiance très vite.

---

## 4. Immersion vidéo : Language Reactor et Migaku

- **Language Reactor** (gratuit/freemium, extension Chrome) : double sous-titres Netflix/YouTube, dico au survol, auto-pause. Excellent pour la compréhension en scène, faible pour la rétention long terme.
- **Migaku** (~10 $/mois, "best Japanese/Korean app 2025" selon ses PR) : mining de phrases — un clic sur une réplique génère une carte Anki avec audio, image, définition, préformatée. Tracking des mots connus par-dessus les sous-titres. Verdict des comparatifs ([funfluen](https://funfluen.com/learn/compare/language-reactor-vs-migaku/)) : LR = "je ne comprends pas la scène", Migaku = "je comprends mais je ne revois jamais les meilleures phrases". Setup raide, courbe d'apprentissage réelle.

**Leçon** : le pipeline "rencontre en contexte → carte SRS en un clic avec contexte complet (phrase + audio + image)" est l'état de l'art du couplage contenu↔flashcards. Molago doit reproduire ce geste : *tout mot tapé dans une histoire devient une carte avec sa phrase d'origine, sans effort*.

---

## 5. Flashcards et SRS : ce qui marche, ce qui brûle les gens

### Anki — puissant et détesté

Raisons d'abandon documentées ([My Senpai, "Why People Quit Anki"](https://my-senpai.com/insights/why-people-quit-anki.html), [The Anki Burnout](https://my-senpai.com/insights/ankiburnout.html)) :
1. **L'avalanche post-pause** : une semaine d'arrêt = backlog de centaines de cartes = culpabilité = abandon. C'est LA cause n°1.
2. **"Ease hell"** : l'algorithme SM-2 punit les cartes ratées en les faisant revenir sans cesse ; les 5-10 % de cartes les plus dures consomment ~50 % du temps de révision.
3. **"Zombie memories"** : mots isolés sans contexte émotionnel — on "connaît" le mot sans le sentir. Consensus Reddit : le sentence mining depuis l'immersion réelle bat les listes de mots isolés.
4. La création de cartes est un travail en soi.

**FSRS** (défaut Anki depuis v23.10, nov. 2023) change la donne : sur des benchmarks de 500 M+ de reviews, FSRS atteint la même rétention de 90 % avec **~20-30 % de reviews en moins** que SM-2 et prédit mieux le rappel dans 99,6 % des collections ([benchmark](https://memoforge.app/blog/fsrs-vs-sm2-anki-algorithm-guide-2025/)). Tout SRS construit en 2026 doit être FSRS-like, pas SM-2.

### Clozemaster — le SRS contextualisé

Phrases à trou massives ([Refold](https://refold.la/blog/srs-that-isnt-anki-clozemaster)) : "Anki traite le vocabulaire comme un problème de mémoire, Clozemaster comme un problème d'exposition". Le cloze en contexte est la forme de révision la moins douloureuse — mais les phrases sont aléatoires, sans lien avec ce que l'utilisateur lit.

### Drops — le contre-modèle

Vocabulaire par images en sessions de 5 min, très joli. Verdict unanime ([mezzoguild](https://www.mezzoguild.com/drops-review/), [FluentU](https://www.fluentu.com/blog/reviews/drops-language-app/)) : simple supplément, aucun contexte, aucune phrase, pas de progression réelle. Exemple parfait de ce que le profil Molago rejette (par-cœur déguisé en jeu).

---

## 6. Conversation IA : Speak, Praktika, et les apps coréennes

- **Speak** (initialement centré coréen, siège à Séoul côté marché) et **Praktika** (20 M d'utilisateurs revendiqués, avatars vidéo, ~8 $/mois) : très bons pour désinhiber l'oral, feedback instantané sans jugement. Critiques récurrentes ([Languatalk review](https://languatalk.com/blog/praktika-review/)) : parcours rigides, feedback générique au-delà du niveau intermédiaire.
- **Teuida** (coréen, 5 M de téléchargements, [passé à d'autres langues fin 2025](https://markets.financialcontent.com/custercountychief/article/getnews-2025-12-10-teuida-passes-5m-downloads-as-it-expands-its-speaking-first-language-learning-platform-beyond-korean)) : simulations de conversation en POV vidéo. Reconnaissance vocale imprécise, contenu orienté débutant/touriste et K-culture.
- **Eggbun** : chatbot scripté avec mascotte, 550+ leçons — en réalité un cours déguisé en chat, répétitif, plafonne vite.
- **Sejong** (apps de l'institut Sejong) : sérieux, scolaire, gratuit, mais zéro personnalisation et UX institutionnelle.

**Constat** : les apps coréennes grand public visent les débutants motivés par la K-pop/dramas — exactement l'anti-profil de l'utilisateur Molago (expat de 8 ans, besoin de vie quotidienne). Ce segment "résident long terme, intermédiaire, hors culture pop" est structurellement mal servi.

---

## 7. Génération 3 (2024-2026) : les graded readers générés par LLM

La vague récente, directement dans l'axe de Molago :

| App | Mécanisme | Points notables |
|---|---|---|
| **[Lenguia](https://www.lenguia.com/)** | Histoires quotidiennes personnalisées (niveau + intérêts), 36 langues **dont le coréen**, 83 structures narratives × 25 tons, import podcasts/EPUB/web avec simplification | **Le concurrent le plus proche de Molago** : les mots en révision SRS sont **réinjectés automatiquement dans les histoires suivantes**. Cible : ≥500 mots de base → C1. Prix élevé : 29,99 $/mois (19,99 $ en annuel) |
| **[Gradia](https://play.google.com/store/apps/details?id=com.betapilot.gradia)** | Génération d'histoires à la demande au niveau choisi, audio intégré, traduction mot/phrase instantanée | Simple, mobile-first, mais pas de vraie boucle de recyclage du vocabulaire |
| **[StoryLing](https://storyling.app/)** | Histoires graduées par intérêts + cartes SRS conservant le contexte d'origine | Early access ; anglais/russe/italien seulement — pas de coréen |
| **[Readlang Story Bot](https://forum.readlang.com/t/new-story-bot-for-ai-generated-stories/1309)** | Génération d'histoires IA dans le lecteur existant (premium, nov. 2024) | Validation : même les acteurs historiques ajoutent la génération |
| **[Comprehensible Later](https://twocentstudios.com/2025/11/15/comprehensible-later-read-it-later-for-language-learners/)** | Read-it-later qui **simplifie par LLM** de vrais articles vers votre niveau | L'idée "actualité réelle réécrite à votre niveau" existe déjà en indie iOS |
| **[MeloLingua](https://melolingua.com/ai-story-language-app)** | Histoires personnalisées + prononciation guidée | Marketing lourd, profondeur méthodologique douteuse |

**Ce que cette génération n'a pas encore résolu** :
1. **La qualité linguistique en coréen** : les LLM écrivent un coréen correct mais souvent traduit-de-l'anglais, avec des registres mal calibrés (해요체 vs 반말 vs 합쇼체). Aucune de ces apps n'a de contrôle qualité spécifique coréen visible.
2. **La méthodologie d'injection** : Lenguia est la seule à annoncer le recyclage SRS→histoires, mais aucune ne documente un vrai contrôle de couverture lexicale (98 %) ni un ordonnancement des 8-10 réexpositions.
3. **Le "cold start" du profil lexical** : savoir ce que l'utilisateur connaît déjà (crucial pour un intermédiaire à ~3 000-5 000 mots) reste bâclé partout — questionnaire grossier ou compteur à zéro.

---

## 8. Les patterns UX gagnants (synthèse transversale)

Présents dans toutes les apps qui marchent :

1. **Dictionnaire au tap, zéro friction** — le standard absolu (Du Chinese, Satori, LingQ, Todaii). Son absence tue une app (Beelinguapp).
2. **Tracking automatique des mots connus** — le moteur de progression perçue (LingQ, Migaku, Lenguia). Meilleur quand il est passif (déduit de la lecture) plutôt qu'actif (clics obligatoires).
3. **Audio synchronisé phrase par phrase** (karaoké) — Du Chinese, Satori, Beelinguapp. Indispensable pour le coréen (lien lecture↔écoute, débit réel).
4. **Niveaux gradués explicites** adossés à un référentiel (HSK pour Du Chinese ; pour le coréen : TOPIK + la liste officielle des **6 000 mots du 국립국어원**, graduée A/B/C, [disponible en Excel](https://aflickerofkorean.wordpress.com/2018/10/27/6000-most-common-korean-words-found-the-official-list/)).
5. **La carte SRS naît du contexte** — phrase d'origine + audio embarqués (Satori, Migaku). Jamais de mot isolé.
6. **Sérialisation / fraîcheur quotidienne** — feuilletons Satori, news du jour Todaii. Le contenu qui se périme (Todaii 2023) ou ne se renouvelle pas fait fuir.
7. **Métriques de constance douces** (heatmap Satori) plutôt que streaks anxiogènes : la recherche sur Duolingo montre que les apprenants motivés uniquement par la gamification abandonnent plus que ceux motivés par un intérêt réel, et que le streak crée une "illusion de progrès" au niveau intermédiaire ([dev.to](https://dev.to/yaptech/duolingos-shallow-learning-trap-gamified-streaks-harmful-habits-4134)). À noter quand même : le churn mensuel de Duolingo est passé de 47 % (2020) à 28 % (2025), DAU/MAU ~37 % — la gamification *fonctionne* pour la rétention produit, mais pas pour l'apprentissage intermédiaire.
8. Chiffre marché utile : les apps à contenu adaptatif IA rapportent **+30-40 % de rétention J30** vs les apps à cours statiques ([LingoBright statistics](https://www.lingobright.com/statistics/language-learning-apps/)).

---

## 9. Le trou dans le marché

Le croisement de trois axes qu'aucune app ne couvre ensemble :

1. **Contenu piloté par les centres d'intérêt réels** (pas "voyages/restaurant/K-pop" mais *les* sujets de l'utilisateur : actu, tech, vie de quartier…) — seule Lenguia s'en approche, à 30 $/mois, sans spécialisation coréenne.
2. **Méthodologie d'injection contrôlée** : contrainte de couverture ~98 %, mots nouveaux choisis dans la bande de fréquence utile (liste 국립국어원 + vocabulaire situationnel de la vie en Corée), replanification des 8-10 réexpositions dans les textes des jours suivants (narrow reading orchestré). **Personne ne fait ça rigoureusement.**
3. **SRS invisible ou quasi invisible** : la révision passe par la relecture (le mot revient dans l'histoire de demain) et non par une pile de cartes ; les flashcards ne sont qu'un complément optionnel avec contexte embarqué.

S'y ajoute le segment démographique orphelin : **le résident étranger de longue durée en Corée, intermédiaire, indifférent à la culture pop** — ignoré par Teuida/Eggbun (débutants K-culture) comme par Todaii (news brutes trop dures, non personnalisées).

---

## 10. Implications concrètes pour Molago 2.0

### Architecture du contenu
1. **Un texte par matin, sérialisé** : alterner (a) résumés d'actualité réécrits au niveau exact (modèle Comprehensible Later / Todaii, mais personnalisé) et (b) micro-feuilletons sur les intérêts de l'utilisateur avec cliffhangers (modèle Satori Reader). La sérialisation est le meilleur moteur de retour quotidien — meilleur qu'un streak.
2. **Contrainte dure de génération : 96-98 % de mots connus.** Le prompt LLM doit recevoir le profil lexical (mots connus/en cours) et une liste de 3-7 mots cibles du jour, avec vérification post-génération (tokeniser le texte produit — mecab-ko/Kiwi —, calculer la couverture, régénérer si < 96 %). C'est le différenciateur méthodologique n°1 : aucune app ne vérifie réellement.
3. **Recyclage planifié** : chaque mot introduit doit réapparaître ~8-10 fois sur ~2-3 semaines dans les textes suivants (scheduler type FSRS qui pilote non pas des cartes mais la *liste de mots à réinjecter* dans le prompt du jour). C'est l'idée Lenguia, poussée à fond.
4. **Cold start intelligent** : initialiser le profil lexical avec la liste officielle 6 000 mots du 국립국어원 (niveaux A/B/C) + un test de placement par balayage (l'utilisateur marque les mots inconnus dans quelques échantillons) plutôt que compteur à zéro façon LingQ.

### UX (les invariants des apps qui marchent)
5. **Tap = définition + la carte se crée toute seule** avec phrase d'origine et audio (pattern Migaku/Satori). Aucune saisie manuelle, jamais.
6. **Audio TTS synchronisé phrase par phrase** (les voix coréennes neurales 2025-2026 sont largement suffisantes) avec vitesse réglable — l'utilisateur aime Didi Podcast : lui donner l'équivalent audio de chaque texte, écoutable en marchant.
7. **Tracking passif des mots connus** : un mot lu sans tap N fois de suite passe "connu" automatiquement ; le compteur de mots connus est affiché comme métrique de progrès (motivation LingQ) mais sans gestion manuelle.
8. **Flashcards en second rideau** : file de révision courte (5-10 cartes/jour max, algorithme FSRS, cloze en contexte façon Clozemaster plutôt que recto-verso), jamais de backlog culpabilisant — en cas d'absence, les cartes ratées redeviennent simplement des mots à réinjecter dans les histoires. C'est la réponse directe au problème n°1 d'Anki (l'avalanche post-pause).
9. **Pas de streak dur** : heatmap de constance façon Satori Reader, tolérante aux absences.

### Contenu et qualité coréenne
10. **Registre contrôlé** : générer en 해요체 par défaut (celui de la vie quotidienne parlée) avec option dialogues en registres mixtes — les LLM génériques se trompent souvent de registre, en faire un point de contrôle explicite.
11. **Vocabulaire "vie en Corée"** en plus de la fréquence : administration (주민센터, 전입신고), banque, santé, immobilier, small talk de voisinage — le vocabulaire que les listes TOPIK sous-pondèrent et dont un expat de 8 ans a précisément besoin.
12. **Contrôle qualité de la génération** : la leçon Beelinguapp — une passe de relecture LLM (self-critique ou second modèle) sur naturalité et registre avant publication, sinon la confiance s'érode vite.

### Positionnement
13. Lenguia prouve la demande (produit vivant à 30 $/mois) mais reste généraliste 36 langues. Molago, outil personnel, peut être **meilleur sur le coréen** précisément parce qu'il ne vise qu'une langue et une personne : profil lexical fin, sujets réels, registres justes. Si un jour il devient produit, le segment "résidents longue durée en Corée, hors K-culture" est identifié et vacant.

---

## Sources principales

- Hu & Nation (2000) ; Walker (1997) — seuil de couverture lexicale, via [The Language Gym](https://gianfrancoconti.com/2025/02/27/why-the-input-we-give-our-learners-must-be-95-98-comprehensible-in-order-to-enhance-language-acquisition-the-theory-and-the-research-evidence/)
- [Pellicer-Sánchez — Incidental vocabulary learning, eye-tracking (Cambridge)](https://www.cambridge.org/core/journals/bilingualism-and-cognition/article/abs/incidental-vocabulary-learning-in-a-natural-reading-context-an-eyetracking-study/9DE8BB8989973448A4245C87522D72C1) ; [Effects of word exposure frequency](https://www.researchgate.net/publication/231853789_The_Effect_of_Exposure_Frequency_on_Intermediate_Language_Learners'_Incidental_Vocabulary_Acquisition_and_Retention_through_Reading)
- [Frontiers in Education 2025 — test de l'input hypothesis avec IA](https://www.frontiersin.org/journals/education/articles/10.3389/feduc.2025.1614680/full)
- [TPRS — revue d'efficacité (Bethel)](https://spark.bethel.edu/cgi/viewcontent.cgi?article=1185&context=etd)
- LingQ : [Trustpilot](https://www.trustpilot.com/review/lingq.com), [FluentU](https://www.fluentu.com/blog/reviews/lingq/), [AllLanguageResources](https://www.alllanguageresources.com/lingq-review/)
- [Readlang Story Bot (forum officiel)](https://forum.readlang.com/t/new-story-bot-for-ai-generated-stories/1309)
- Du Chinese : [LTL](https://ltl-school.com/du-chinese/), [Ninchanese](https://ninchanese.com/blog/2022/10/18/du-chinese-review-of-a-great-graded-reader/)
- Satori Reader : [Tofugu](https://www.tofugu.com/reviews/satori-reader/), [How it works](https://www.satorireader.com/how-it-works)
- [Todaii Easy Korean (Google Play)](https://play.google.com/store/apps/details?id=mobi.eup.easykorean&hl=en_US)
- [Beelinguapp — Lingopie review](https://lingopie.com/blog/beelinguapp-review/)
- Migaku / Language Reactor : [funfluen comparatif](https://funfluen.com/learn/compare/language-reactor-vs-migaku/), [wordy.info](https://wordy.info/blog/migaku-alternatives)
- Anki : [Why People Quit Anki](https://my-senpai.com/insights/why-people-quit-anki.html), [Anki Burnout](https://my-senpai.com/insights/ankiburnout.html) ; FSRS : [MemoForge guide](https://memoforge.app/blog/fsrs-vs-sm2-anki-algorithm-guide-2025/)
- Clozemaster : [Refold — SRS that isn't Anki](https://refold.la/blog/srs-that-isnt-anki-clozemaster) ; Drops : [Mezzoguild](https://www.mezzoguild.com/drops-review/)
- Praktika : [Languatalk review](https://languatalk.com/blog/praktika-review/), [Trustpilot](https://www.trustpilot.com/review/praktika.ai) ; Teuida : [AllLanguageResources](https://www.alllanguageresources.com/teuida-app/), [5M downloads PR](https://markets.financialcontent.com/custercountychief/article/getnews-2025-12-10-teuida-passes-5m-downloads-as-it-expands-its-speaking-first-language-learning-platform-beyond-korean)
- Apps IA 2024-2026 : [Lenguia](https://www.lenguia.com/), [Gradia](https://play.google.com/store/apps/details?id=com.betapilot.gradia), [StoryLing](https://storyling.app/), [Comprehensible Later](https://twocentstudios.com/2025/11/15/comprehensible-later-read-it-later-for-language-learners/)
- Duolingo/gamification : [Business of Apps](https://www.businessofapps.com/data/duolingo-statistics/), [LingoBright stats](https://www.lingobright.com/statistics/language-learning-apps/), [dev.to — Shallow Learning Trap](https://dev.to/yaptech/duolingos-shallow-learning-trap-gamified-streaks-harmful-habits-4134)
- Liste 6 000 mots 국립국어원 : [TOPIK Guide](https://www.topikguide.com/korean-frequency-list-top-6000-words/), [fichier officiel](https://aflickerofkorean.wordpress.com/2018/10/27/6000-most-common-korean-words-found-the-official-list/)
- Open source : [Lute v3](https://github.com/jzohrab/lute), [LWT](https://github.com/HugoFara/lwt)
