# Molago — spécification produit

*Version 1 · 25 juillet 2026 · issue de l'entretien de conception du même jour.*
*Source des arbitrages : [`decisions.md`](decisions.md) (31 décisions). Base de recherche : [`research/`](research/).*

**Statut : spécification produit validée. Aucun code écrit. La direction visuelle
(couleurs, typographie, identité) fera l'objet d'une session distincte — ce document
décrit la structure et le comportement, pas l'apparence finale.**

---

## 1. Le produit en une phrase

Chaque matin, quatre textes coréens sur des sujets qui intéressent réellement
l'utilisateur, calibrés sur son vocabulaire, lus à voix haute — et les mots qu'il croise
dans sa vie à Séoul reviennent dedans.

## 2. Pour qui

Un Français vivant en Corée depuis huit ans. Il lit le hangul couramment, possède
3 000 à 5 000 mots, et veut **mieux parler avec les gens autour de lui**. Il déteste le
par-cœur, la pop culture coréenne ne l'intéresse pas, et il travaille dans la tech.

Son problème n'est pas de commencer le coréen — c'est de sortir du plateau où s'installent
les résidents de longue durée : assez à l'aise pour vivre, jamais assez pour la
conversation à plusieurs, le téléphone, ou la nuance.

## 3. Les principes non négociables

| # | Principe | Conséquence concrète |
|---|---|---|
| P1 | **Le contenu est le produit, la langue est le véhicule** | Le test de validation : « l'aurais-tu lu si c'était en français ? » |
| P2 | **Le niveau est garanti par un calcul, pas par un jugement** | Analyse morphologique déterministe avant publication. Un texte hors niveau n'est pas publié. |
| P3 | **La répétition espacée est invisible** | Elle vit dans les textes et le quiz. Jamais de pile de cartes. |
| P4 | **Zéro dette, zéro culpabilité** | Aucun compteur de non-lus, aucune série à tenir, une seule notification par jour. |
| P5 | **Un effort minimal mais réel** | 90 secondes de récupération active par jour. Lire seul ne suffit pas. |
| P6 | **L'unité est le chunk, pas le mot isolé** | Les exemples sont des phrases utilisables, les collocations sont enseignées. |
| P7 | **L'app ne doute jamais devant l'utilisateur** | Pas de bouton « signaler une mauvaise phrase ». La qualité se contrôle avant publication. |
| P8 | **Le système observe, il n'interroge pas** | Le profil se construit par les taps et les lectures, pas par des déclarations. |

---

## 4. Le parcours quotidien

### 4.1 Pendant la nuit — invisible

À une heure calculée pour finir avant l'heure choisie par l'utilisateur, la chaîne de
fabrication produit **quatre textes complets et leurs voix** (voir §9). Le résultat
est déposé sur le serveur.

### 4.2 La notification

Une seule par jour, à l'heure réglée par l'utilisateur.

> **Molago**
> *Why Korean chipmakers are betting everything on HBM4* — and 2 more

Elle annonce quelque chose à lire, elle ne réclame rien. Formulations proscrites :
« Don't forget », « Your streak », « You haven't read today ». **C'est la seule
notification de l'application** — aucun rappel, aucune relance.

Au moment où elle arrive, le téléphone télécharge les quatre textes et leurs audios.

### 4.3 L'ouverture — 5 secondes

L'onglet **Library** s'ouvre sur les quatre textes du jour, quatre cartes égales, une par
univers. Chacune porte :

- une étiquette d'univers colorée (`News`, `Tech`, `Fun`, `Life`) ;
- un titre en anglais ;
- une ligne d'information : `4 min` — et rien d'autre si la difficulté est normale,
  `4 min · a bit of a stretch` ou `4 min · easy going` quand elle sort de l'ordinaire.

**Ce qui n'apparaît jamais sur la carte** : le nombre total de mots (il ne varie pas), le
nombre de mots nouveaux (ambigu, et il fait faire un calcul faux), l'origine du sujet
(« from your notebook » — la découverte en lisant vaut mieux qu'une annonce).

En dessous, sans séparation ni changement d'écran, **l'historique** : les jours
précédents, leurs quatre textes chacun, indéfiniment. On descend dans le temps.

### 4.4 La lecture — 3 à 4 minutes

L'utilisateur tape une carte. Le texte s'affiche **instantanément** (tout est déjà sur
l'appareil) et **la voix démarre**.

- Le texte fait ~300 mots coréens, en 해요체 naturel pour le registre parlé, en style
  journalistique léger pour l'actualité.
- **La phrase en cours de lecture est surlignée** et suit la voix.
- Deux dispositions au choix dans les réglages : **flux continu** (le texte comme un
  article) ou **blocs phrase par phrase**.
- Taper une phrase déplace la lecture à cet endroit.
- **Aucun mot n'est marqué visuellement comme nouveau** — ça casserait le flux et
  transformerait la lecture en exercice.

**Taper un mot** ouvre le panneau de mot (§5.3) et **met la voix en pause**. À la
fermeture, la lecture reprend manuellement — ou automatiquement si le réglage est activé.

**Appui long sur une phrase** : sa traduction complète. Volontairement plus coûteuse
qu'un tap. La traduction de phrase est *disponible*, jamais *proposée* — si elle était à
un tap, elle deviendrait un réflexe, et l'utilisateur lirait l'anglais plutôt que le
coréen.

### 4.5 Le quiz — 90 secondes

Trois questions, construites sur **les phrases du texte qui vient d'être lu**.

- **Format choisi par mot** : choix multiple pour un mot jeune, **saisie au clavier**
  pour un mot mûr (revu plusieurs fois sur plusieurs semaines). Savoir écrire est une
  compétence distincte que le choix multiple ne travaille jamais ; la difficulté monte
  donc toute seule à mesure que les mots mûrissent.
- **Deux questions portent sur le texte du jour, une sur un mot ancien à revoir** (§7).
- **Distracteurs** : même nature grammaticale, même bande de fréquence, **tirés du même
  texte**. Quatre mots au hasard rendent l'exercice inutile.
- **Tolérance à la saisie** : les espaces sont ignorés (le 띄어쓰기 piège même les
  Coréens) ; une lettre à côté affiche `almost — it was 관리비` et **compte comme
  réussi**. On teste la mémoire du mot, pas la dextérité au clavier.

**Après chaque réponse** : le mot reprend sa place dans la phrase, la traduction
apparaît, on enchaîne. Juste ou faux, **exactement le même traitement**.

**À la fin** : rien. Pas de score, pas de récapitulatif, pas de « bravo ». L'écran se
ferme, la journée commence.

---

## 5. Les écrans

### 5.1 Structure générale

Deux onglets seulement.

```
┌──────────────────────────────┐
│  Library            [avatar] │   ← l'avatar ouvre les réglages
│  ──────────────────────────  │
│  SATURDAY 25 JULY            │
│  ┌────────────────────────┐  │
│  │ TECH & SCIENCE         │  │
│  │ Why Korean chipmakers… │  │
│  │ 4 min                  │  │
│  └────────────────────────┘  │
│  ┌────────────────────────┐  │
│  │ KOREA                  │  │
│  │ Seoul raises the…      │  │
│  │ 4 min · a bit of a…    │  │
│  └────────────────────────┘  │
│  ┌────────────────────────┐  │
│  │ DAILY LIFE             │  │
│  │ When the building…     │  │
│  │ 3 min                  │  │
│  └────────────────────────┘  │
│  EARLIER                     │
│  Friday · The rice price…  ✓ │
│  Friday · Chip export…       │
│  …                           │
│  ──────────────────────────  │
│  [ Library ]   [ Notebook ]  │
└──────────────────────────────┘
```

**Il n'y a pas d'onglet réglages** : l'avatar en haut à droite les ouvre. Les réglages de
lecture, eux, sont dans le lecteur — accessibles au moment où on en a besoin.

**Il n'y a pas d'onglet bibliothèque** : l'archive est la suite du fil d'aujourd'hui.
Séparer les deux créerait un endroit où s'accumule ce qu'on n'a pas fait.

### 5.2 Le lecteur

```
┌──────────────────────────────┐
│  ‹      DAILY LIFE       Aa  │   ← Aa = réglages de lecture
│  When the building manager…  │
│  4 min                       │
│  ──────────────────────────  │
│  이번 달 관리비 고지서를 받고 │
│  깜짝 놀랐어요. ▓지난달보다   │   ← ▓ = phrase en cours
│  삼만 원이나 올랐거든요.▓     │
│  관리사무소에 전화해서…       │
│                              │
│  ──────────────────────────  │
│  ❚❚  ▬▬▬▬▬▬▭▭▭▭▭    1.0×    │
└──────────────────────────────┘
```

**Réglages de lecture** (bouton `Aa`, quatre lignes) : vitesse de la voix, flux continu
ou blocs, reprise automatique après le panneau de mot, taille du texte.

### 5.3 Le panneau de mot — trois étages

Il s'ouvre **toujours au premier étage**. Il ne se souvient pas d'où on l'avait laissé :
la prévisibilité vaut mieux que l'intelligence.

**Étage 1 — le sens, point.** C'est l'état par défaut, celui qu'on veut en pleine lecture.

```
┌──────────────────────────────┐
│            ▬▬▬               │
│  관리비                       │
│  gwan-ri-bi · noun           │
│                              │
│  maintenance fee — the       │
│  monthly charge for a        │
│  building's shared costs     │
│  ──────────────────────────  │
│  ← I knew this   Examples ⌃  │
│                     Keep →   │
└──────────────────────────────┘
```

**Étage 2 — trois phrases d'usage** (en tirant le panneau vers le haut). Des phrases
utilisables le soir même, pas des exemples de dictionnaire.

```
관리비가 또 올랐어요.
  The maintenance fee went up again.
관리비에 수도 요금도 포함돼요?
  Does the fee include the water bill too?
이번 달 관리비 고지서 받으셨어요?
  Did you get this month's bill?

  [ Same root 管理 · 8 words  › ]
```

**Étage 3 — la famille de racine, en plein écran.** Chaque mot avec sa traduction, et
**ceux déjà connus marqués `KNOWN`**. C'est là que le rangement mental se fait :
découvrir que 관리자 et 관리하다, utilisés tous les jours, sont le même bloc que le mot
sur lequel on séchait.

```
‹ 관리비          管理 · to manage

관리하다   KNOWN      to manage, look after
관리자     KNOWN      manager, administrator
관리비                maintenance fee
관리사무소            building management office
관리직                managerial position
품질관리   KNOWN      quality control
자기관리              self-discipline
```

**Règle de correction impérative** : le regroupement se fait sur le **caractère chinois
réel**, jamais sur la syllabe hangul. 사회 et 사장 partagent une syllabe et rien d'autre —
les regrouper produirait des familles absurdes. Le caractère reste discret : l'utilisateur
ne lit pas le chinois, ce qu'on lui montre c'est le **sens partagé**.

### 5.4 Les deux gestes de swipe

| Geste | Effet | Pourquoi |
|---|---|---|
| **Droite — `Keep`** | Le mot entre au Notebook avec sa phrase comme contexte | C'est l'utilisateur qui décide ce qui mérite d'être gardé |
| **Gauche — `I knew this`** | Corrige le moteur : le tap venait de la curiosité, pas de l'ignorance | Sans ce geste, le système resservirait pendant des semaines un mot maîtrisé |
| **Fermer** | Rien | Le cas le plus fréquent, et c'est normal |

**Distinction structurante** : *taper* un mot alimente le moteur — c'est automatique et
invisible. Le *Notebook* est une **collection choisie**. Si tout ce qui est tapé y
atterrissait, ce serait 800 mots en trois semaines et plus un carnet de mémoire.

### 5.5 Le Notebook — un journal

```
┌──────────────────────────────┐
│  Notebook           [avatar] │
│  148 words kept · 1 240 known│
│  ┌────────────────────────┐  │
│  │ 🔍 Search your words…  │  │
│  └────────────────────────┘  │
│  YESTERDAY · FROM A PHOTO    │
│  [🧾] 관리비 ●                │
│       maintenance fee        │
│       "이번 달 관리비 고지서…" │
│  [🧾] 연체료 ●                │
│       late payment fee       │
│       same bill              │
│  3 DAYS AGO · WHILE READING  │
│  [가] 회식 ●                  │
│       company dinner         │
│       "금요일에 회식이 있어요" │
│  ──────────────────────────  │
│  [ Library ]   [ Notebook ]  │
└──────────────────────────────┘
```

Chaque mot porte **sa vignette, sa phrase de contexte et son jour**. Un point coloré
donne l'état — jamais un nombre à côté.

**Les icônes viennent de la base Thiings** de l'utilisateur : 9 000 objets, API Docker
existante sur le port 3088, routes `/icons` et `/icons/:slug/image`. L'icône est choisie
automatiquement en cherchant la traduction anglaise du mot dans les titres et les tags —
aucun appel à un modèle.

**La recherche remplace les filtres.** Le champ accepte :

- du coréen (`관리`) ou de l'anglais (`fee`) ;
- une **nature grammaticale** (`noun`, `adjective`, `verb`) ;
- un **domaine sémantique** (`housing`, `real estate`, `health`, `admin`).

*Implémentation* : au moment de la capture, le modèle produit déjà la traduction — il
émet en plus la nature et 1 à 3 tags de domaine. La recherche fait une correspondance
simple sur ces champs. Passer aux embeddings **seulement si** les synonymes posent
réellement problème.

**Écartés** : le tri par état (`New 12` est un compteur, donc une dette) et le mur de
mots (dense mais sans contexte — ça redevient une liste de vocabulaire).

### 5.6 La fiche d'un mot et la jauge de confiance

Ouvrir un mot du Notebook donne sa fiche, avec une **jauge d'auto-évaluation** inspirée
du « Perceived Exertion » de Strava.

```
┌──────────────────────────────┐
│  ‹ Notebook              ··· │
│           [🧾]                │
│          관리비               │
│       maintenance fee        │
│                              │
│    How well do you know it?  │
│         I recognise it       │
│   You get it when you read   │
│   it, but it wouldn't come   │
│   to you on its own.         │
│                              │
│  ▬▬▬▬▬▬▬▬▬◉▬┊▬▬▬▬▬▬▬▬▬▬▬▬   │
│  NOT YET  RECOGNISE  USE IT  │
│   MOLAGO'S ESTIMATE — DASHED │
└──────────────────────────────┘
```

Quatre paliers, qui correspondent à des **compétences réellement distinctes** :

| Palier | Signification |
|---|---|
| `Not yet` | Jamais vu, ou vu sans rien en retenir |
| `I recognise it` | Clair à la lecture |
| `I understand it` | Clair aussi à l'oral |
| `I can use it` | Il vient tout seul en parlant |

Deux idées reprises de Strava :

1. **L'utilisateur s'auto-évalue.** Lui seul sait s'il emploierait le mot spontanément —
   aucune observation de taps ne peut répondre à ça.
2. **Le système affiche son estimation à côté** (la zone en pointillés, équivalent du
   « based on available HR data »). L'écart entre les deux se voit d'un coup d'œil.

**Où, et où pas** : dans le Notebook, au repos. **Pas pendant la lecture** — là, le swipe
binaire reste le bon geste, rapide et sans réflexion.

### 5.7 La capture

Trois portes d'entrée, **un seul écran de tri**.

| Geste | Couvre |
|---|---|
| **Photo** | Le physique : factures, panneaux, menus, papiers administratifs |
| **Partage iOS** | Le numérique : KakaoTalk, sites, n'importe quelle app |
| **Saisie manuelle** | Le reste |

*L'OCR est natif iOS* (framework Vision, coréen depuis iOS 16) : gratuit, hors ligne,
instantané, aucune dépendance. Sa seule faiblesse est le manuscrit.

**Le tri.** Le texte extrait s'affiche avec **les mots inconnus surlignés**, le reste en
gris. C'est utile avant même d'apprendre : trois secondes pour voir ce qui bloque sur un
papier administratif.

Les mots candidats s'enchaînent ensuite **au swipe** — le même geste qu'en lecture :
droite je garde, gauche je passe. Six mots triés en six secondes.

Si un seul mot a été capturé, les étapes se confondent : **le sens s'affiche
immédiatement**. On capture souvent parce qu'on a besoin de comprendre maintenant, devant
sa facture.

### 5.8 La calibration du premier jour

Une trentaine de mots, du très courant au rare, deux gros boutons `I know it` /
`I don't`. **Deux minutes, une seule fois dans sa vie.**

Un bouton `Skip` existe : l'app part alors d'une hypothèse et se corrige en quelques
jours par les taps. On échange de la précision contre l'absence d'un mur à franchir le
jour où l'envie est maximale.

*Principe* : les réponses tracent une frontière sur une liste de fréquence du coréen. En
dessous, connu ; au-dessus, inconnu ; entre les deux, une zone grise. C'est cette
frontière qui pilote le choix des mots nouveaux.

### 5.9 Le quiz à la demande

Une action discrète dans le Notebook : cinq questions sur les mots en cours. **Jamais
annoncée, jamais comptée, aucune pastille.** Elle est là si l'envie prend dans le métro,
elle ne réclame rien.

---

## 6. Le moteur de vocabulaire

### 6.1 Comment le système apprend, sans jamais demander

| Signal | Interprétation |
|---|---|
| Tap sur un mot | Il ne le connaît pas |
| Swipe gauche après un tap | Il le connaissait — annuler le signal précédent |
| Lu ≥ 5 fois sans tap, sur ≥ 3 jours distincts | Il le connaît |
| Réussi au quiz | Confirmation, l'intervalle s'allonge |
| Raté au quiz | Il redescend, réapparaît sous peu |
| Auto-évaluation dans le Notebook | Prime sur l'estimation du système |

**Aucune déclaration n'est jamais demandée à l'utilisateur.**

### 6.2 « Connu » n'est pas un état final

Un mot ne sort **jamais** du système. Les intervalles s'allongent — une semaine, puis
trois, puis deux mois — ils ne s'arrêtent pas. Un mot vu cinq fois en trois jours est
connu *aujourd'hui* ; sans le recroiser, il s'efface.

---

## 7. Les révisions — deux canaux

C'est la conséquence directe du choix d'un contenu réel : **un fait vrai ne se laisse pas
tordre pour caser des mots.** Une fiction inventée obéirait ; un article sur une réforme
du travail, non. Et l'espace est compté : 300 mots, dont il faut déjà loger 3 à 8 mots
nouveaux.

1. **Le texte, en priorité.** Les mots dus sont **proposés** au générateur, jamais
   imposés : *« place ceux-ci si ça tombe naturellement, n'en force aucun »*. Trois ou
   quatre passent tout seuls, parce que les mots dus sont souvent des mots courants.
2. **Le quiz, en filet.** Ceux qui ne sont pas passés y vont — une question sur trois.
3. **Le choix du sujet, en dernier recours.** Un mot en attente depuis trop longtemps
   devient un critère : à titres également intéressants, on retient celui dont l'article
   contient déjà des mots dus. Le sujet reste vrai, on a seulement choisi le plus utile.

**Le texte n'est jamais déformé. Le quiz est la soupape.**

---

## 8. Le contenu

### 8.1 Nature

**Du réel réécrit.** Des faits vrais, remis au niveau de coréen de l'utilisateur.

Pas de fiction feuilletonnée, bien que la recherche la soutienne (effet Zeigarnik,
sérialisation). Deux raisons décisives : elle échouerait au test « l'aurais-tu lu en
français ? » pour quelqu'un qu'aucune fiction coréenne n'attire ; et **inventer une
histoire attachante est la tâche la plus dure pour un modèle, alors que reformuler un
fait est la plus facile**. On place le risque là où il est le plus faible.

**Règle impérative : on part toujours d'un vrai article.** Le modèle reçoit le texte
source et le réécrit. Il ne raconte **jamais** l'actualité de mémoire — il inventerait.

### 8.2 Les quatre univers *(trois jusqu'à §41 des décisions)*

| Slot | Univers | Source | Rôle | Couche de langue |
|---|---|---|---|---|
| 1 | **News** | Presse coréenne (Yonhap, 동아일보) | La conversation | Journalistique |
| 2 | **Tech** | Sources internationales (Hacker News, presse tech) | Le cerveau | Sino-coréen dense |
| 3 | **Fun** | Culture et divertissement (Yonhap, 동아일보) | La sortie | Parlé et léger, 해요체 |
| 4 | **Life** | **Les mots capturés par l'utilisateur** | L'utile | Parlé, 해요체 |

Le quatuor est délibéré : il n'y a **pas quatre fois de l'actualité**. Un slot pour le
cerveau, un pour la conversation, un pour ce dont on parle le vendredi soir, un pour la
vie. Et chacun travaille une couche différente du coréen — c'est précisément l'écart entre
ces couches qui fait plafonner les résidents de longue durée.

**Le slot 2 vise le rendement conversationnel** : lire ce que les gens autour de lui ont
lu ce matin.

**Le slot 3 ferme la boucle de la capture.** Un mot attrapé sur une facture devient le
sujet du lendemain, remis en situation avec tout le vocabulaire qui l'entoure. Quand le
carnet est vide, il tourne sur un fonds de situations d'expat : la pharmacie, le service
client, la banque, le taxi, le voisinage.

### 8.3 Format

- **~300 mots coréens**, 3 à 4 minutes de lecture.
- **3 à 8 mots nouveaux**, jamais plus.
- Registre adapté au slot.
- **Durée fixe et annoncée** avant l'ouverture. C'est ce contrat qui fait revenir, plus
  que le contenu lui-même.

---

## 9. La chaîne de fabrication nocturne

Elle tourne une fois par jour, calée pour finir avant l'heure de notification de
l'utilisateur. Elle est **idempotente** : relancée, elle reprend sans dupliquer.

```
┌─ 1. COLLECTE ────────────────────────────────────────┐
│  Slots 1 et 2 : flux RSS → articles du jour          │
│  Slot 3 : mots capturés en attente → situation       │
└──────────────────────────────────────────────────────┘
                        ↓
┌─ 2. CHOIX DU SUJET ──────────────────────────────────┐
│  Un candidat par slot. À intérêt égal, on privilégie │
│  l'article contenant déjà des mots dus.              │
└──────────────────────────────────────────────────────┘
                        ↓
┌─ 3. SÉLECTION DU VOCABULAIRE ────────────────────────┐
│  • 3 à 8 mots nouveaux : fréquence × pertinence      │
│    situationnelle × rendement de famille (hanja)     │
│  • mots dus : proposés, jamais imposés               │
└──────────────────────────────────────────────────────┘
                        ↓
┌─ 4. GÉNÉRATION — GPT-5.1 ────────────────────────────┐
│  Article source + vocabulaire cible + registre       │
│  + exemples de vrai coréen parlé → texte de 300 mots │
└──────────────────────────────────────────────────────┘
                        ↓
┌─ 5. CONTRÔLE DÉTERMINISTE — sans modèle ─────────────┐
│  Analyse morphologique (Kiwi) → lemmes → comparaison │
│  au profil. Niveau atteint ? sinon → retour en 4     │
│  (2 tentatives max)                                  │
└──────────────────────────────────────────────────────┘
                        ↓
┌─ 6. VÉRIFICATION DE NATURALITÉ ── SUPPRIMÉE ─────────┐
│  Prévue avec un modèle coréen natif. L'essai §14 a   │
│  montré que le seul candidat commercial disponible   │
│  écrit ET juge moins bien que le générateur retenu.  │
│  Étape retirée. Détail en §9.1.                      │
└──────────────────────────────────────────────────────┘
                        ↓
┌─ 7. ANNOTATION ──────────────────────────────────────┐
│  Découpage en mots tappables · glossaire ·           │
│  collocations · 3 exemples par mot · famille hanja   │
└──────────────────────────────────────────────────────┘
                        ↓
┌─ 8. QUIZ ────────────────────────────────────────────┐
│  3 questions · distracteurs de même nature et bande, │
│  tirés du texte · format selon la maturité du mot    │
└──────────────────────────────────────────────────────┘
                        ↓
┌─ 9. VOIX ────────────────────────────────────────────┐
│  Une piste par phrase, pour les TROIS textes         │
└──────────────────────────────────────────────────────┘
                        ↓
┌─ 10. PUBLICATION ────────────────────────────────────┐
│  Écriture transactionnelle · notification            │
│  Un texte qui n'a pas passé l'étape 5 n'est pas      │
│  publié — on en propose deux.                        │
└──────────────────────────────────────────────────────┘
```

### 9.1 Pourquoi l'étape 6 a disparu

*Cette section décrivait une répartition entre deux modèles. L'essai du 27 juillet 2026
(§14) l'a invalidée.*

Le raisonnement initial était que *juger* — « un Coréen dirait-il ça ? » — relève de
l'intuition de langue, et qu'un modèle nourri massivement de coréen y serait meilleur
même en étant plus petit ; tandis que *corriger* relève du suivi de consignes, où le
modèle frontière gagne.

**Les deux moitiés se sont révélées fausses en pratique.** Sur cinq réécritures du même
article, jugées à l'aveugle par trois modèles en trois passages chacun :

- `upstage/solar-pro-3`, seul modèle coréen natif à licence commerciale disponible,
  **finit dernier à écrire du coréen** — 4,3/10 contre 8,8 pour le vainqueur. Les juges
  citent des anglicismes (`톱 3`), de l'argot de jeu collé à des verbes formels
  (`'치킨'을 성사시키다`), et une hallucination franche : une référence à la rhétorique
  de Trump insérée dans un article sur un tournoi d'e-sport.
- Il est aussi **le juge le moins fiable** : ±2,5 à ±3 points de dispersion sur des
  passages strictement identiques, contre ±0 pour les deux autres juges.

Un vérificateur qui écrit moins bien que le générateur et dont les verdicts ne sont pas
reproductibles n'apporte rien. L'étape est retirée : un fournisseur, un contrat, une
étape et de la latence en moins chaque nuit.

**Leçon de méthode, valable partout ailleurs dans le pipeline** : un seul appel de
jugement par un modèle ne mesure rien. Le même juge a noté le même texte 4/10 puis 9/10.
Toute évaluation par modèle doit faire plusieurs passages et moyenner — ou ne pas exister.

### 9.2 Le contrôle déterministe est la garantie la plus solide

L'étape 5 n'est **pas** un jugement, c'est un calcul : analyse morphologique, extraction
des lemmes, comparaison au profil. Elle est exacte, gratuite, reproductible. C'est elle
qui garantit qu'un texte trop dur n'est jamais publié — aucun modèle n'a autorité sur ce
point.

### 9.3 Le choix des modèles — tranché

**Génération : `openai/gpt-5.1`.** Le pari initial de cette section est confirmé par
l'essai. Meilleure note de naturalité (8,8/10 de moyenne, avec **±0 de dispersion** sur
trois passages chez deux juges sur trois) *et* le moins cher du haut de tableau :
**1,31 €/mois** pour trois textes par nuit (quatre depuis §41 des décisions), contre 4,14 € pour GPT-5.5 qui le suivait à
8,5. Compatible avec un usage commercial.

**Vérification : aucune.** Voir §9.1.

**Voix : Google Cloud TTS, `ko-KR-Chirp3-HD-Achernar`.** Retenue à l'écoute comparée. Elle
ne renvoie aucun repère temporel : le début de chaque 어절 est estimé depuis la durée réelle
de la phrase, à 0,11 s près (§39 des décisions, qui révise §36). **0 €/mois** : la consommation est de ~93 000 caractères par
mois, le palier gratuit de Google est à 1 million, sans expiration.

**Limite qui reste vraie** : KMMLU, CLIcK et KAIO mesurent ce qu'un modèle *sait* en
coréen — histoire, droit, sciences. **Aucun ne mesure si un texte sonne écrit par un
Coréen.** C'est pourquoi il a fallu un essai maison. En revanche, l'hypothèse que
« seule l'oreille de l'utilisateur le peut » s'est révélée fausse pour l'écrit : elle
demande plus de coréen que n'en a l'utilisateur, ce qui est précisément le problème que
ce produit existe pour résoudre. Elle reste vraie pour l'audio, tranché en une écoute.

---

## 10. Modèle de données

Chaque table porte un `user_id` **dès le premier jour**.

| Table | Contenu |
|---|---|
| `users` | Compte Google, heure de notification, réglages |
| `lexemes` | Mot ou chunk : forme, nature, fréquence, hanja + famille, traduction, tags de domaine, slug d'icône Thiings |
| `lexeme_state` | Par utilisateur et par mot : état, confiance auto-évaluée, confiance estimée, champs de planification (stabilité, échéance, répétitions, échecs), expositions, jours d'exposition |
| `texts` | Date, slot, titre, statut, source, niveau atteint, chemin audio, métadonnées de fabrication (coûts, itérations) |
| `sentences` | Rang, coréen, traduction, piste audio, découpage en mots avec rôle |
| `text_lexemes` | Glossaire du texte : rôle, occurrences, traduction, collocation, 3 exemples |
| `quizzes` | Questions, format, distracteurs, réponses |
| `captures` | Mot capturé, source (photo/partage/saisie), image, phrase de contexte, date, statut de tri |
| `events` | Taps, swipes, ouvertures de famille, réponses, complétions |
| `calibration` | Réponses du test initial |

---

## 11. Socle technique

Repris tel quel du projet `to-day`, qui tourne déjà sur le même VPS.

| Pièce | Choix |
|---|---|
| **Front** | Application **native Apple (Swift)** |
| **Base** | **Postgres 16 alpine** en conteneur, RAM plafonnée |
| **API** | **TypeScript — Hono + Drizzle**, en conteneur |
| **Exposition** | Traefik existant (réseau `n8n_default`), sous-domaine dédié, TLS Let's Encrypt |
| **Auth** | **Google OAuth** + liste blanche sur l'adresse |
| **Planification** | Tâche périodique dans le conteneur, calée sur l'heure de chaque utilisateur |
| **Génération** | **OpenRouter** — `openai/gpt-5.1` (§9.3) |
| **Vérification** | *Aucune — étape supprimée (§9.1)* |
| **Voix** | **Google Cloud TTS**, `ko-KR-Chirp3-HD-Achernar` (§9.3, décisions §39) |
| **Icônes** | API Thiings existante, port 3088 |
| **OCR** | Natif iOS (Vision) — aucun service |
| **Morphologie** | Kiwi, en conteneur |

**Ce qu'on n'utilise pas** : Supabase, ffmpeg, GitHub Actions, Vercel — tous présents
dans le plan précédent, tous rendus inutiles par le passage au natif et au VPS.

### 11.1 Coûts mensuels estimés

| Poste | Estimation |
|---|---|
| Génération (3 textes/jour, GPT-5.1) | **1,31 €** — mesuré, pas estimé |
| Annotation et quiz (même modèle) | ~1 à 2 € |
| Voix (3 textes/jour, ~93 000 caractères) | **0 €** — palier gratuit Google, 1 M/mois |
| Vérification | 0 € — étape supprimée |
| Infrastructure | 0 € (VPS déjà payé) |
| **Total** | **~2 à 4 €/mois** |

---

## 12. Cas d'échec

| Situation | Comportement |
|---|---|
| **Génération ratée** | La notification ne part pas. À l'ouverture, l'app le dit franchement et propose de relancer. La bibliothèque reste disponible. |
| **Un texte hors niveau** après réécritures | Il n'est pas publié — on en propose deux. **Deux bons textes valent mieux que trois dont un mauvais.** |
| **Pas de réseau le matin** | Aucune différence : textes et voix sont déjà sur le téléphone. |
| **Aucune actualité exploitable** | Le slot bascule sur un sujet de fond (histoire, science) plutôt que de ne rien proposer. |
| **Carnet vide pour le slot 3** | Repli sur le fonds de situations d'expat. |
| **OCR sans résultat** | Saisie manuelle proposée immédiatement, sans message d'erreur. |

**Aucun de ces cas ne produit de reproche, de rattrapage à faire, ou de retard à combler.**

---

## 13. Hors périmètre V1

| Écarté | Raison |
|---|---|
| Flashcards, même optionnelles | Dès qu'une pile révisable existe, elle produit une dette. « Optionnel » n'y change rien. |
| Dictionnaire généraliste | Naver et Papago sont gratuits et ont vingt ans d'avance. |
| Mode conversation / production orale | Vrai besoin, mais un second produit. Explicitement reporté. |
| Sérialisation d'un sujet sur plusieurs jours | Mal compatible avec quatre univers différents chaque matin. |
| Bouton « cette phrase sonne bizarre » | L'app avouerait ne pas se faire confiance ; le doute contaminerait tout le texte. |
| Paiement, inscription publique, quotas, support | Rien de tout ça avant d'avoir un produit qui tienne. |
| Mutualisation des textes par niveau | Ne se tranche pas avant de savoir si les gens aiment lire ces textes. |
| Dictée vocale à la capture | Reconnaître un mot coréen isolé, mal prononcé, hors contexte : le cas le plus dur, pour un gain faible. |
| Toute dépendance sous licence non commerciale | Une version commerciale est envisagée. |

---

## 14. La première chose à faire — ✅ faite le 27 juillet 2026

> **Résultat.** Génération : `openai/gpt-5.1` (8,8/10). Voix : Google Cloud TTS
> `ko-KR-Chirp3-HD-*` (0 €/mois). Vérificateur coréen natif : **supprimé** (§9.1).
> Outillage : `tools/m0-blind-test/`. Coût de l'essai : 0,60 € et deux heures.
>
> **Ce qu'on a appris en plus, et qui ne figurait pas dans le plan :**
> 1. Le seul modèle coréen natif à licence commerciale écrit *moins* bien le coréen que
>    les modèles frontière — l'intuition « un natif écrit mieux » est fausse ici.
> 2. Un jugement par modèle n'est pas reproductible d'un appel à l'autre. Toute
>    évaluation par modèle doit faire plusieurs passages.
> 3. L'utilisateur ne peut pas juger la naturalité d'une prose coréenne — c'est ce que le
>    produit doit lui apporter. Le point 5 ci-dessous était mal posé : il tranche
>    l'audio, pas l'écrit. Le niveau, lui, se vérifie par le calcul de l'étape 5, jamais
>    par sa lecture (P2).
>
> *Le protocole d'origine est conservé ci-dessous : il resservira tel quel le jour où on
> changera de modèle ou de fournisseur de voix.*

**Avant toute ligne de code : un essai comparatif à l'aveugle.**

Tout le produit repose sur une hypothèse jamais vérifiée — qu'un modèle écrive du coréen
qu'on ne reconnaîtrait pas comme généré. Et aucun classement ne peut la valider, parce
qu'aucun ne mesure ça.

1. Prendre un vrai article coréen du jour.
2. Générer le même texte de 300 mots avec **plusieurs candidats**.
3. Faire lire le même paragraphe par **plusieurs fournisseurs de voix**.
4. Présenter le tout **sans dire lequel est lequel**.
5. L'utilisateur lit, écoute, tranche.

Une séance, quelques centimes. Elle décide du générateur, elle dit si un vérificateur
coréen est réellement nécessaire, elle choisit la voix — et surtout, elle répond à la
seule question qui décide de la viabilité du produit.

**Si le coréen est bon, tout le reste tient. S'il est mauvais, on l'aura su en une heure
au lieu de trois semaines.**

---

## 15. Le parking — idées gardées, non retenues pour la V1

- ~~**Surlignage du mot en cours**~~ — **sorti du parking et livré le 27 juillet 2026.**
  Reste au parking la moitié « contrôle fin de la vitesse de lecture », pour se pousser
  progressivement plus vite.
- **Une phrase à réutiliser aujourd'hui** en fin de session — sert l'objectif de parler,
  écartée au profit du quiz.
- **Transformer un article capturé en texte du jour** (coller un lien, le faire réécrire
  à son niveau).
- **Mode conversation / discussion orale.**

---

## 16. Risques

| Risque | Gravité | Parade |
|---|---|---|
| ~~**Le coréen généré sonne artificiel**~~ | ~~Critique~~ | **Levé** — essai §14 mené le 27/07/2026 : GPT-5.1 noté 8,8/10 par trois juges, avec ±0 de dispersion chez deux d'entre eux. À re-vérifier si on change de modèle. |
| ~~**Le vérificateur coréen commercial est cher ou inaccessible**~~ | ~~Moyenne~~ | **Sans objet** — l'étape est supprimée (§9.1). |
| **Un jugement par modèle n'est pas reproductible** | Moyenne | Découvert pendant l'essai : le même juge note le même texte 4/10 puis 9/10. Toute évaluation par modèle fait plusieurs passages et moyenne. |
| **La capture s'assèche, le slot 3 tourne à vide** | Moyenne | Fonds de situations d'expat. Signal utile : si la capture ne se fait pas, c'est que le geste est trop coûteux. |
| **La calibration initiale est fausse** | Faible | Les taps corrigent en quelques jours. |
| **Les distracteurs du quiz sont trop faciles** | Moyenne | Contrainte explicite : même nature, même bande, tirés du texte. À vérifier sur les premiers quiz réels. |
| **L'analyse morphologique diverge de la liste de fréquence** | Moyenne | Normalisation au chargement, liste blanche de mots-outils, tests sur du coréen réel avant de s'y fier. |
