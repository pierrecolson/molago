# Molago — plan de MVP

*27 juillet 2026. Suite de [`product-spec.md`](product-spec.md) et de la direction visuelle A
([`design/direction-a-systeme.html`](design/direction-a-systeme.html)).*

**Le principe de ce document : la spec décrit le produit fini. Le MVP en construit un tiers,
et c'est le bon tiers.** Chaque coupe ci-dessous est justifiée par une seule question — *est-ce
que le produit reste vrai sans ça pendant six semaines ?*

---

## 0. Ce qui vient avant la première ligne de Swift — ✅ fait

**L'essai comparatif à l'aveugle (spec §14), mené le 27 juillet 2026.** Deux heures, 0,60 €.

Tout le produit reposait sur une hypothèse jamais vérifiée : qu'un modèle écrive du coréen
qu'on ne reconnaîtrait pas comme généré. Cinq modèles ont réécrit le même article coréen du
jour, jugés à l'aveugle par trois modèles, trois passages chacun.

| | Verdict |
|---|---|
| **Génération** | `openai/gpt-5.1` — 8,8/10, et le moins cher du haut de tableau (1,31 €/mois) |
| **Voix** | Google Cloud TTS `ko-KR-Chirp3-HD-*` — meilleur à l'oreille, **0 €/mois** |
| **Vérificateur coréen natif** | **Supprimé.** Il écrit et juge moins bien que le générateur. |

**Trois choses apprises qui n'étaient pas au programme :**

1. L'intuition « un modèle coréen natif écrit mieux le coréen » est **fausse** : le seul
   candidat commercial finit dernier, avec des anglicismes et une hallucination franche.
2. **Un seul appel de jugement par un modèle ne mesure rien** — le même juge a noté le même
   texte 4/10 puis 9/10. Règle désormais générale au pipeline : plusieurs passages, moyenne.
3. L'utilisateur **ne peut pas juger la naturalité d'une prose coréenne** — c'est exactement
   ce que le produit doit lui apporter. Il tranche l'audio en une écoute ; pour l'écrit, le
   jugement revient aux modèles, et le niveau au calcul déterministe de l'étape 5 (P2).

Outillage réutilisable le jour où on changera de modèle ou de voix :
`tools/m0-blind-test/run.mjs` puis `judge.mjs`.

---

## 1. La liste des coupes

| Dans la spec | MVP | Pourquoi |
|---|---|---|
| Postgres 16 en conteneur | ❌ **Fichiers JSON** | Un utilisateur, un appareil. Une base sert à partager entre utilisateurs — il n'y en a pas. Postgres revient au deuxième utilisateur. |
| API Hono + Drizzle | ❌ **Fichiers statiques + 1 route** | L'app télécharge `2026-07-28.json` et des MP3. La seule route dynamique reçoit le profil de vocabulaire. ~30 lignes. |
| Google OAuth + liste blanche | ❌ **Un chemin secret** | Un utilisateur. L'auth arrive avec l'inscription publique, pas avant. |
| Notification push (APNs) | ❌ **Notification locale + tâche de fond** | Pas de certificat, pas de serveur de push. `BGAppRefreshTask` télécharge la nuit et réécrit la notification avec le vrai titre ; si elle n'a pas tourné, la formulation est générique et l'app télécharge à l'ouverture. |
| Vérificateur coréen natif (étape 6) | ❌ **Supprimé définitivement** | L'essai M0 a tranché : le seul modèle coréen natif commercial écrit *moins* bien que le générateur retenu, et juge de façon non reproductible. Voir `decisions.md` §34. |
| Famille de racine hanja (étage 3) | ❌ | Demande une base de hanja et un regroupement par caractère réel. Deux étages au lieu de trois. |
| Icônes Thiings | ✅ **Gardées (V1)** | Licence commerciale acquise. Le coût réel est un script de correspondance plus ~2 h de tri à l'œil, une seule fois — et c'est ce qui fait que le Notebook ressemble à une collection d'objets plutôt qu'à une liste de vocabulaire. Les mots abstraits gardent une tuile typographique : la règle « pas d'icône plutôt qu'une icône fausse » tient. |
| Calibration du premier jour | ❌ | La spec dit elle-même qu'elle est sautable et que les taps corrigent en quelques jours. Tu connais ton niveau : on part d'un seuil et on laisse le moteur corriger. |
| Quiz par saisie clavier | ❌ **QCM seulement** | La tolérance de saisie (espaces, une lettre à côté) est la partie fastidieuse. Le QCM suffit à prouver que le rappel actif marche. |
| Jauge de confiance (Strava) | ❌ | Confort du Notebook. |
| Grille d'activité | ❌ | Pur plaisir. |
| Réglages de lecture (flux/blocs, vitesse, reprise auto) | ❌ **Un seul mode** | Flux continu, 1.0×. Les réglages arrivent quand on sait lequel on préfère. |
| Extension de partage iOS · Centre de contrôle · bouton Action | ❌ | Trois cibles Xcode et du provisioning en plus. Le bouton central suffit d'abord. |
| Analyse morphologique Kiwi | ✅ **Gardée** | C'est le mécanisme unique du produit (P2), et c'est `pip install kiwipiepy` plus trente lignes. On ne coupe pas ce qui est à la fois porteur et bon marché. |
| Capture photo + OCR | ✅ **Gardée** | C'est la boucle qui rend le slot 3 vrai. Vision est natif : ~20 lignes. |
| Quiz (3 questions) | ✅ **Gardé** | P5 : « lire seul ne suffit pas ». Sans quiz, le produit n'est plus qu'un lecteur. |

---

## 2. L'architecture, réduite à l'os

```
       VPS (déjà payé, Traefik déjà en place)
┌──────────────────────────────────────────────┐
│  cron 04:00                                  │
│    └─ pipeline.py  ──────────────┐           │
│                                  ▼           │
│                        /data/2026-07-28.json │
│                        /data/audio/*.mp3     │
│                                  │           │
│  Caddy/Traefik ── fichiers statiques ────────┼──▶ HTTPS
│  1 route POST /profile ── profile.json ◀─────┼───
└──────────────────────────────────────────────┘
                                                ▲
                                                │
                                     ┌──────────┴─────────┐
                                     │  Molago.app        │
                                     │  SwiftData local   │
                                     │  (état, notebook)  │
                                     └────────────────────┘
```

**Il n'y a pas de base de données côté serveur, et pas d'API au sens habituel.** Le serveur
fabrique des fichiers la nuit et les sert. L'app les télécharge et garde tout son état
localement. La seule chose qui remonte est un petit JSON de profil (lemmes connus + mots dus),
déposé une fois par jour.

Le `docker-compose.yml` et les étiquettes Traefik se copient de `to-day` — le motif
(sous-domaine, TLS Let's Encrypt, réseau `n8n_default`) tourne déjà.

### Le format du jour

```json
{
  "date": "2026-07-28",
  "texts": [{
    "slot": "tech", "title": "Why Korean chipmakers…", "minutes": 4,
    "difficulty": "normal",
    "sentences": [
      { "ko": "이번 달 관리비 고지서를 받고 깜짝 놀랐어요.",
        "en": "I got this month's maintenance bill and was shocked.",
        "audio": "audio/2026-07-28-tech-01.mp3",
        "words": [ { "surface": "관리비", "lemma": "관리비", "range": [3,6] } ] }
    ],
    "glossary": { "관리비": { "pos": "noun", "en": "maintenance fee", "examples": ["…"] } },
    "quiz": [ { "sentenceIndex": 1, "blank": "관리비", "choices": ["관리비","연체료","보증금","수도료"] } ]
  }]
}
```

Tout est déjà là quand l'app ouvre : rien à calculer, rien à demander au réseau pendant la
lecture. C'est ce qui tient la promesse des « 5 secondes ».

---

## 3. Le pipeline nocturne

Un seul script Python, cron'é. Environ 300 lignes.

| Étape | Ce que ça fait | Coût |
|---|---|---|
| 1 · Collecte | RSS (Hacker News, Yonhap/한겨레) → articles du jour. Slot 3 : les mots capturés en attente. | `feedparser` |
| 2 · Sujet | Un candidat par slot. À intérêt égal, celui qui contient déjà des mots dus. | — |
| 3 · Vocabulaire | 3 à 8 mots nouveaux ; les mots dus sont *proposés*, jamais imposés. | — |
| 4 · Génération | Article source + vocabulaire cible + registre → 300 mots. **Jamais de mémoire.** | OpenRouter |
| 5 · Contrôle | Kiwi → lemmes → comparaison au profil. Hors niveau → retour en 4, deux fois max. | gratuit |
| ~~6 · Naturalité~~ | *Supprimée — voir `decisions.md` §34.* | — |
| 7 · Annotation | Découpage en mots tappables, glossaire, 3 exemples par mot. | OpenRouter |
| 8 · Quiz | 3 QCM, distracteurs de même nature et même bande, tirés du texte. | OpenRouter |
| 9 · Voix | **Une piste par phrase.** C'est ce qui rend la synchro triviale (voir §4). | TTS |
| 10 · Publication | Écriture atomique du JSON. Un texte hors niveau n'est pas publié — on en propose deux. | — |

Idempotent : relancé, il reprend sans dupliquer. Un fichier `.lock` par date suffit.

---

## 4. L'app Swift

**SwiftUI, iOS 18 minimum, Swift 6.** Un seul target. Pas de Package.swift, pas de modules,
pas de couche « architecture » — cinq écrans et un modèle.

| Pièce | Choix | Pourquoi |
|---|---|---|
| Persistance | **SwiftData** | Natif, zéro boilerplate Core Data. Sauvegarde par iCloud, gratuite. |
| Audio | **`AVQueuePlayer`** | Une piste par phrase → on empile les phrases, et le surlignage suit `currentItem`. |
| OCR | **Vision, `VNRecognizeTextRequest` en `ko-KR`** | Natif, hors ligne, instantané, aucune dépendance. |
| Téléchargement | **À l'ouverture de l'app**, avec un état de chargement soigné | Les modes d'arrière-plan font partie des capacités restreintes sur compte gratuit (§7). On ne parie pas dessus : ~2 Mo se téléchargent en trois secondes, et il ouvre l'app le matin de toute façon. `BGAppRefreshTask` revient avec le compte payant, en bonus. |
| Notification | **`UNUserNotificationCenter`, locale** | Les notifications locales ne demandent aucun *entitlement* — seul le push distant en exige un. Formulation générique en V1 (« trois textes vous attendent ») : sans APNs, l'app ne peut pas connaître le titre du jour avant de l'avoir téléchargé. |
| Sauvegarde | **Le Notebook remonte au serveur chaque jour** | iCloud est bloqué sur compte gratuit, et une réinstallation peut emporter les données locales. Le JSON de profil qu'on envoyait déjà pour calibrer le niveau porte aussi les mots gardés. Vingt lignes de plus, et une réinstallation devient sans conséquence. |

### Le seul morceau techniquement délicat, et il est déjà résolu

La phrase surlignée qui suit la voix. Avec un seul fichier audio par texte, il faudrait des
timings mot par mot du TTS et une synchronisation continue. **La spec a déjà choisi une piste
par phrase (§9, étape 9)** — donc :

```swift
player = AVQueuePlayer(items: sentences.map { AVPlayerItem(url: $0.audioURL) })
player.publisher(for: \.currentItem)
      .sink { [weak self] item in self?.highlighted = self?.index(of: item) }
```

Le surlignage n'est pas synchronisé : il *est* l'index de la piste en cours. Taper une phrase
= `removeAllItems()` puis réempiler à partir de là. Une quinzaine de lignes, et aucune dérive
possible.

### Les cinq écrans

1. **Library** — les trois cartes du jour (aplats dancheong, filet blanc), l'historique en dessous.
2. **Reader** — texte, phrase surlignée, barre de lecture.
3. **Carte de mot flottante** — sens + exemples, swipe droite `Keep` / gauche `I knew this`.
   `DragGesture` + `rotationEffect` + ressort. Le même composant sert au tri après capture.
4. **Quiz** — 3 QCM, puis l'écran se ferme. Pas de score.
5. **Notebook** — liste, recherche, tuiles typographiques.

Plus la **capture** : bouton central → appareil photo → OCR → pile de cartes à trier.

---

## 5. L'ordre de construction

Chaque jalon se termine par quelque chose à ouvrir sur le téléphone.

| # | Jalon | Ce qu'on peut tester | Taille |
|---|---|---|---|
| ~~**M0**~~ | ~~**L'essai à l'aveugle**~~ | ✅ **Fait le 27/07/2026.** GPT-5.1 pour générer, Google Chirp3-HD pour la voix, étape 6 supprimée. Coût : 0,60 €. | ~~½ session~~ |
| **M1** | **Trois textes, lus à voix haute** | Le matin, trois cartes ; on en tape une, le texte s'affiche, la voix démarre, la phrase se surligne. Pas de tap sur les mots, pas de quiz, pas de notebook. **C'est déjà le produit.** | 2–3 sessions |
| **M2** | **Taper un mot** | Carte flottante, `Keep` / `I knew this`, le Notebook se remplit — **avec les icônes Thiings**. Le moteur commence à apprendre de tes taps. | 1–2 sessions |
| **M2b** | **Les 240 icônes** | Le script de correspondance tourne sur les 9 000, sort une liste de candidats ; tu valides à l'œil (attention aux `$` et enseignes anglaises incrustés dans les modèles 3D), on embarque le catalogue. | ½ session + 2 h à toi |
| **M3** | **Le quiz** | 90 secondes après la lecture, trois questions tirées du texte. P5 est satisfait. | 1 session |
| **M4** | **La capture** | Photo d'une facture → mots inconnus surlignés → tri au swipe → le lendemain, le slot 3 parle de ça. **La boucle se ferme.** | 2 sessions |

**M1 est le vrai MVP.** Si après deux semaines de M1 tu n'ouvres pas l'app le matin, ni le
quiz ni la capture n'y changeront rien — et on l'aura su avant de les construire.

---

## 6. Ce qui revient ensuite

Dans l'ordre où ça compte, une fois M4 en place et utilisé quinze jours :

1. **La famille de racine hanja** — l'étage 3, celui où le rangement mental se fait.
2. **Le quiz par saisie clavier** pour les mots mûrs, avec la tolérance aux espaces.
3. **L'extension de partage iOS**, puis le contrôle du Centre de contrôle et le bouton Action.
4. **APNs** — la notification qui porte le vrai titre, de façon fiable.
5. **La jauge de confiance** et **la grille d'activité**.
6. **Postgres + l'API + OAuth** — le jour où il y a un deuxième utilisateur, pas avant.

---

## 7. Développer sans compte Apple Developer

**Décision : on commence sans payer les 99 €/an.** C'est tenable, à trois conditions.

### Ce qui marche quand même

Tout ce dont M1 à M4 ont besoin : SwiftUI, SwiftData en local, `AVQueuePlayer`, le
framework Vision pour l'OCR, l'appareil photo, et les **notifications locales** — celles-ci
ne demandent aucun *entitlement*, seul le push distant en exige un.

### Les trois contraintes, et ce qu'on fait

| Contrainte | Conséquence | Parade |
|---|---|---|
| **Le profil expire au bout de 7 jours** | L'app cesse de se lancer : on tape l'icône, rien ne se passe. | Rebrancher l'iPhone, ouvrir Xcode, appuyer sur ▶. Trente secondes, une fois par semaine. Pendant le développement c'est invisible — je reconstruis de toute façon. |
| **iCloud est bloqué** | Aucune sauvegarde automatique du Notebook, et une réinstallation peut emporter les données locales. | **Le Notebook remonte au serveur chaque jour**, greffé sur le JSON de profil déjà prévu. Une réinstallation redevient sans conséquence — c'est la parade la plus importante des trois. |
| **Les modes d'arrière-plan sont restreints** | `BGAppRefreshTask` peut ne pas se déclencher. | On ne parie pas dessus : le téléchargement se fait **à l'ouverture**, ~2 Mo en trois secondes. Plus simple à coder, et sans risque. |

*Sont aussi bloqués : App Groups (donc l'extension de partage iOS), Sign in with Apple, et
les domaines associés. Tous étaient déjà hors du MVP.*

### Le moment où payer devient évident

**À la fin de M1, après deux semaines d'usage quotidien.** Pas avant.

Si tu ouvres l'app tous les matins pendant quinze jours, les 99 € se justifient tout seuls
et débloquent d'un coup : plus d'expiration, **APNs** (la notification porte enfin le vrai
titre du jour, comme la spec le décrit en §4.2), la sauvegarde iCloud, et l'extension de
partage pour M4.

Si tu ne l'ouvres pas, tu auras économisé 99 € et appris quelque chose de bien plus utile.

C'est le bon ordre : **le compte payant récompense un produit qui a fait ses preuves, il ne
finance pas un pari.**
