# Les spécificités de l'apprentissage du vocabulaire coréen pour un francophone

*Rapport de recherche — Molago 2.0 — juillet 2026*

---

## Résumé exécutif

Le coréen est classé par le FSI parmi les 5 langues « super-hard » (catégorie IV actuelle, ex-catégorie V) : ~2 200 heures pour atteindre une aisance professionnelle, soit 4 à 5 fois plus que l'espagnol pour un occidental. La difficulté principale au niveau intermédiaire n'est pas la grammaire mais le **volume lexical** : ~57 % du lexique est sino-coréen (racines hanja), et il faut connaître l'équivalent de 6 000 à 9 000 familles de mots pour comprendre confortablement du contenu authentique (seuil de couverture 95–98 % établi par Hu & Nation). La bonne nouvelle : le lexique sino-coréen est **combinatoire** — apprendre ~300–500 racines hanja démultiplie mécaniquement le vocabulaire, ce qui est validé expérimentalement. Le fossé manuel/rue est réel : le coréen parlé privilégie les mots natifs, les contractions et le 반말/해요체, alors que les listes NIKL/TOPIK sur-représentent l'écrit académique. Pour le profil de l'utilisateur (8 ans en Corée, lecteur, allergique au par-cœur), la recherche converge vers : **input compréhensible « compelling » à ~95–98 % de couverture + glossage L1 intégré + répétition espacée légère des mots rencontrés en contexte** — exactement l'architecture envisagée pour Molago 2.0.

---

## 1. Pourquoi le coréen est une langue « catégorie IV/V » pour un occidental

### 1.1 Le classement FSI

Le Foreign Service Institute du Département d'État américain classe le coréen dans sa catégorie la plus difficile — aujourd'hui appelée **Category IV « super-hard languages »** (anciennement catégorie V selon les versions du classement) — aux côtés du mandarin, du cantonais, du japonais et de l'arabe. Estimation officielle : **88 semaines / 2 200 heures de classe** pour atteindre le niveau « Professional Working Proficiency » (ILR 3), contre 600–750 heures pour l'espagnol ou le néerlandais ([state.gov](https://www.state.gov/foreign-language-training/), [fsi-language-courses.org](https://www.fsi-language-courses.org/blog/fsi-language-difficulty/)). Le Korea Times a même titré en 2017 sur le fait que le FSI juge le coréen « exceptionally difficult » ([Korea Times](https://www.koreatimes.co.kr/southkorea/society/20171201/korean-exceptionally-difficult-language-to-learn-us-agency)).

Points de contexte importants pour Molago :

- Ces 2 200 heures supposent un **cours intensif** (25 h/semaine + devoirs) avec des diplomates sélectionnés. Pour un autodidacte en immersion partielle, le volume réel d'exposition nécessaire est plutôt supérieur.
- Le chiffre mesure la distance **depuis l'anglais** ; le français est à distance équivalente (aucun avantage lexical, contrairement à l'espagnol ou l'italien).
- L'utilisateur de Molago a déjà « payé » une grande partie du coût grammatical (conjugaison, particules, hangul). Ce qui reste, c'est précisément la partie la plus longue de la courbe : **le lexique**, qui représente l'essentiel des heures entre le niveau intermédiaire et l'aisance.

### 1.2 D'où vient la difficulté (pour le vocabulaire spécifiquement)

1. **Zéro cognat avec le français.** En espagnol, ~60 % du vocabulaire est deviné gratuitement par un francophone. En coréen, chaque mot doit être acquis (hors konglish, cf. §2.3). C'est le facteur n°1 du classement FSI.
2. **Opacité phonologique** : les mots sino-coréens sont courts (2 syllabes le plus souvent) et fortement homophoniques — 수 peut être 水 (eau), 手 (main), 數 (nombre), 壽 (longévité)… Sans conscience des racines, les mots se ressemblent tous et se confondent en mémoire.
3. **Triple lexique** (natif / sino-coréen / emprunts) avec des registres différents : il existe souvent 2–3 mots pour un même concept (나이 vs 연세 pour « âge » ; 이 vs 치아 pour « dent »), à choisir selon le registre et la politesse.
4. **Système honorifique** : certains noms et verbes changent entièrement selon l'interlocuteur (먹다/드시다/잡수시다 pour « manger », 집/댁 pour « maison »), ce qui multiplie les formes à connaître ([90 Day Korean](https://www.90daykorean.com/korean-speech-levels/)).
5. **Idéophones massifs** (의성어/의태어) : des milliers de mots mimétiques (반짝반짝, 살금살금, 미끌미끌) très fréquents à l'oral, quasi absents des manuels, impossibles à deviner ([Lingopie](https://lingopie.com/blog/korean-onomatopoeia/), [Wiktionary](https://en.wiktionary.org/wiki/Category:Korean_ideophones)).
6. **Agglutination et contractions à l'oral** qui rendent la reconnaissance des mots connus difficile à l'écoute (그것이 → 그게, 하지요 → 하죠).

**Conséquence produit** : la difficulté du coréen pour cet utilisateur est un problème de *volume et de rétention lexicale*, pas de compréhension du système. C'est le problème que Molago doit résoudre.

---

## 2. La structure du lexique coréen : trois couches

### 2.1 Les mots sino-coréens (한자어) — la couche dominante

Selon le dictionnaire de référence du NIKL (표준국어대사전), les mots sino-coréens représentent **~57 % des entrées** du lexique ; les estimations vont de 50 à 70 % selon les corpus ([Wikipedia — Sino-Korean vocabulary](https://en.wikipedia.org/wiki/Sino-Korean_vocabulary)). Caractéristiques :

- Construits à partir de **racines hanja** (caractères chinois), presque toujours monosyllabiques, combinées en mots de 2–4 syllabes.
- Dominent le vocabulaire **abstrait, administratif, technique, journalistique** : l'actualité, les documents officiels, la banque, l'immobilier, la santé — précisément la « vie adulte » en Corée.
- Nuance capitale relevée par les linguistes : en **fréquence d'usage oral**, les mots natifs dominent (les 100 mots les plus fréquents du coréen parlé sont majoritairement natifs), mais dès qu'on parle de sujets concrets de la vie quotidienne adulte (계약 contrat, 보험 assurance, 진료 consultation médicale), on est en plein sino-coréen ([WordReference forum](https://forum.wordreference.com/threads/over-half-of-korean-vocabulary-is-recognizable-as-chinese.450262/)).

### 2.2 Les mots natifs (고유어) — la couche à haute fréquence orale

~25–35 % du lexique, mais **sur-représentés dans la conversation** : verbes de base, sentiments, corps, nourriture, idéophones. C'est la couche la plus difficile à « systématiser » (pas de racines combinables) et celle où les nuances entre quasi-synonymes sont les plus fines. Ils s'acquièrent presque uniquement par exposition répétée en contexte — l'argument le plus fort en faveur d'une approche par histoires/lecture pour cette couche.

### 2.3 Les emprunts et le konglish (외래어 / 콩글리시)

Environ **5 000 emprunts actifs à l'anglais** ([KoreanClass101](https://www.koreanclass101.com/blog/2021/05/13/english-loanwords-in-korean/)) : la seule couche « gratuite » pour un occidental, avec deux pièges :

- **Adaptation phonologique** : il faut reconnaître 아르바이트 (petit boulot, via l'allemand *Arbeit*), 셀카 (selfie), 헬스장 (salle de sport).
- **Faux amis konglish** : 미팅 = rencontre arrangée/blind date (pas « meeting »), 핸드폰 = téléphone portable, 스킨십 = contact physique, 아이쇼핑 = lèche-vitrines, 서비스 = offert par la maison ([Migaku — Korean false friends](https://migaku.com/blog/korean/korean-false-friends), [Wikipedia — Konglish](https://en.wikipedia.org/wiki/Konglish)).

**Ratio de référence (dictionnaire NIKL)** : ~57 % sino-coréen / ~25 % natif / ~5 % emprunts / reste mixte. En corpus oral, l'ordre s'inverse partiellement au profit du natif.

---

## 3. Exploiter les racines hanja : l'effet multiplicateur

### 3.1 Le principe

C'est l'équivalent des racines gréco-latines en français (« -logie », « bio- », « -tion »), mais en **beaucoup plus systématique et productif**. Exemple canonique avec 학 (學, étude) :

| Mot | Décomposition | Sens |
|---|---|---|
| 학교 | étude + bâtiment (校) | école |
| 학생 | étude + être-vivant (生) | étudiant |
| 대학 | grand (大) + étude | université |
| 과학 | discipline (科) + étude | science |
| 수학 | nombre (數) + étude | mathématiques |
| 학원 | étude + institut (院) | académie privée (hagwon) |
| 방학 | libérer (放) + étude | vacances scolaires |

Une racine apprise ≈ 5 à 20 mots partiellement « débloqués ». Avec ~150 racines on couvre les combinaisons les plus productives ; les listes classiques pour apprenants tournent autour de **300–500 hanja** (contre 1 800 appris par les lycéens coréens). Point crucial : il ne s'agit **pas d'apprendre à écrire les caractères**, seulement d'associer *syllabe hangul ↔ sens de racine* (학 = « étude » dans un mot composé).

### 3.2 Validation empirique

- Une étude de l'Université du Minnesota (mémoire, Conservancy UMN) a montré que des étudiants **rappellent significativement mieux les mots contenant une syllabe hanja enseignée en classe** : enseigner le sens des syllabes améliore la rétention du vocabulaire nouveau ([UMN Conservancy](https://conservancy.umn.edu/items/3e0271c5-eafe-4dd6-b96e-b1abe104095a)).
- Consensus des praticiens : How to Study Korean maintient une section hanja dédiée en expliquant que « connaître les racines permet de deviner le sens d'un mot jamais étudié » ([HTSK Hanja Lesson 1](https://www.howtostudykorean.com/hanja-unit-1-lessons-1-20/hanja-lesson-1/)) ; TTMIK a publié une série « Hanja Guide » et un cours d'idiomes 사자성어 pour intermédiaires ; les blogs d'apprenants avancés (ex. [Sofie to Korea](https://sofietokorea.com/2021/07/04/how-im-studying-hanja-and-why-you-should-too/), [Speechling](https://speechling.com/blog/korean-hanja-how-i-learned-hanja-and-how-you-can-too/)) décrivent le hanja comme le levier principal pour sortir du plateau intermédiaire.
- Le hanja transforme le vocabulaire « d'une liste infinie de mots arbitraires en un système de briques combinables » ([Clozemaster](https://www.clozemaster.com/blog/best-ways-to-learn-korean-vocabulary/)) — exactement le déclic cognitif qui rend l'apprentissage « gratuit » pour un profil analytique.

### 3.3 Racines à plus fort rendement (échantillon)

학(étude), 교(école/enseigner), 생(vie/naître), 대(grand), 소(petit), 인(personne), 국(pays), 어(langue), 회(réunion/société), 사(affaire/entreprise), 장(lieu/chef), 실(salle), 원(institut/membre), 금(argent/or), 물(chose), 식(nourriture/manière), 일(jour/travail), 시(ville/heure), 차(voiture/thé), 전(avant/électricité), 후(après), 상(dessus/commerce), 하(dessous), 내(intérieur), 외(extérieur), 무(sans), 불/부(non-), 비(non-), 재(re-), 신(nouveau), 구(ancien)…

Les préfixes négatifs 무-(無, sans), 불/부-(不, in-), 비-(非, non-) et le préfixe 재-(再, re-) sont immédiatement productifs : 무료 (gratuit), 무선 (sans fil), 불가능 (impossible), 비공식 (non officiel), 재활용 (recyclage).

---

## 4. Familles de mots et dérivation : la « grammaire du lexique »

Le coréen fabrique des familles entières à partir d'un noyau nominal, surtout sino-coréen. Pour un apprenant, chaque noyau appris rapporte 3 à 8 mots quasi gratuits :

- **N + 하다** → verbe actif : 공부하다 (étudier), 걱정하다 (s'inquiéter). Des centaines de verbes s'obtiennent ainsi ; c'est le mécanisme le plus productif du coréen ([Seonsaengnim blog](https://www.seonsaengnim.com/en/blog/verbes-hada-coreen) parle de « 500+ verbes instantanés »).
- **N + 되다** → passif/résultatif : 걱정되다 (être inquiété), 취소되다 (être annulé). Règle quasi mécanique : tout N하다 transitif a son N되다.
- **N + 시키다 / 받다 / 당하다** → causatif, bénéficiaire, subi : 교육시키다, 사랑받다, 무시당하다.
- **N + 적(的)** → adjectif relationnel (« -ique/-el ») : 문화적 (culturel), 개인적 (personnel), 현실적 (réaliste) ; + -으로 → adverbe.
- **N + 성(性)** → « -ité » : 가능성 (possibilité), 중요성 (importance), 안전성 (sûreté).
- **N + 자(者) / 가(家) / 원(員) / 사(師·士)** → agents : 기자 (journaliste), 작가 (écrivain), 회사원 (employé), 변호사 (avocat).
- **N + 소(所) / 장(場) / 실(室) / 점(店)** → lieux : 세탁소 (pressing), 주차장 (parking), 화장실 (toilettes), 편의점 (supérette).
- Dérivation native : suffixes verbaux passifs 이/히/리/기, nominalisation -기/-음, -개 (instrument : 지우개 gomme), -쟁이/-꾸러기 (personnes, familier).

La recherche décrit une cinquantaine de modèles de formation de mots productifs en coréen ([ResearchGate — Derivation of nouns](https://www.researchgate.net/publication/297917868_Derivation_of_nouns_denoting_human-beings_in_Korean), [U. Hawaii — A Sketch of Korean](http://www2.hawaii.edu/~sford/research/korean1/index.html)). **Implication directe : présenter les mots nouveaux en familles (noyau + dérivés) plutôt qu'en items isolés est aligné avec la structure réelle de la langue.**

---

## 5. Le fossé manuel / rue : registres et coréen réel

### 5.1 Niveaux de langue

Trois niveaux vivants en pratique ([LingoDeer](https://blog.lingodeer.com/korean-speech-levels/), [90 Day Korean](https://www.90daykorean.com/korean-speech-levels/)) :

- **합쇼체 (-습니다)** : formel — annonces, news, business, armée. C'est celui des manuels débutants, mais presque personne ne parle comme ça au café.
- **해요체 (-아/어요)** : poli standard, le registre par défaut de la vie quotidienne entre adultes. **C'est le registre cible n°1 pour l'utilisateur de Molago.**
- **반말/해체** : intime — amis proches, famille, enfants. Refuser de passer au 반말 quand on y est invité est perçu comme une mise à distance ([Migaku](https://migaku.com/blog/korean/korean-informal-speech)).

Le système honorifique va au-delà des terminaisons : vocabulaire dédié (드시다, 주무시다, 댁, 말씀), infixe -시-, titres à la place des noms. C'est cité par les enseignants comme la difficulté n°1 des occidentaux car sans équivalent européen.

### 5.2 Le coréen des manuels n'est pas le coréen de la rue

Constats répétés dans les retours d'apprenants ([Teuida](https://www.teuida.net/en/blog/the-real-problem-with-korean-textbooks-and-how-to-learn-better-today), [LearningKR](https://learningkr.com/why-your-korean-isnt-improving/)) :

- Le coréen réel **omet les particules** (밥 먹었어? au lieu de 밥을 먹었어요?), contracte massivement (뭐 해? 그게, 하죠), parle par fragments.
- Témoignage typique : un ingénieur ayant étudié 8 mois de manière classique comprenait « **30 % de ce que les gens disaient réellement** » à Séoul.
- Le vocabulaire des manuels est biaisé vers l'écrit académique ; le parlé regorge d'idéophones, d'argot générationnel, de konglish récent et de discours rapporté contracté (-대, -래, -잖아).
- « Le coréen scripté des manuels est propre, prévisible et neutre ; le coréen réel n'est rien de tout ça. »

**Implication** : le contenu généré par Molago doit être écrit en **해요체 conversationnel naturel** (éventuellement avec dialogues en 반말 contextualisés), avec contractions réelles — pas en style TOPIK. C'est exactement le positionnement de Didi Podcast, dont le succès auprès de l'utilisateur confirme la cible stylistique.

---

## 6. Listes de fréquence coréennes : ce qui existe et leurs limites

### 6.1 Ressources officielles

- **NIKL 한국어 학습용 어휘 목록 (2003)** : 5 965 mots sélectionnés pour l'apprentissage, gradés A (982) / B (2 111) / C (2 872). C'est LA liste de référence, mais triée alphabétiquement, pas par fréquence ([A Flicker of Korean](https://aflickerofkorean.wordpress.com/2018/10/27/6000-most-common-korean-words-found-the-official-list/), [TOPIK Guide](https://www.topikguide.com/6000-most-common-korean-words-1/)).
- **NIKL 현대 국어 사용 빈도 조사 (2002, révisé 2005)** : le vrai corpus de fréquence (textes de manuels, littérature, presse, oral), disponible sur [korean.go.kr](https://korean.go.kr/front/reportData/reportDataView.do?report_seq=303&mn_id=45) et réutilisable (données publiques, y compris pour entraînement d'IA).
- **Listes TOPIK** : ~1 671 mots pour TOPIK I, ~2 662 supplémentaires pour TOPIK II ([Tammy Korean](https://learning-korean.com/elementary/20210101-10466/)).
- **한국어기초사전 (Basic Korean Dictionary, NIKL)** : ~50 000 entrées avec niveau (초/중/고급), définitions simples, exemples, et **API/données ouvertes** — avec version bilingue coréen-français ([Wikipedia](https://en.wikipedia.org/wiki/Basic_Korean_Dictionary)). Ressource clé pour le glossaire de Molago.

### 6.2 Limites pour la vie quotidienne

1. **Biais écrit/académique** : les corpus NIKL sur-pondèrent presse et manuels ; les idéophones, l'argot, le konglish récent et le vocabulaire « logistique » du quotidien (livraison, 배달앱, 무인매장…) y sont sous-représentés ou absents (listes de 2002-2003 : plus de 20 ans d'écart avec la langue actuelle).
2. **Fréquence ≠ utilité personnelle** : la recherche sur la couverture lexicale montre qu'il faut ~4 000 familles de mots pour couvrir 95 % d'un journal, 8 000–9 000 pour 98 % ([Nation 2006](https://www.lextutor.ca/cover/papers/nation_2006.pdf)) — mais le vocabulaire *pertinent pour la vie de l'utilisateur* (ses courses, son quartier, son travail, ses conversations) est un sous-ensemble personnel que les listes génériques ne capturent pas.
3. **Le mot hors contexte est mal appris** : les listes donnent des mots isolés, or les quasi-synonymes coréens (natif vs sino-coréen) ne se départagent qu'en contexte.

**Usage recommandé pour Molago** : les listes NIKL/TOPIK servent d'**armature de calibration** (déterminer si un mot est « attendu connu » au niveau de l'utilisateur, choisir les mots nouveaux à injecter), pas de programme d'étude visible.

---

## 7. Ce que dit la recherche sur l'acquisition du vocabulaire par la lecture

Les fondements scientifiques du concept Molago (« l'apprentissage vient tout seul par la lecture ») sont solides, avec des conditions précises :

1. **Seuil de couverture 95–98 %** : Hu & Nation (2000), répliqué par Kremmel et al. (2023), établissent que la compréhension autonome demande ~98 % de mots connus (1 mot inconnu sur 50) ; 95 % est le minimum pour une compréhension assistée ([Language Learning/Wiley](https://onlinelibrary.wiley.com/doi/10.1111/lang.12622), [synthèse Gianfranco Conti](https://gianfrancoconti.com/2025/02/27/why-the-input-we-give-our-learners-must-be-95-98-comprehensible-in-order-to-enhance-language-acquisition-the-theory-and-the-research-evidence/)). **Le contenu généré doit donc contenir ~2–5 % de mots nouveaux, pas plus.**
2. **Input « compelling »** : Krashen a raffiné son hypothèse i+1 — l'input doit être si intéressant qu'on oublie qu'on apprend ; l'ennui bloque l'acquisition (filtre affectif). Le « narrow reading » (plusieurs textes sur un même sujet) accélère l'acquisition car le contexte partagé fait recirculer le même vocabulaire ([InfinLume](https://www.infinlume.com/blog/krashen-input-hypothesis-language-learning), [Leonardo English](https://www.leonardoenglish.com/blog/comprehensible-input)).
3. **Le glossage fonctionne, et fort** : méta-analyses récentes — lecture glosée : 45,3 % des mots retenus en post-test immédiat vs 26,6 % sans glose ; **les gloses en L1 (français) battent les gloses en L2** ; les gloses multiple-choice sont les plus efficaces, les glossaires en fin de texte les moins efficaces ([Frontiers meta-analysis 2026](https://www.frontiersin.org/journals/language-sciences/articles/10.3389/flang.2026.1815571/full), [Zhang & Ma 2024](https://journals.sagepub.com/doi/abs/10.1177/13621688211011511)). → Le dictionnaire intégré de Molago doit être **au toucher, dans le texte, en français**.
4. **Répétitions nécessaires** : l'apprentissage incident demande de multiples rencontres (effet moyen r = 0,34 de la répétition ; les études convergent vers ~7–12 rencontres espacées pour ancrer un mot) ([méta-analyse Uchihara et al.](https://www.academia.edu/38264254/The_Effects_of_Repetition_on_Incidental_Vocabulary_Learning_A_Meta_Analysis_of_Correlational_Studies)). → Molago doit **faire recirculer les mots injectés dans les histoires des jours suivants** (espacement croissant), ce qui est plus puissant et invisible qu'un paquet Anki.
5. **Incident + intentionnel > incident seul** : la lecture avec exercices ciblés sur les mots bat la lecture seule ; l'apprentissage espacé bat le massé ([Cambridge meta-analysis](https://www.cambridge.org/core/journals/language-teaching/article/how-effective-is-second-language-incidental-vocabulary-learning-a-metaanalysis/E38E3468FD2090B1FA3051051DE8E70C)). → Un micro-quiz optionnel de 60 secondes après lecture (reconnaissance en contexte, pas de récitation) capte ce bonus sans réintroduire le « par-cœur ».

---

## 8. Stratégies documentées d'expatriés et méthodes reconnues

### 8.1 Patterns récurrents chez les occidentaux long-terme qui réussissent

Les récits publiés (blogs, Substack d'expatriés comme [Mathias Barra](https://mathiasbarra.substack.com/p/reflections-on-a-year-lived-in-korea), forums, [In My Korea](https://inmykorea.com/learn-korean-to-live-in-korea/)) convergent sur quelques constantes :

- **Vivre en Corée ne suffit pas** : l'immersion passive n'apprend rien sans input compréhensible actif — d'innombrables expatriés de 10+ ans plafonnent au niveau survie. Le facteur discriminant est une routine quotidienne d'input à niveau adapté.
- Ceux qui percent le plateau intermédiaire citent presque toujours : (a) le passage à du **contenu natif ou semi-natif quotidien sur des sujets qui les intéressent**, (b) l'étude des **racines hanja**, (c) un système de capture des mots rencontrés (sentence mining) plutôt que des listes préfabriquées.
- La motivation par le **besoin réel** (démarches administratives, voisins, travail) surpasse la motivation culturelle — pertinent pour un utilisateur indifférent à la K-pop.

### 8.2 Ressources et méthodes de référence

| Ressource | Nature | Pertinence Molago |
|---|---|---|
| **TTMIK (Talk To Me In Korean)** | Leçons audio structurées, « Iyagi » (conversations naturelles), News in Korean, Stories app (lecteurs gradés 10 niveaux) | Référence du ton conversationnel ; leur « News in Korean » = preuve de la demande pour l'actu simplifiée ([review](https://www.alllanguageresources.com/talk-to-me-in-korean/)) |
| **How to Study Korean** | Grammaire exhaustive gratuite + unités hanja | Référence pour l'architecture hanja ([HTSK](https://www.howtostudykorean.com/)) |
| **Didi's Korean Culture Podcast** | Histoires/culture en coréen clair, 해요체, sous-titres KO+EN, 2 vidéos/semaine | **Le gold standard stylistique pour Molago** : narration calme, sujets de société, niveau intermédiaire ([chaîne](https://www.youtube.com/@DidiKoreanPodcast)) |
| **태웅쌤 Comprehensible Input Korean, Comprehensible Korean** | CI pur façon Krashen, par niveaux | Modèles de calibration i+1 ([CI Wiki Korean](https://comprehensibleinputwiki.org/wiki/Korean)) |
| **Kimchi Reader** | Extension/app : dictionnaire popup, lemmatisation, tracking Unknown→Seen→Known, stats de couverture, mining vers Anki | **Concurrent/inspiration directe** : prouve la faisabilité technique du tracking de vocabulaire personnel en coréen ([kimchi-reader.app](https://kimchi-reader.app/), [Show HN](https://news.ycombinator.com/item?id=38059396)) |
| **LingQ / Migaku / Refold** | Écosystèmes input + SRS | Migaku vise « les ~1 500 mots pour suivre 80 % de Netflix » — même logique de couverture ([Migaku](https://migaku.com/blog/korean/start-learning-korean)) |
| **한국어기초사전 / Naver Dict** | Dictionnaires ; le premier a une API ouverte et une version KO-FR | Source de données pour le glossaire |
| **Graded readers** (Routledge Intermediate Korean Reader, TTMIK Stories, Yonsei readers) | Lecture graduée | Preuve du format, mais sujets génériques — la faille que Molago comble avec la personnalisation |

---

## 9. Implications concrètes pour Molago 2.0

### A. Calibration du contenu (le cœur du produit)

1. **Règle des 95–98 %** : chaque histoire du matin doit viser ~96–98 % de mots déjà connus/supposés connus, soit **5 à 12 mots nouveaux pour un texte de 300–400 mots** (2–4 min de lecture). Ni plus (frustration), ni moins (stagnation).
2. **Modéliser le vocabulaire connu de l'utilisateur** : initialiser avec NIKL A+B (~3 000 mots) + un test de placement indolore (auto-marquage « je connais / je ne connais pas » sur un échantillon), puis affiner en continu via les taps sur le glossaire (mot tapé = probablement inconnu ; mot jamais tapé sur 5 rencontres = connu). C'est le modèle Kimchi Reader (Unknown → Seen → Known), à répliquer.
3. **Écrire en 해요체 conversationnel naturel** (style Didi Podcast) : contractions réelles (그게, 하죠, -잖아요), particules omises dans les dialogues, PAS de style TOPIK/합쇼체 — sauf pour les résumés d'actualité où un style journalistique léger est authentique.

### B. Injection méthodique du vocabulaire

4. **Sélection des mots nouveaux par triple filtre** : (a) fréquence corpus (NIKL 빈도 조사), (b) pertinence pour les centres d'intérêt et la vie quotidienne de l'utilisateur, (c) **rendement morphologique** — prioriser les mots dont la racine hanja débloque une famille.
5. **Recirculation programmée** : tout mot injecté doit réapparaître naturellement dans les histoires suivantes à J+1, J+3, J+7, J+16… jusqu'à ~8–10 rencontres. C'est le SRS invisible — l'espacement est dans le contenu, pas dans des cartes. C'est LA fonctionnalité différenciante que ni les graded readers ni Kimchi Reader n'offrent.
6. **Narrow reading** : enchaîner 2–4 histoires sur un même thème dans la semaine (le vocabulaire du thème recircule gratuitement et le contexte booste la compréhension).

### C. Glossaire et hanja

7. **Glose au toucher, en français, dans le texte** (pas de glossaire en bas de page — démontré moins efficace). Afficher : sens en contexte, forme de dictionnaire (lemme), et la phrase d'exemple courante.
8. **Panneau « famille de mots »** dans chaque glose : pour un mot sino-coréen, montrer la décomposition en racines (학교 = 학 étude + 교 école) et 3–5 mots frères déjà connus ou à venir. Effet multiplicateur documenté (§3) + satisfaction intellectuelle pour un profil analytique. Tenir un inventaire des ~300 racines les plus rentables et tracker leur découverte.
9. **Marquer les konglish et faux amis** d'un badge dédié (gain rapide, plaisir de reconnaissance) et introduire progressivement les idéophones dans les dialogues (couche absente des manuels, très « vie réelle »).

### D. Le mix flashcards + contenu

10. **Renverser le rapport** : le contenu est le plat, les flashcards le condiment. Après lecture : micro-quiz optionnel de 3–5 questions de *reconnaissance en contexte* (phrase de l'histoire avec trou, 3 choix — le format « multiple-choice gloss » est le plus efficace selon les méta-analyses). Jamais de récitation coréen→français à froid.
11. **Tableau de bord de couverture, pas de streak de cartes** : montrer « vous connaissez ~4 200 mots, 96,5 % de couverture des textes du quotidien » — métrique motivante, honnête, alignée sur la recherche (objectif long terme : 8 000–9 000 familles pour l'autonomie totale).

### E. Contenu du matin

12. **Deux formats en alternance** : (a) résumé d'actualité (2–3 brèves Corée/monde sur ses sujets — style sino-coréen, registre écrit léger), (b) petite histoire/chronique de vie quotidienne en Corée (registre parlé, mots natifs et idéophones). Les deux couches lexicales (§2) sont ainsi travaillées chacune dans son registre naturel.
13. **Audio TTS de qualité** en option : Didi Podcast fonctionne parce que c'est *écouté et lu* ; la double modalité augmente la rétention et prépare la conversation réelle.

---

## Sources principales

- FSI / State.gov — [Foreign Language Training](https://www.state.gov/national-foreign-affairs-training-center/foreign-language-training) ; [Korea Times](https://www.koreatimes.co.kr/southkorea/society/20171201/korean-exceptionally-difficult-language-to-learn-us-agency)
- [Wikipedia — Sino-Korean vocabulary](https://en.wikipedia.org/wiki/Sino-Korean_vocabulary) ; [Wikipedia — Konglish](https://en.wikipedia.org/wiki/Konglish) ; [Wikipedia — Basic Korean Dictionary](https://en.wikipedia.org/wiki/Basic_Korean_Dictionary)
- Hanja : [UMN Conservancy — Studying Hanja-Based Syllables Improves Korean Vocabulary Retention](https://conservancy.umn.edu/items/3e0271c5-eafe-4dd6-b96e-b1abe104095a) ; [How to Study Korean — Hanja](https://www.howtostudykorean.com/hanja-unit-1-lessons-1-20/hanja-lesson-1/) ; [Sofie to Korea](https://sofietokorea.com/2021/07/04/how-im-studying-hanja-and-why-you-should-too/) ; [Speechling](https://speechling.com/blog/korean-hanja-how-i-learned-hanja-and-how-you-can-too/) ; [Clozemaster](https://www.clozemaster.com/blog/best-ways-to-learn-korean-vocabulary/)
- Couverture lexicale : [Nation 2006 — How Large a Vocabulary Is Needed](https://www.lextutor.ca/cover/papers/nation_2006.pdf) ; [Kremmel et al. 2023 — réplication Hu & Nation](https://onlinelibrary.wiley.com/doi/10.1111/lang.12622) ; [Schmitt et al. 2011](https://onlinelibrary.wiley.com/doi/10.1111/j.1540-4781.2011.01146.x) ; [Conti — 95-98% comprehensible](https://gianfrancoconti.com/2025/02/27/why-the-input-we-give-our-learners-must-be-95-98-comprehensible-in-order-to-enhance-language-acquisition-the-theory-and-the-research-evidence/)
- Glossage & répétition : [Frontiers 2026 — meta-analysis glosses](https://www.frontiersin.org/journals/language-sciences/articles/10.3389/flang.2026.1815571/full) ; [Zhang & Ma 2024](https://journals.sagepub.com/doi/abs/10.1177/13621688211011511) ; [Uchihara et al. — repetition meta-analysis](https://www.academia.edu/38264254/The_Effects_of_Repetition_on_Incidental_Vocabulary_Learning_A_Meta_Analysis_of_Correlational_Studies) ; [Cambridge — incidental vocabulary meta-analysis](https://www.cambridge.org/core/journals/language-teaching/article/how-effective-is-second-language-incidental-vocabulary-learning-a-metaanalysis/E38E3468FD2090B1FA3051051DE8E70C)
- Registres : [90 Day Korean — Speech Levels](https://www.90daykorean.com/korean-speech-levels/) ; [LingoDeer](https://blog.lingodeer.com/korean-speech-levels/) ; [Migaku — 반말 guide](https://migaku.com/blog/korean/korean-informal-speech) ; [Teuida — problème des manuels](https://www.teuida.net/en/blog/the-real-problem-with-korean-textbooks-and-how-to-learn-better-today) ; [LearningKR](https://learningkr.com/why-your-korean-isnt-improving/)
- Listes de fréquence : [NIKL 현대 국어 사용 빈도 조사](https://korean.go.kr/front/reportData/reportDataView.do?report_seq=303&mn_id=45) ; [A Flicker of Korean — liste officielle 6000 mots](https://aflickerofkorean.wordpress.com/2018/10/27/6000-most-common-korean-words-found-the-official-list/) ; [TOPIK Guide](https://www.topikguide.com/korean-frequency-list-top-6000-words/) ; [Tammy Korean — listes TOPIK](https://learning-korean.com/elementary/20210101-10466/)
- Ressources & CI : [Comprehensible Input Wiki — Korean](https://comprehensibleinputwiki.org/wiki/Korean) ; [Didi's Korean Culture Podcast](https://www.youtube.com/@DidiKoreanPodcast) ; [Kimchi Reader](https://kimchi-reader.app/) ; [AllLanguageResources — TTMIK review](https://www.alllanguageresources.com/talk-to-me-in-korean/) ; [Migaku Korean](https://migaku.com/blog/korean/start-learning-korean) ; [Krashen i+1](https://www.infinlume.com/blog/krashen-input-hypothesis-language-learning)
- Konglish : [Migaku — false friends](https://migaku.com/blog/korean/korean-false-friends) ; [KoreanClass101 — loanwords](https://www.koreanclass101.com/blog/2021/05/13/english-loanwords-in-korean/) ; Idéophones : [Lingopie — onomatopoeia](https://lingopie.com/blog/korean-onomatopoeia/)
