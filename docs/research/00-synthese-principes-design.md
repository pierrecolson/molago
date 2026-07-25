# 00 — Synthèse : principes de design pour Molago 2.0

*Document de synthèse stratégique — juillet 2026. Fondé sur les rapports 01 à 06 de `docs/research/`.*

**Contexte utilisateur** : Français vivant en Corée depuis 8 ans, lit parfaitement le hangul, vocabulaire estimé ~3 000–5 000 mots, veut du vocabulaire de vie quotidienne pour mieux parler avec les gens autour de lui. Déteste le par-cœur, indifférent à la K-pop et aux dramas, aime le style Didi Podcast. Idée fondatrice : un contenu quotidien matinal généré, où « l'apprentissage vient tout seul ».

---

## 1. Les 10 principes de design non négociables

### P1 — Compelling input d'abord : le contenu est le produit, la langue est le véhicule

L'histoire ou le brief du matin doit être quelque chose que l'utilisateur lirait *même en français*. L'intérêt pour le sujet est un facteur causal mesuré des gains de vocabulaire et de leur rétention (rapport 01, §8 ; *System* 2023), et la Compelling Input Hypothesis de Krashen montre que l'input captivant élimine le besoin de motivation consciente (rapport 03, §3). L'analyse de Didi Podcast et Iyagi confirme : on vient pour l'histoire, pas pour la leçon (rapport 03, §9). Test de validation : « aurais-tu ouvert cet article s'il était dans ton journal ? ». Corollaire : pas de « seductive details » décoratifs — l'intérêt vient du sujet, pas d'ornements (rapport 03, §1).

### P2 — Couverture lexicale contrôlée à 96–98 %, vérifiée algorithmiquement

C'est LE paramètre qui détermine si l'utilisateur est en flow ou en déchiffrage. Le seuil 95 % minimal / 98 % optimal est l'un des résultats les plus solides du domaine (Hu & Nation 2000 ; Laufer & Ravenhorst-Kalovski 2010 — rapports 01 §5, 02 §7, 03 §3, 04 §1). Concrètement : 3–8 mots/chunks nouveaux par texte de 300–400 mots, jamais plus. Et la vérification doit être **déterministe, hors LLM** : analyse morphologique (Kiwi/MeCab-ko) → lemmes → comparaison au profil lexical → réécriture si < 96 % (rapports 04 §10 et 06 §7). Aucune app concurrente ne fait cette vérification rigoureusement (rapport 04, §9) — c'est le différenciateur méthodologique n°1.

### P3 — La répétition espacée est cachée dans le contenu, jamais montrée en cartes

Un mot demande ~8–12 rencontres espacées en contextes variés pour être acquis (Webb 2007, Nation — rapport 01, §3). La répétition espacée (FSRS) est un moteur scientifiquement irréprochable mais un désastre motivationnel comme interface : avalanche de backlog, ease hell, culpabilité du streak — causes documentées d'abandon d'Anki (rapports 01 §6, 03 §6, 04 §5). Solution : FSRS sert de **planificateur interne** qui décide quels mots réinjecter dans le texte du jour (J+1, J+3, J+7, J+16…). L'espacement est dans les histoires, pas dans une pile de cartes. C'est la fonctionnalité que Lenguia esquisse et que personne ne pousse à fond (rapports 04 §7, 06 §1.3).

### P4 — Zéro dette, zéro culpabilité : rater des jours ne coûte rien

Cause n°1 d'abandon d'Anki : le backlog post-pause (rapport 04, §5). Leçon Duolingo : pardonner l'absence retient mieux que punir (Streak Freeze : −21 % de churn — rapport 03, §6). Et Lally et al. (2010) : manquer un jour n'a aucun effet mesurable sur la formation d'habitude ; c'est l'abandon après le raté qui tue (rapport 03, §7). Design : si l'utilisateur rate 5 jours, les mots dus sont simplement tissés dans le prochain texte. Pas de compteur de cartes dues, pas de streak punitif, pas de notification culpabilisante. Au plus une heatmap de constance douce, façon Satori Reader (rapport 04, §8).

### P5 — Récupération active obligatoire : le plaisir de lire ne suffit pas

Résultat contre-intuitif crucial de Storyfier (UIST 2023) : les histoires générées plaisent et réduisent l'effort perçu, mais la rétention **baisse** si l'IA fait tout le travail (rapport 06, §3). En face : le testing effect (61 % vs 40 % de rétention à une semaine — Roediger & Karpicke) et l'effet de génération (+40 % de rappel — rapport 01, §7). Design : gloss en tap-to-reveal (pas affiché d'office), micro-instant de génération avant révélation (mot masqué 2 secondes), et 3–5 questions cloze en fin de lecture sur les phrases mêmes du texte. L'effort actif reste minimal en durée mais non négociable en présence.

### P6 — L'unité d'apprentissage est le chunk parlé, pas le mot de manuel

Le coréen réel est fait de contractions (근데, 그게), de fillers, de backchannels (아 그렇구나, 맞아요) et de collocations peu prédictibles (사진을 찍다, 약속을 잡다) — massivement absents des manuels et des listes TOPIK, dont les corpus ne contenaient que ~3 % d'oral (rapport 05, §1–4). Les séquences préfabriquées sont traitées plus vite et donnent la fluidité (approche lexicale — rapport 05, §4). Design : le glossaire enregistre des chunks (2–4 mots) et phrases-patrons, les textes sont écrits en 해요체 conversationnel naturel avec contractions réelles, style Didi Podcast — jamais en style TOPIK/합쇼체 (rapports 02 §5, 05 §8).

### P7 — Narrow reading structurel : des fils thématiques, pas du zapping

Lire plusieurs textes sur un même thème fait recirculer mécaniquement le même vocabulaire — c'est la solution au problème des ~10 rencontres nécessaires que la lecture libre ne garantit jamais (Schmitt & Carter 2000, Cho & Krashen — rapport 01, §4 ; rapport 03, §8). Design : mini-séries de 3–5 épisodes sur un même sujet (une actu qui évolue, un feuilleton), avec cliffhanger — l'effet Zeigarnik crée l'envie de revenir demain, un « streak » naturel sans compteur (rapport 03, §4). La sérialisation est le mécanisme de retour quotidien le plus puissant observé chez Satori Reader (rapport 04, §3).

### P8 — Stealth assessment : mesurer sans jamais tester

Le système apprend ce que l'utilisateur sait en observant : mot tapé = probablement inconnu, mot lu N fois sans tap = connu (modèle Kimchi Reader Unknown→Seen→Known — rapport 02, §9). Le stealth assessment est validé empiriquement (Shute — rapport 03, §5) et le tracking passif est le pattern gagnant du marché, contrairement au tracking manuel corvéable de LingQ (rapport 04, §2 et §8). La progression affichée est purement informationnelle — « 4 200 mots connus, 97 % de couverture » — jamais de points, gemmes ou ligues : les récompenses tangibles attendues détruisent la motivation intrinsèque (overjustification, d = −0,34 — rapport 03, §6).

### P9 — Pipeline qualité pour le coréen généré : générer → vérifier → réviser → ancrer

Le coréen des LLM frontière est correct mais reconnaissablement artificiel : virgules sur-utilisées, style nominal, registre dérivant vers le formel, 번역투 (KatFishNet, XDAC — rapport 06, §2). La leçon Beelinguapp : du contenu IA non vérifié détruit la confiance très vite (rapports 04 §3, 06 §3). Design non négociable : few-shot de vrai coréen parlé dans le prompt, consigne de registre explicite (해요체, pas de 당신), vérification lexicale déterministe, passe de révision par un second modèle (idéalement HyperCLOVA X), et **glossaire ancré sur l'API krdict** (dictionnaire réel, définitions FR) — jamais des définitions hallucinées par le LLM (rapport 06, §7).

### P10 — Rituel matinal fini, à zéro décision et zéro friction

L'habitude bat la motivation : automaticité en ~66 jours médiane, à condition d'un comportement simple ancré à une routine existante (habit stacking, café du matin — Lally, Fogg ; rapport 03, §7). La leçon des expats qui plafonnent après 10 ans : le système doit demander 10–15 min/jour sans volonté, pas des « sessions d'étude » (rapport 05, §6). Design : contenu généré la nuit, prêt à l'ouverture, longueur fixe et annoncée (3–5 min de lecture), audio TTS synchronisé (coût négligeable, ~1–2 €/mois — rapport 06, §5), format borné qui se termine — un épisode, pas un flux infini. La fraîcheur quotidienne est un contrat implicite : une app de contenu quotidien qui cesse de l'être meurt (leçon Todaii — rapport 04, §3).

---

## 2. Tensions et arbitrages entre les recherches

### T1 — Répétition espacée nécessaire vs aversion aux flashcards
La tension fondatrice. Le SRS est prouvé (FSRS : même rétention avec ~30 % de révisions en moins — rapport 01, §6) et l'apprentissage délibéré est ~4× plus rapide que l'incident (35 mots/h — rapport 01, §2). Mais l'utilisateur déteste le par-cœur et la littérature d'abandon d'Anki est accablante. **Arbitrage retenu** : le SRS pilote la génération de contenu (invisible), et les flashcards survivent en dose homéopathique — 5–10 cartes/jour max, format cloze en contexte issu des histoires lues, optionnelles, qui expirent silencieusement sans backlog. Nation plafonne l'étude délibérée à 25 % du temps ; Molago vise plutôt 10–15 %.

### T2 — « Sans effort perçu » vs nécessité de l'effort réel (desirable difficulty)
Krashen promet l'acquisition sans effort conscient ; Storyfier démontre que l'assistance IA totale dégrade la rétention, et le testing effect montre que la récupération est efficace *parce qu'elle est effortful* (rapports 01 §7, 06 §3). **Arbitrage** : l'effort perçu doit rester bas, mais des micro-efforts de récupération sont insérés dans le flux (tap-to-reveal, cloze, 2 secondes de tentative avant la révélation). L'utilisateur ne doit jamais avoir l'impression de « réviser », mais il doit toujours récupérer activement.

### T3 — Fréquence corpus vs utilité personnelle
Les listes NIKL/TOPIK sont l'armature de calibration la plus solide (rapport 02, §6), mais elles sont biaisées écrit/académique (~3 % d'oral dans les corpus — rapport 05, §1) et vieilles de 20 ans ; le vocabulaire réellement utile à un expat (배달, 관리비, 상담원 연결, backchannels) y est sous-représenté. **Arbitrage** : triple filtre de sélection — fréquence corpus (plutôt le *Frequency Dictionary of Korean*, registre oral) × pertinence situationnelle vie d'expat × rendement morphologique hanja. Les listes officielles servent à calibrer le « supposé connu », pas à dicter le programme.

### T4 — Registre oral (natif) vs registre écrit (sino-coréen)
Le small talk et la conversation vivent dans les mots natifs, contractions et idéophones ; la « vie adulte » (contrat, banque, santé, actualité) vit dans le sino-coréen (rapport 02, §2). Les deux couches s'apprennent différemment. **Arbitrage** : alterner deux formats de contenu — chroniques/feuilletons en 해요체 parlé (couche native) et brèves d'actualité en style journalistique léger (couche sino-coréenne), chaque couche travaillée dans son registre naturel (rapport 02, §9).

### T5 — Gamification qui retient vs gamification qui détruit
Les streaks de Duolingo fonctionnent pour la rétention produit (streak ≥ 7 jours = 2,4× plus de retour) mais créent déplacement d'objectif, anxiété, et une illusion de progrès au niveau intermédiaire ; les récompenses tangibles sabotent la motivation intrinsèque (rapport 03, §6). **Arbitrage** : aucune récompense extrinsèque ; la seule « accroche » du lendemain est narrative (cliffhanger) et informationnelle (progression réelle de couverture). Molago, outil personnel sans KPI d'engagement à vendre, n'a aucune raison d'importer les dark patterns.

### T6 — Personnalisation profonde vs coûts de démarrage (cold start)
La personnalisation par intérêts améliore mesurablement rétention et transfert (Walkington — rapport 03, §8), mais exige de connaître finement le profil lexical et les intérêts — et le cold start est bâclé partout dans le marché (rapport 04, §7). **Arbitrage** : initialisation NIKL A+B (~3 000 mots supposés connus) + test de placement indolore par auto-marquage, puis affinage continu par les taps. Accepter une calibration imparfaite les 2 premières semaines plutôt qu'un onboarding lourd.

### T7 — Contenu quotidien frais vs qualité linguistique vérifiée
La fraîcheur quotidienne est un contrat implicite (leçon Todaii), mais générer vite du coréen naturel demande un pipeline multi-passes (rapport 06). **Arbitrage** : peu de contenu mais bon — un seul brief/jour, pipeline complet de vérification (coût : quelques centimes), et un bouton « ce passage sonne bizarre » comme garde-fou humain — le signal que Beelinguapp n'a jamais eu.

### T8 — Input pur vs besoin d'output
L'input compréhensible développe la compréhension mais laisse la production en retard (critique de Swain — rapport 01, §1) ; or l'objectif final est de *parler* avec les gens. **Arbitrage V1** : rester input-first (c'est le cœur validé), mais semer des embryons d'output à coût quasi nul : la boucle « 1–2 expressions à essayer aujourd'hui » en fin d'histoire, et l'auto-évaluation hebdo « as-tu utilisé un mot de Molago dans une vraie conversation ? ». Le retelling oral (RetAssist) et le STT sont reportés en V2.

---

## 3. La boucle quotidienne idéale

**Durée totale : 8–12 minutes, chaque matin, ancrée au premier café (habit stacking). Générée la nuit, prête à l'ouverture, zéro décision à prendre.**

### La veille, pendant la nuit (automatique, invisible)
Le planificateur FSRS calcule les mots/chunks « dus » ; le générateur reçoit : le fil thématique en cours (épisode suivant du feuilleton ou suite de l'actu suivie), 3–8 items nouveaux sélectionnés par triple filtre, la liste des items à réinjecter, la consigne de registre + few-shot de coréen parlé. Pipeline : génération → vérification morphologique de couverture (≥ 96 %) → réécriture ciblée → révision « relecteur natif » → glossaire ancré krdict → TTS synchronisé.

### Le matin

1. **Ouverture (0 min)** — Le brief du jour est là, titre + durée annoncée (« 4 min »). Reprise du fil d'hier : le cliffhanger d'hier est la raison d'ouvrir aujourd'hui.

2. **Lecture/écoute (4–6 min)** — Texte de 300–400 mots en 해요체 naturel, audio karaoké phrase par phrase (lecture + écoute simultanées, le format le plus soutenu par la recherche). Mots nouveaux non signalés visuellement (préserver le flow) ; tap sur n'importe quel mot = gloss FR instantané avec la collocation complète + panneau famille hanja quand pertinent. Les mots déjà rencontrés dus en révision apparaissent d'abord brièvement masqués (2 s de tentative de génération avant révélation) — uniquement 2–3 par texte pour ne pas casser la lecture.

3. **Micro-quiz de clôture (2–3 min)** — 3–5 questions cloze sur les phrases mêmes du texte (récupération active déguisée, format multiple-choice gloss validé par méta-analyse). Les items ratés repartent dans la file de réinjection et reviendront dans le brief du surlendemain. Pas de note, pas de score — juste la correction.

4. **Sortie (30 s)** — Une carte « à essayer aujourd'hui » : 1–2 expressions du texte utilisables en situation réelle (au café, au bureau, avec le gardien). Fin nette : « à demain — [teaser de l'épisode suivant] ». L'app se ferme, la journée commence.

5. **Optionnel, plus tard dans la journée** — File de 5–10 cartes cloze (2 min max), jamais obligatoire, expirant silencieusement. Réécoute audio possible en marchant.

**Ce qui n'arrive jamais** : notification culpabilisante, backlog, compteur brisé. Un matin raté = le fil reprend simplement le lendemain, les mots dus tissés dans le texte suivant.

**Rythme hebdomadaire** : 3–5 épisodes sur un même fil thématique (narrow reading), alternance entre feuilleton de vie quotidienne (couche native/orale) et actu suivie (couche sino-coréenne), + occasionnellement une « mission » situationnelle scriptée (appeler le service client, renouveler l'ARC).

---

## 4. Questions ouvertes que seul l'utilisateur peut trancher

1. **Centres d'intérêt précis.** « Pas K-pop/dramas » est une exclusion, pas un programme. Quels sujets lirait-il même en français ? (tech, actu coréenne/internationale, économie, sport, vie de quartier, histoire de la Corée, cuisine… ?) C'est un paramètre d'efficacité mnésique, pas un gadget d'onboarding (rapport 01, §8).

2. **Budget temps réel.** 8–12 min/matin est l'hypothèse de la synthèse — est-ce le bon calibre ? Y a-t-il un créneau secondaire dans la journée (trajet, pause) pour l'audio ou les cartes optionnelles ?

3. **Oral vs écrit : la cible de sortie.** L'objectif est-il d'abord de mieux *comprendre* (téléphone, conversations de groupe — le « boss final ») ou de mieux *produire* (small talk, lien avec voisins/commerçants) ? Cela change la pondération compréhension orale / chunks de production dans le contenu.

4. **Fiction vs réel.** Feuilletons fictifs ancrés dans sa vie à Séoul, actualité réelle réécrite, ou chroniques culturelles façon Didi ? Quel mix le ferait revenir un matin de faible motivation ?

5. **Priorités situationnelles.** Parmi les 8 domaines d'expat (téléphone, santé, logement, admin/banque, restau/livraison, travail, small talk, taxi — rapport 05, §2), lesquels sont des douleurs *actuelles* vs déjà maîtrisés après 8 ans ? Où travaille-t-il, en quelle langue, avec qui parle-t-il coréen aujourd'hui ?

6. **État réel du vocabulaire.** ~3 000–5 000 mots est une estimation. Accepte-t-il un test de placement par auto-marquage (10 min, une fois) pour calibrer le profil lexical initial ?

7. **Le hanja l'intéresse-t-il ?** Le panneau « famille de mots » est un levier documenté (rapport 02, §3) et convient à un profil analytique — mais c'est un goût personnel : certains adorent la décomposition, d'autres la trouvent scolaire.

8. **Audio : quelle place ?** TTS systématique dès la V1 (quasi gratuit), mais : voix unique de conteur ou dialogues à deux voix ? Écoute-t-il en lisant, ou aussi en marchant sans texte (ce qui exige un calibrage 90–95 % plus prudent — rapport 04, §1) ?

9. **Interactions dans le texte.** Quel niveau de micro-friction tolère-t-il avant que « sans effort » soit trahi : mots masqués à deviner, quiz de clôture, gloss à choix multiple ? À tester avec lui, car c'est l'arbitrage T2 incarné.

10. **Ambition produit.** Molago reste-t-il un outil strictement personnel, ou l'hypothèse « produit pour résidents longue durée en Corée » (segment identifié vacant — rapport 04, §9) doit-elle influencer l'architecture dès maintenant ?

---

*Rapports sources : 01 (science de l'acquisition), 02 (spécificités du coréen), 03 (motivation et intérêt), 04 (paysage des apps), 05 (vocabulaire de vie quotidienne), 06 (contenu généré par IA).*
