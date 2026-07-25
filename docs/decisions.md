# Molago — journal des décisions produit

Interview produit du 25 juillet 2026. Une décision par ligne, dans l'ordre où elles
ont été prises. Ce fichier est la matière première de la spec finale.

## Contexte

Français vivant en Corée depuis 8 ans. Lit le hangul couramment, vocabulaire estimé
3 000–5 000 mots. Objectif : mieux parler avec les gens autour de lui. Déteste le
par-cœur. La pop culture coréenne ne l'intéresse pas. Travaille dans la tech.

## Contraintes techniques posées d'entrée

- **Front** : application native Apple (Swift).
- **Backend** : VPS personnel — Postgres + API en Docker, sur le modèle du projet `to-day`
  (Postgres 16 alpine, API Hono/Drizzle conteneurisée, exposition Traefik, auth par
  `OWNER_TOKEN` mono-utilisateur).
- **LLM** : OpenRouter.
- **Voix** : fournisseur séparé si besoin (OpenRouter ne fait que du texte).
- Pas de Supabase, pas de ffmpeg, pas de GitHub Actions.

## Décisions

### D1 — Le cœur du produit est le texte quotidien
Le carnet de mots personnels est un affluent, pas le fleuve. La capture doit être
quasi instantanée, et sa récompense est de voir le mot revenir dans un texte.

### D2 — Le contenu est du réel réécrit
Actualité, tech, société, science — des faits vrais remis au niveau de coréen de
l'utilisateur. Pas de fiction feuilletonnée : elle échouerait au test « l'aurais-tu
lu en français ? », et inventer une histoire attachante est la tâche la plus dure
pour un modèle, alors que reformuler un fait est la plus facile.

### D3 — L'utilisateur choisit son sujet parmi trois titres
Trois propositions le matin, issues d'**univers différents** (pas trois angles du
même sujet). Le choix coûte deux secondes et transforme l'attente de génération en
commande assumée.

### D4 — Les trois univers
| Slot | Univers | Rôle | Couche de langue |
|---|---|---|---|
| 1 | Tech & science | Le cerveau | Sino-coréen dense |
| 2 | Corée : actu & société | La conversation | Journalistique |
| 3 | Vie quotidienne à Séoul | L'utile | Parlé, 해요체 |

### D5 — Sources
- Slot 1 → sources internationales (Hacker News, presse tech).
- Slot 2 → presse coréenne (Yonhap, KBS, 한겨레) : lire ce que les gens autour de lui
  ont lu ce matin.
- Slot 3 → **les mots capturés par l'utilisateur**. Un mot attrapé dans la vraie vie
  devient le sujet du lendemain, remis en situation. Repli sur un fonds de situations
  d'expat quand le carnet est vide.

**Règle non négociable** : on part toujours d'un vrai article. Le modèle reçoit le
texte source et le réécrit — il ne raconte jamais l'actualité de mémoire.

### D6 — Un micro-quiz de 90 secondes clôt la lecture
Trois phrases du texte, un mot retiré, à remettre. Pas de note, pas de score, pas de
série. Justification : lire avec assistance produit une sensation de progrès
supérieure au progrès réel (Storyfier, UIST 2023) ; la récupération active donne 61 %
de rétention à une semaine contre 40 % pour la relecture.

### D7 — La session dure ~6 minutes, durée fixe et annoncée
Texte de ~300 mots coréens (3–4 min de lecture) + 90 s de quiz. La durée est affichée
avant d'ouvrir : c'est ce contrat qui fait revenir, plus que le contenu lui-même.
Un geste petit survit aux mauvais matins ; un geste long se fait repousser.

### D8 — Lecture et écoute simultanées par défaut
La voix part à l'ouverture, la phrase en cours est surlignée. Pause, réécoute d'une
phrase au tap, ralenti possible. Format le mieux soutenu par la recherche, et le seul
qui travaille la compréhension orale — là où l'utilisateur plafonne.
Réécoute sans écran : gratuite une fois l'audio produit.
*Plus tard, hors V1 : un mode conversation / discussion.*

### D9 — Calibration éclair, puis évaluation invisible
- **Jour 1** : ~30 mots du courant au rare, deux boutons (je connais / je connais pas),
  2 minutes, une seule fois.
- **Ensuite** : tap sur un mot = inconnu ; lu ≥5 fois sans tap sur ≥3 jours = connu ;
  raté au quiz = redescend. L'utilisateur ne déclare jamais rien.
- **Aucun mot ne sort du système.** « Connu » n'est pas un état final : les intervalles
  s'allongent (J+7, J+21, J+60…), ils ne s'arrêtent pas.

### D10 — Les révisions passent par deux canaux
Conséquence directe de D2 : un contenu réel ne se laisse pas tordre pour caser des mots.
1. Les mots dus sont **proposés** au générateur, jamais imposés — il les place si ça
   tombe naturellement.
2. Ceux qui ne passent pas vont **au quiz** : 2 questions sur le texte du jour,
   1 sur un mot ancien à revoir.
3. Un mot en attente depuis trop longtemps devient un **critère de choix du sujet** :
   à titres égaux, on retient celui dont l'article contient déjà des mots dus.

Le texte n'est jamais déformé ; le quiz est la soupape du système.

### D11 — Trois gestes de capture
**Photo** (le physique : factures, panneaux, menus, papiers administratifs),
**partage iOS** (le numérique, depuis n'importe quelle app), **saisie manuelle**.
Au moment de la capture, le sens s'affiche immédiatement — on capture souvent parce
qu'on a besoin de comprendre maintenant.

### D12 — Le carnet est un carnet de mémoire, pas une liste d'étude
Chaque mot : le sens, **la photo ou la phrase où il a été croisé**, la date, son état.
Cherchable. Aucune action à faire, aucun bouton « réviser », rien qui attende.
C'est le journal de ce que la Corée lui a appris.

Écartés : les flashcards optionnelles (dès qu'une pile révisable existe, elle produit
une dette — l'appeler optionnelle n'y change rien) et le dictionnaire généraliste
(Naver et Papago sont gratuits et ont vingt ans d'avance).

*À reprendre : un quiz déclenchable à la main, quand l'envie est là.*

### D13 — Toute capture passe par le même écran
Le texte extrait s'affiche avec **les mots inconnus surlignés**, le reste en gris.
L'utilisateur tape ceux qu'il garde ; ils entrent au carnet avec leur phrase comme
contexte. Un mot seul : les étapes se confondent.
Utile avant même d'apprendre — trois secondes pour voir ce qui bloque sur un papier
administratif. **OCR natif iOS** (Vision, coréen depuis iOS 16) : gratuit, hors ligne,
zéro dépendance. Faible sur le manuscrit uniquement.

*Écarté pour plus tard : transformer un article capturé en texte du jour.*

### D14 — Les hanja sont une clé de regroupement sémantique
Familles affichées au tap et dans le carnet ; à utilité égale, on privilégie les mots
qui **ouvrent une famille** (관리 en donne cinq). Jamais de leçon de caractères, jamais
de tracé, jamais de liste : le hanja n'apparaît que comme **explication d'un mot déjà
croisé**.

**Contrainte de correction** : le regroupement se fait sur le caractère chinois réel,
jamais sur la syllabe hangul — 사회 et 사장 partagent une syllabe et rien d'autre.
Le caractère reste discret (l'utilisateur ne lit pas le chinois) ; ce qu'on montre,
c'est le **sens partagé**.

### D15 — Les textes la nuit, la voix au fil de la lecture
Les deux morceaux n'ont pas le même coût : le texte vaut quelques centimes, la voix est
le poste cher. Donc :
- Les **trois textes complets** sont prêts avant l'heure choisie dans les réglages.
- Une **notification** annonce qu'ils sont là. La génération est calée sur cette heure,
  pas sur une heure fixe.
- La **voix se fabrique phrase par phrase** pendant la lecture, avec une longueur
  d'avance. Aucune attente, aucun gaspillage.
- Téléchargement complet de l'audio d'un geste pour l'usage hors ligne.

### D16 — Bibliothèque : on garde tout, on ne compte rien
Le danger n'est pas de conserver les textes, c'est de les compter. Une pastille
« 12 non lus » transforme un rayonnage en dette.
- Tout est conservé indéfiniment, les trois textes de chaque jour, audio compris.
- **Aucune pastille, aucun compteur, aucun rappel.** Une marque discrète sur les textes
  lus, pas un reproche sur les autres.
- Un texte relu garde ses mots tapés surlignés : constater qu'ils sont devenus
  transparents est la meilleure preuve de progrès possible, et elle est gratuite.

### D17 — Deux onglets, réglages sous l'avatar
- **Library** — les trois textes du jour en haut, l'historique en dessous. La
  bibliothèque n'est pas un lieu séparé : c'est ce qu'il y a plus bas. On descend dans
  le temps, on ne va pas dans ses retards.
- **Notebook** — les mots, avec une ligne discrète en tête (*1 240 words known*).
- **Pas d'onglet réglages** : l'avatar en haut ouvre les réglages. **Connexion Google**
  (même mécanisme que `to-day`) — le carnet et la progression suivent l'appareil.
- **Les réglages de lecture** (vitesse, voix) sont dans le lecteur, accessibles pendant
  la lecture. Pas enterrés dans les réglages généraux.
- La capture vient surtout de l'extérieur (appareil photo, partage iOS).

### D18 — Tout en anglais
Interface **et** contenu d'apprentissage : sens des mots, traductions, corrections du
quiz. Une seule langue dans l'app. Les ressources coréen-anglais sont nettement plus
riches que coréen-français, donc des définitions plus fiables.

### D19 — Écran du matin : trois cartes égales
Une carte par univers, avec sa couleur. Historique en dessous, dans le même flux.
**Pas de mention « from your notebook »** sur la carte : découvrir son propre mot en
lisant vaut mieux qu'une annonce.

### D20 — Sur la carte : la durée et la sensation, pas un chiffre
`4 min · easy going` plutôt que `320 words · 5 new`. Deux raisons :
- Le total de mots et le nombre de mots nouveaux ne sont pas sur la même échelle
  (occurrences vs mots distincts) — les rapprocher produit un calcul faux.
- La longueur ne varie pas (D7) : l'afficher trois fois n'aide jamais à choisir.

Comme le système vise toujours le même confort, **on n'affiche rien quand c'est
normal**. Le silence veut dire « comme d'habitude ».

### D21 — Écran de lecture : flux continu ou blocs, au choix
Réglage, pas arbitrage — même donnée, deux rendus.
- Taper un mot **met l'audio en pause**. Reprise manuelle par défaut, réglage pour
  une reprise automatique.
- La traduction d'une phrase entière existe mais demande un **geste délibéré**
  (appui long) : assez accessible pour débloquer, assez coûteuse pour ne pas devenir
  un réflexe. Disponible, jamais proposée.

### D22 — Le panneau de mot a trois étages
1. **Le sens seul** — mot, prononciation, nature, définition. C'est l'état par défaut.
2. **Trois phrases d'usage** — des phrases utilisables, pas des exemples de dictionnaire.
3. **La famille de racine en plein écran** — chaque mot avec sa traduction, ceux déjà
   connus marqués `KNOWN`. C'est là que le rangement mental se fait.

Le panneau **s'ouvre toujours à l'étage 1**. Pas de mémoire d'étage : la prévisibilité
vaut mieux que l'intelligence.

### D23 — Le swipe, deux directions et deux sens
- **Droite : Keep** — le mot entre au Notebook avec sa phrase comme contexte.
- **Gauche : I knew this** — corrige le moteur quand le tap venait de la curiosité et
  non de l'ignorance. Sans ce geste, le système resservirait pendant des semaines un
  mot déjà maîtrisé.
- Refermer sans rien faire reste le cas le plus courant.

**Distinction structurante** : taper un mot alimente le moteur (automatique, invisible) ;
le Notebook est une **collection choisie**. Si tout ce qui est tapé y atterrissait, ce
serait 800 mots en trois semaines et plus un carnet de mémoire.

### D24 — Le même swipe trie la capture
Après une photo, les mots inconnus extraits sont enchaînés au swipe : droite je garde,
gauche je passe. Six mots triés en six secondes. Le geste s'apprend une fois et sert
à deux endroits — et il tombe encore mieux ici, où il y a une pile à trier.

### D25 — Quiz mixte, format choisi selon la maturité du mot
- **Mot jeune** → choix multiple. Lui demander de l'écrire le matin même est injuste.
- **Mot mûr** (revu plusieurs fois sur plusieurs semaines) → saisie au clavier, parce
  que savoir écrire est une compétence à part que le choix multiple ne travaille jamais.

La difficulté monte donc toute seule à mesure que les mots mûrissent.

**Qualité des distracteurs** : même nature, même niveau, tirés du même texte. Quatre mots
au hasard rendent l'exercice inutile.

**Tolérance à la saisie** : espaces ignorés (le 띄어쓰기 piège même les Coréens) ; une
lettre à côté affiche « presque » et compte comme réussi. On teste la mémoire du mot,
pas la dextérité.

**Après la réponse** : le mot reprend sa place dans la phrase, la traduction apparaît,
on enchaîne. Juste ou faux, même traitement. Pas de « bravo », pas de score, pas de
récapitulatif final.

### D26 — Le Notebook est un journal
Par date, chaque mot avec **sa vignette, sa phrase de contexte et son jour**. Un point
coloré donne l'état, jamais un nombre à côté. Deux chiffres en tête seulement :
*148 words kept · 1 240 words known*.

Écartés : le tri par état (« New 12 » est un compteur, donc une dette — cf. D16) et le
mur de mots (dense mais sans contexte, ça redevient une liste de vocabulaire).

- **Icônes** : base **Thiings** de Pierre (9 000 objets, API Docker sur le port 3088,
  routes `/icons`, `/icons/:slug/image`). L'icône est choisie automatiquement en
  cherchant la traduction anglaise du mot dans les titres et tags — aucun appel LLM.
- **Recherche sémantique plutôt que filtres.** Le champ de recherche accepte le coréen,
  l'anglais, mais aussi une **nature** (`noun`, `adjective`) ou un **domaine**
  (`housing`, `real estate`). Implémentation : le modèle produit déjà la traduction au
  moment de la capture — il émet en plus la nature et 1 à 3 tags de domaine, et la
  recherche fait une correspondance simple. Passer aux embeddings seulement si les
  synonymes posent problème.

### D27 — Une jauge de confiance par mot (inspirée de Strava)
« Connu / pas connu » est trop grossier : entre *jamais vu* et *je le sors tout seul*,
il y a des marches distinctes qui sont justement là où l'apprentissage se passe.

Quatre paliers, qui correspondent à des compétences réelles :
`Not yet` → `I recognise it` (à la lecture) → `I understand it` (aussi à l'oral) →
`I can use it` (il vient tout seul).

Deux idées reprises de Strava :
- **L'utilisateur s'auto-évalue** — lui seul sait s'il emploierait le mot spontanément ;
  aucune observation de taps ne répond à ça.
- **Le système affiche son estimation à côté** (zone en pointillés, équivalent du
  « based on available HR data »). L'écart entre les deux est visible d'un coup d'œil.

**Où** : dans le Notebook, à l'ouverture d'un mot. Pas pendant la lecture — là, le swipe
binaire reste le bon geste. La jauge est pour le moment posé.

### D28 — GPT-5.1 génère, un modèle coréen natif vérifie
Pas de bouton « ça sonne bizarre » dans l'écran de lecture : une app qui demande à
l'utilisateur de signaler sa mauvaise qualité avoue ne pas se faire confiance, et le
doute contamine tout le texte. La vérification est faite par la machine, avant publication.

**Division du travail** — juger et corriger sont deux tâches différentes :
- **Juger** (« un Coréen dirait-il ça ? ») relève de l'intuition de langue : un modèle
  nourri massivement de coréen y est meilleur, même plus petit.
- **Corriger** (reformuler en respectant vocabulaire, registre, longueur) relève du
  suivi de consignes : le modèle frontière gagne.

Donc : le modèle coréen **détecte et annote**, GPT-5.1 **réécrit**.

**Contrainte de licence** : version commerciale envisagée → aucune dépendance non
commerciale. Cela **écarte EXAONE** (licence NC), pourtant le meilleur ouvert.
Vérificateur à trancher au branchement : HyperCLOVA X (API Naver, tarifs non publics),
Upstage Solar, ou A.X — licences à vérifier.

**Troisième couche, la plus fiable : le contrôle déterministe.** Une analyse
morphologique (Kiwi, en conteneur) vérifie que le vocabulaire est dans le niveau de
l'utilisateur. Ce n'est pas un jugement, c'est un calcul — c'est ce qui garantit qu'un
texte trop dur n'est jamais publié.

**Limite des benchmarks** : KMMLU, CLIcK, KAIO mesurent ce qu'un modèle *sait* en
coréen, jamais si un texte *sonne écrit par un Coréen*. Aucun classement ne répond à
notre question.

### D29 — Mono-utilisateur par la liste blanche, multi-utilisateur par l'architecture
Connexion Google, **`user_id` sur chaque table dès le premier jour**, liste blanche
n'autorisant que le compte de Pierre. L'app se comporte comme une app multi-utilisateur ;
il se trouve qu'il n'y a qu'un compte autorisé.

Reprendre après coup une base construite sans `user_id` obligerait à réécrire chaque
requête — c'est la seule migration réellement coûteuse, et dix minutes la suppriment.

**Explicitement hors périmètre** : paiement, inscription publique, quotas,
administration, support. Et surtout l'arbitrage « textes uniques ou mutualisés par
niveau », qui ne se tranche pas avant de savoir si les gens aiment lire ces textes.

*Note d'économie pour plus tard* : la personnalisation par utilisateur ne connaît aucune
économie d'échelle — plancher de l'ordre de 5 à 15 €/utilisateur/mois en coût brut,
quand LingQ se vend 13 € et Duolingo est gratuit. La sortie serait de mutualiser les
textes par bande de niveau en ne personnalisant que glossaire et quiz.

### D30 — Modèle et voix tranchés à l'oreille, pas sur des scores
Une séance d'essai comparatif à l'aveugle, avant toute ligne de code :
- **Texte** : le même article réécrit par plusieurs candidats, lus sans savoir qui est qui.
- **Voix** : le même paragraphe coréen lu par plusieurs fournisseurs.

Coûts mensuels pour ~27 000 caractères (un texte lu par jour) : Naver CLOVA Voice
~0,08 € · OpenAI TTS ~0,40 € · ElevenLabs ~5 €. **Le coût n'est pas un critère.**

Deux points contre-intuitifs : ElevenLabs n'est excellent que sur une dizaine de langues,
avec une contamination d'accent anglophone signalée en coréen ; et Naver CLOVA Voice
est un TTS coréen natif à un soixantième du prix, dont la limite documentée (pas de flux
temps réel) ne nous concerne pas puisqu'on génère par phrases courtes.

### D31 — Tout est prêt d'avance, audio compris *(révise D15)*
La D15 protégeait une économie qui n'existe pas : tripler la voix fait passer de 0,08 €
à 0,24 € par mois. Et elle coûtait cher ailleurs — dépendance au réseau pendant la
lecture (le métro, précisément là où on écouterait) et orchestration délicate à écrire.

**Les trois textes et leurs trois voix** sont prêts avant l'heure choisie et téléchargés
sur le téléphone à la notification. Lecture entièrement hors ligne, zéro attente.

**Cas d'échec, simplifiés d'autant** :
- Génération ratée → la notification ne part pas ; à l'ouverture, l'app le dit franchement
  et propose de relancer. La bibliothèque reste disponible.
- Pas de réseau le matin → aucune différence, tout est déjà là.
- Un texte n'atteint pas le niveau visé après réécritures → il n'est pas publié, on n'en
  propose que deux. Deux bons textes valent mieux que trois dont un mauvais.

## En suspens

- « Une phrase à réutiliser aujourd'hui » en fin de session — écarté au profit du
  quiz, à reconsidérer en complément.
- Sérialisation : est-ce qu'un sujet peut durer plusieurs jours ?
- Mode conversation / discussion orale (post-V1).
- Quiz déclenchable manuellement, à la demande.
- Contrôle de la vitesse de lecture, avec le **mot en cours** surligné (pas seulement
  la phrase) — pour se pousser progressivement plus vite.
- Transformer un article capturé en texte du jour.
