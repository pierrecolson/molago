# 06 — Contenu d'apprentissage généré par LLM : état de l'art, qualité, pièges (2024-2026)

> Recherche menée en juillet 2026. Sources : articles arXiv/ACL 2024-2026, blogs de linguistes et d'enseignants de coréen, benchmarks TTS/STT indépendants, documentation produits (Naver Cloud, ElevenLabs, OpenAI, Google), retours d'expérience Reddit/HN.

## Résumé exécutif

Générer du contenu gradué par LLM fonctionne, mais le prompting seul est fragile : le phénomène d'**alignment drift** (les modèles dérivent vers leur complexité naturelle) est documenté, et le contrôle lexical strict échoue partiellement (~0,5 % de mots hors vocabulaire dans le meilleur cas publié, SRS-Stories 2025). La recette gagnante validée académiquement est un **pipeline itératif** : prompt simple avec liste de mots cibles → détection des mots hors niveau par analyse morphologique → réécriture ciblée par le LLM — et non le "constrained decoding". Le coréen des LLM frontière (Claude, GPT) est grammaticalement correct mais reconnaissablement artificiel : sur-usage des virgules, style nominal, registre trop formel (당신, 습니다 hors contexte), monotonie syntaxique — des marqueurs quantifiés par KatFishNet et XDAC (ACL 2025). Les mitigations efficaces : few-shot avec du vrai coréen parlé, consigne explicite de registre (해요체), révision par un second passage LLM, et ancrage du glossaire dans un dictionnaire réel (API krdict, gratuite). La TTS coréenne est devenue excellente et bon marché (OpenAI ~0,015 $/min, Google Chirp 3 HD, Naver Clova Voice) ; le STT coréen est mûr via Whisper fine-tuné ou Clova Speech. Attention au résultat contre-intuitif de Storyfier (UIST 2023) : l'histoire générée plaît, mais si l'IA fait *tout* le travail, la rétention baisse — il faut garder un effort actif de récupération (cloze, rappel) dans la boucle.

---

## 1. Génération de textes gradués par niveau : ce qui est documenté

### 1.1 Le prompting CEFR fonctionne… au début

La littérature 2024-2026 converge : demander à un LLM d'écrire "au niveau A2/B1" produit un premier jet raisonnable, mais le contrôle se dégrade.

- **Alignment drift** : l'étude [Alignment Drift in CEFR-prompted LLMs for Interactive Spanish Tutoring](https://arxiv.org/html/2505.08351v1) (2025) teste 4 modèles open-source 7B-12B (Llama-3.1-8B, Gemma-3-12B, Mistral-7B, Qwen-2.5-7B) : les métriques de lisibilité distinguent bien A1/B1/C1 en début de conversation, puis **les niveaux convergent au fil des tours** — les modèles "reviennent à leur comportement non contraint". C'est moins critique pour Molago (génération one-shot d'un texte, pas un dialogue long), mais cela vaut aussi pour les textes longs : la fin d'une histoire de 800 mots est souvent plus difficile que le début.
- **Prompting vs fine-tuning** : [Toward Beginner-Friendly LLMs for Language Learning](https://arxiv.org/pdf/2506.04072) (japonais, niveaux JLPT — cadre très transposable au TOPIK coréen) montre que le prompting seul obtient un succès modéré et que le fine-tuning tient mieux la difficulté sur la durée. Point pratique : les niveaux JLPT/TOPIK avec listes de vocabulaire officielles sont un meilleur signal de contrôle que le CEFR flou.
- **Taille du modèle** : la synthèse [CEFR-Aligned Language Model (CELL)](https://www.emergentmind.com/topics/cefr-aligned-language-model-cell) note que la performance du prompting **chute fortement sur les modèles 7B-12B** ; les modèles frontière (Claude, GPT-4/5) tiennent nettement mieux la consigne. Pour un outil personnel, utiliser un modèle frontière élimine une grande partie du problème que la littérature mesure sur des petits modèles.
- **Approche "prompt accessible"** : une étude 2026 sur l'espagnol grand débutant ([Linguistic control in AI text generation](https://www.researchgate.net/publication/400345278_Linguistic_control_in_AI_text_generation_An_accessible_prompt-based_approach_targeting_L2_Spanish_absolute_beginners)) valide une méthode sans fine-tuning : contraintes définies par **une liste de vocabulaire catégorisée + des phrases d'exemple illustrant les structures grammaticales autorisées**, injectées dans le prompt. C'est exactement le pattern "few-shot avec du vrai contenu du niveau visé".

### 1.2 Vocabulaire : les pièges du contrôle statique

- Les listes de vocabulaire figées gèrent mal les **mots composés et la morphologie** ([CEFR-Annotated WordNet, 2025](https://arxiv.org/html/2510.18466)) : en coréen agglutinant, c'est central — 먹었어요 doit être reconnu comme 먹다 + passé + 해요체, sinon le vérificateur compte des "mots inconnus" fantômes. Toute vérification doit passer par un **analyseur morphologique** (Kiwi, MeCab-ko, Okt), jamais par une comparaison de chaînes.
- [Alfter (2024)](https://arxiv.org/html/2510.18466) a tenté de générer des listes de vocabulaire alignées CEFR par LLM dans 5 langues : performances médiocres hors anglais. **Ne pas demander au LLM de décider ce qui est "niveau 2"** — utiliser les listes officielles TOPIK I/II (~2 000 / ~6 000 mots) ou la liste de fréquence du National Institute of Korean Language comme référentiel externe.

### 1.3 Le benchmark le plus proche de Molago : SRS-Stories (déc. 2025)

[SRS-Stories: Vocabulary-constrained multilingual story generation for language learning](https://arxiv.org/html/2512.18362) est quasiment le blueprint de Molago 2.0 : génération d'histoires personnalisées **n'utilisant que le vocabulaire connu de l'utilisateur** (synchronisé avec un système de répétition espacée), en anglais, chinois et polonais. Enseignements chiffrés :

- **Le prompt simple bat les stratégies élaborées** : "écris une histoire de 500-750 mots utilisant chacun de ces mots cibles au moins 3 fois" a obtenu les meilleures notes humaines (grammaire 4,04/5, cohérence 4,27/5, intérêt 4,06/5) contre des stratégies de planification en 3 étapes.
- **La boucle de réécriture bat le décodage contraint** : mots hors vocabulaire résiduels **0,52 %** avec prompt simple + réécriture des mots inconnus, contre **6,71 %** pour le constrained beam search (qui dégrade aussi la fluidité). Le pattern gagnant : générer → détecter les mots hors liste → demander au LLM de réécrire ces passages avec des synonymes plus simples.
- Limite honnête : il reste toujours quelques mots hors vocabulaire, surtout aux bas niveaux ; et les métriques "LLM-as-judge" corrèlent moins bien avec le jugement humain hors anglais (0,21-0,43 pour chinois/polonais vs 0,46-0,56 pour l'anglais) — méfiance envers l'auto-évaluation du coréen par LLM.

---

## 2. Qualité du coréen généré par les LLM actuels

### 2.1 Compétence brute : bonne et en progrès

- Sur [KMMLU](https://github.com/daekeun-ml/evaluate-llm-on-korean-dataset) (connaissances en coréen), GPT-5.1 atteint ~83,7 % (0-shot) fin 2025 ; les modèles frontière dominent. Mais KMMLU teste la *connaissance*, pas la *naturalness*.
- [HyperCLOVA X](https://clova.ai/en/hyperclova) (Naver) a été entraîné sur **~6 500 fois plus de données coréennes que GPT-4** et [dépasse GPT-4 sur les questions spécifiquement coréennes](https://www.kedglobal.com/artificial-intelligence/newsView/ked202402270003) (benchmark KMMLU, culture/institutions/expressions locales). Le consensus coréen : GPT-4o produit encore des tournures "traduites" (번역투) là où HyperCLOVA X sonne local. HyperCLOVA X est accessible via l'API CLOVA Studio (Naver Cloud) ; des variantes open-weight (HyperCLOVA X SEED) existent.
- [KoGEM](https://arxiv.org/pdf/2506.01237) (ACL 2025) montre un **écart persistant LLM vs humains natifs sur la compétence linguistique fine** : phénomènes morphosyntaxiques complexes, jugements de naturalité mal alignés avec l'intuition native.

### 2.2 Les marqueurs mesurés du "coréen d'IA"

Deux papiers ACL 2025 ont quantifié ce qui rend le coréen généré reconnaissable — précieux comme *checklist inverse* pour Molago :

**[KatFishNet](https://arxiv.org/abs/2503.00032)** (détection de texte coréen généré, ACL 2025) :
- **Sur-usage des virgules** : 61 % des phrases générées en contiennent, contre 26 % chez les humains ; virgule après terminaison connective dans 19,8 % des cas (LLM) vs 4,1 % (humains). Un simple détecteur de virgules permet 94,9 % AUROC de détection.
- **Style nominal** : les LLM portent l'information par les noms ; les humains par les terminaisons verbales et prédicats (plus dynamique, plus oral).
- **Monotonie syntaxique** : diversité des n-grammes de POS plus faible ; espacement (띄어쓰기) mécaniquement parfait là où les humains varient.

**[XDAC](https://aclanthology.org/2025.acl-long.1108/)** (détection de commentaires générés, 1M de commentaires générés par 14 modèles) : détection à 98,5 % de F1 — le coréen informel bref généré par LLM reste très identifiable sur les dimensions morphologiques et sociolinguistiques.

### 2.3 Registre : le problème n°1 pour un usage "vie quotidienne"

- Problème documenté par les enseignants ([Talk To Me In Korean](https://blog.talktomeinkorean.com/how-to-use-chatgpt-to-maximize-your-korean-practice/)) : ChatGPT utilise **당신** (trop formel/bizarre en conversation) ou **너** (trop familier), et dérive vers un 합쇼체/문어체 de rédaction alors que la vie quotidienne se passe en **해요체** et 반말. Le coréen a 6 niveaux de discours ; les LLM, par défaut, écrivent comme un article ou un manuel, pas comme Didi Podcast.
- Sans consigne explicite, un LLM produit du coréen *écrit* : c'est exactement l'inverse du besoin de Molago (vocabulaire de conversation). La consigne de registre ("해요체 tout du long, comme quelqu'un qui raconte une histoire à un ami, style oral, pas de 당신, phrases courtes se terminant par des verbes") + 2-3 paragraphes d'exemple de vrai coréen parlé changent radicalement la sortie.

### 2.4 Erreurs typiques à surveiller (synthèse)

1. **번역투** (translationese) : calques de structures anglaises, pronoms sujets explicites partout (le coréen les omet), passifs artificiels.
2. **Registre incohérent** : mélange 해요체/합니다체 dans un même texte, 당신.
3. **Ponctuation et rythme non coréens** : virgules partout, phrases longues à subordonnées empilées.
4. **Collocations approximatives** : mot juste au dictionnaire mais combinaison inhabituelle (le type d'erreur le plus dangereux pour un apprenant, car invisible).
5. **Vocabulaire daté ou trop littéraire** au lieu du mot que les gens utilisent vraiment (ex. classique : proposer 서적 au lieu de 책).

---

## 3. Histoires personnalisées selon les intérêts : prior art

### 3.1 Académique

- **[Storyfier](https://dl.acm.org/doi/10.1145/3586183.3606786)** (UIST 2023, N=28) — résultat **contre-intuitif et crucial** : les apprenants préfèrent les histoires générées couvrant leurs mots cibles et trouvent la charge de travail réduite, **mais rappellent et réutilisent moins bien les mots cibles** qu'avec l'outil baseline sans IA. Interprétation des auteurs : l'assistance IA réduit l'effort cognitif de traitement (desirable difficulty). Leçon pour Molago : l'histoire doit rester le vecteur, mais il faut **conserver des moments d'effort actif** (cloze, rappel avant révélation, production) — le mix "contenu + flashcards" prévu est la bonne intuition, à condition que les flashcards restent un exercice de récupération, pas une relecture passive.
- **[SRS-Stories](https://arxiv.org/html/2512.18362)** (2025) : voir §1.3 — la validation la plus directe du concept "histoires contraintes par le vocabulaire de l'utilisateur + SRS".
- **[RetAssist](https://arxiv.org/html/2405.14794)** (2024) : le *retelling* (raconter à nouveau l'histoire lue) assisté améliore l'apprentissage du vocabulaire — piste d'extension orale pour Molago.
- **[LOOM](https://arxiv.org/pdf/2511.21037)** (2025) : mémoire apprenant dynamique (graphe) alimentée par les conversations quotidiennes avec un LLM pour piloter la maîtrise à long terme — le pattern "le système sait ce que tu connais et génère en fonction" est en train de se standardiser.

### 3.2 Produits (2025-2026)

- **[Lenguia](https://www.lenguia.com/)** : histoires générées selon intérêts, longueur, niveau ; **réutilise les mots inconnus dans les histoires suivantes** — le mécanisme le plus proche de l'idée Molago.
- **[Beelinguapp](https://beelinguapp.com/blog/ai-and-beelinguapp:-crafting-the-perfect-stories-for-language-learning)** : passage massif au contenu IA… et [retour de bâton sévère](https://lingopie.com/blog/beelinguapp-review/) ("Proof That Bad AI Can Wreck Language Learning") : contenu IA non relu = qualité perçue en chute. Avertissement : le contenu généré *non vérifié* détruit la confiance.
- **[MeloLingua](https://melolingua.com/ai-story-language-app)**, **LingQ**, **[Speak](https://www.speak.com/)** (valorisé ~1 Md$, backed OpenAI, très fort en Corée) : tout le marché converge vers "comprehensible input personnalisé + IA". Aucun produit grand public ne fait précisément "brief matinal d'actualité/histoires en coréen gradué pour expat francophone" — la niche de Molago est réelle.
- Fils Show HN sur les outils IA d'apprentissage ([exemple, mars 2025](https://news.ycombinator.com/item?id=43303845)) : les retours récurrents des utilisateurs avancés = (1) la personnalisation par les intérêts est le vrai différenciateur, (2) la qualité de la langue générée est le premier reproche, (3) les apps qui mélangent lecture + audio + dictionnaire intégré retiennent mieux.

---

## 4. Injection contrôlée de vocabulaire cible

La littérature "controlled text generation" ([survey ACM](https://dl.acm.org/doi/full/10.1145/3617680)) distingue contraintes sémantiques, structurelles et **lexicales**. Pour les contraintes lexicales en 2026, trois familles :

1. **Hard constrained decoding** (constrained beam search, NeuroLogic) : garantit l'inclusion des mots cibles mais **dégrade la fluidité** et est inapplicable via les API fermées. SRS-Stories mesure 6,71 % de mots hors vocabulaire et une qualité inférieure — à éviter.
2. **Prompting + vérification + réécriture** (soft constraints) : l'état de l'art pratique. Inclusion des mots cibles ~95-100 % avec un modèle frontière quand la liste est courte (5-10 mots), fluidité préservée, résidu hors vocabulaire <1 % après une passe de réécriture.
3. **Fine-tuning avec tokens de contrôle de niveau** : le plus robuste ([Lexical Complexity Controlled Sentence Generation](https://arxiv.org/pdf/2211.14540)) mais coût/complexité injustifiés pour un outil personnel.

Règles pratiques qui ressortent des papiers :
- **5-8 mots nouveaux par texte**, chacun répété **3+ fois dans des contextes différents** (consigne explicite dans le prompt — c'est ce que SRS-Stories demande et mesure : ~1,8-2,4 occurrences obtenues par mot cible).
- Donner au LLM la **liste des mots connus n'est pas scalable** (des milliers de mots) ; donner le *niveau* + la liste des *mots nouveaux à injecter* + interdire explicitement toute rareté ("si un mot n'est pas dans le vocabulaire TOPIK 1-2, reformule") fonctionne mieux, complété par la vérification morphologique a posteriori.
- Le ratio validé par la recherche sur l'input compréhensible : **~98 % de couverture lexicale connue** pour une lecture fluide (cf. doc 01) — le vérificateur doit mesurer ce taux, pas seulement compter les mots cibles.

---

## 5. TTS coréenne (2025-2026) : options, qualité, coûts

| Option | Qualité coréen | Prix indicatif | Notes |
|---|---|---|---|
| **OpenAI gpt-4o-mini-tts** | Bonne, intonation parfois "lue" | **~0,015 $/min** (~[12 $/M tokens audio](https://texttolab.com/blog/openai-tts-pricing)) | Le meilleur rapport qualité/prix ; instructions de style en langage naturel ("voix chaleureuse de conteur") |
| **Google Chirp 3 HD / Gemini TTS** | [Excellente, quasi native en coréen](https://docs.cloud.google.com/text-to-speech/docs/chirp3-hd) | ~30 $/M caractères (Chirp 3 HD) ; Gemini TTS 10-20 $/M tokens audio | Coréen dans les langues lancées en premier ; streaming ; multi-speaker (dialogues !) |
| **ElevenLabs (v2 / v3)** | Très bonne ; [v2 plus stable que v3 en coréen](https://elevenlabs-lab.com/en/post/44) (v3 plus expressive mais prononciation moins constante) | Cher : ~[66-165 $/M caractères selon plan](https://awesomeagents.ai/pricing/voice-tts-pricing/) | Voix clonées, tags émotionnels ; overkill en coût pour un brief quotidien |
| **Naver Clova Voice** | Référence native — [~100 voix](https://www.ncloud.com/product/aiService/clovaVoice), prosodie coréenne la plus naturelle du marché | À l'usage sur Naver Cloud (paramètres émotion/vitesse/pitch ; max 2 000 caractères/appel) | Inscription Naver Cloud (faisable depuis la Corée) ; le choix "qualité coréenne maximale" |

Ordre de grandeur du besoin Molago : un brief de 3 min/jour ≈ 90 min/mois ≈ **1,35 $/mois avec OpenAI**, quelques euros avec Google/Naver — le coût TTS est négligeable. Recommandation : commencer avec gpt-4o-mini-tts ou Gemini TTS (multi-speaker pour les dialogues), tester Clova Voice en A/B si la prosodie déçoit.

## 6. STT coréen (pratique orale éventuelle)

- **Whisper large-v3** vanilla est moyen en coréen ; les [fine-tunes coréens sur zeroth-korean](https://huggingface.co/ghost613/whisper-large-v3-turbo-korean) (Hugging Face, gratuits) réduisent fortement l'erreur. Convention importante : le coréen s'évalue en **CER, pas WER** (agglutination + segmentation variable).
- **Naver Clova Speech** : le meilleur STT coréen commercial (spécialisé accents/registre local, [streaming temps réel depuis 2025](https://koreatechtoday.com/naver-cloud-introduces-real-time-streaming-for-clova-speech-live-broadcasts-with-ai-subtitling/), prix [réduits de 40 %](https://koreaplus-lifes.com/naver-clova-ai-speech-accuracy/)).
- **gpt-4o-transcribe / Realtime API** : suffisant pour de la conversation d'apprentissage, avec l'avantage d'être dans le même écosystème que la génération.
- Piège spécifique apprenant : les STT entraînés sur des natifs sont **indulgents avec l'accent étranger** (ils "corrigent" silencieusement) — un score STT n'est pas un feedback de prononciation fiable. Pour du feedback de prononciation, il faudrait un modèle dédié (hors scope V1).

---

## 7. Le pipeline "génère → vérifie → annote" : état de l'art

Le pattern standard 2025-2026 (cohérent avec SRS-Stories, la littérature CTG et les systèmes d'évaluation TOPIK) :

1. **Générer** (modèle frontière, prompt riche : sujet d'intérêt du jour, registre 해요체, mots cibles ×3, few-shot de coréen parlé authentique).
2. **Vérifier le niveau, hors LLM** : analyse morphologique (Kiwi/MeCab-ko) → lemmes → lookup dans les listes de fréquence/TOPIK → % de couverture connue, liste des intrus. Les [systèmes hybrides "features linguistiques + LLM" pour le TOPIK](https://www.researchgate.net/publication/396040352_A_Hybrid_System_for_Automated_Assessment_of_Korean_L2_Writing_Integrating_Linguistic_Features_with_LLM) battent le LLM seul ; [Ace-CEFR](https://arxiv.org/pdf/2506.14046) (Google, 2025) montre qu'un LLM peut approcher l'expert humain en classement de difficulté, mais le juge le plus fiable et gratuit reste le comptage lexical déterministe.
3. **Réécrire** les passages contenant des intrus (boucle 1-2 fois max — rendements décroissants, cf. SRS-Stories : résidu 0,5 %).
4. **Réviser par un second passage/modèle** ("est-ce naturel à l'oral ? registre cohérent ? collocations correctes ?") — idéalement un modèle différent ou un prompt "réviseur natif sévère" ; c'est la mitigation standard contre le coréen artificiel. Croisement possible : générer avec Claude/GPT, faire relire par HyperCLOVA X (ou inversement).
5. **Annoter le glossaire depuis un dictionnaire réel, pas depuis le LLM** : l'[API du 한국어기초사전 (krdict)](https://krdict.korean.go.kr) du National Institute of Korean Language est **gratuite, avec définitions apprenants et traductions multilingues (dont le français)**, wrappers open-source disponibles ([krdict.py](https://github.com/omarkmu/krdict.py)). Le LLM choisit *quel sens* est utilisé en contexte ; le dictionnaire fournit la définition. Cela neutralise le risque principal d'hallucination (définitions plausibles mais fausses, particulièrement toxiques pour un apprenant qui ne peut pas les détecter — cf. [littérature hallucinations](https://arxiv.org/html/2510.06265v2)).

Coût total du pipeline (généreux) : ~3-5 appels LLM/jour + TTS ≈ **quelques centimes par brief quotidien**.

---

## 8. Risques et mitigations — tableau de synthèse

| Risque | Réalité documentée | Mitigation |
|---|---|---|
| Coréen peu naturel (번역투, style nominal, virgules) | Quantifié par KatFishNet/XDAC ; détectable à 94-98 % | Few-shot avec transcriptions de vrai coréen parlé (style Didi Podcast) ; consigne "phrases courtes finissant par le verbe, peu de virgules" ; passe de révision |
| Sur-formalité / registre incohérent | 당신, dérive 합쇼체 documentées par les enseignants | Registre imposé explicitement (해요체), interdiction de 당신, exemples du bon registre dans le prompt |
| Dérive de niveau (alignment drift) | Convergence des niveaux mesurée sur textes longs/dialogues | Textes courts (300-600 mots) ; vérification lexicale déterministe post-hoc + réécriture |
| Hallucination de sens dans le glossaire | Risque majeur car indétectable par l'apprenant | Glossaire ancré sur krdict ; le LLM ne fait que désambiguïser le sens en contexte |
| Mots cibles absents ou sur-rares | ~2 occurrences obtenues vs 3 demandées (SRS-Stories) | Vérifier le compte d'occurrences, régénérer ou compléter par des phrases d'exemple |
| L'IA rend l'apprentissage trop passif | Storyfier : rétention *inférieure* malgré la préférence | Garder cloze/rappel actif ; le glossaire en tap-to-reveal plutôt qu'affiché d'office |
| Contenu IA de masse qui lasse | Backlash Beelinguapp | Peu de contenu mais bon : 1 brief/jour, relu par pipeline, sur des sujets réellement choisis |

---

## 9. Implications concrètes pour Molago 2.0

1. **Le concept est validé par l'état de l'art.** SRS-Stories (2025) et Lenguia prouvent la faisabilité exacte du cœur de Molago : histoires/briefs quotidiens contraints par le vocabulaire connu + injection de mots nouveaux suivis en SRS. Personne ne le fait pour le coréen orienté "vie d'expat" — construire.

2. **Architecture de génération recommandée** (tout en API, pas de fine-tuning) :
   - Prompt : sujet du jour (intérêts + éventuellement 2-3 titres d'actu récupérés par ailleurs), 5-8 mots cibles issus de la file SRS avec consigne "chaque mot ≥3 fois, contextes variés", registre 해요체 style conteur oral, 2-3 extraits few-shot de coréen parlé authentique (transcrire quelques passages de Didi Podcast une fois pour toutes comme exemplaires de ton).
   - Post-traitement : Kiwi (analyse morphologique) → lemmes → check contre liste TOPIK/fréquence + vocabulaire connu de l'utilisateur → si couverture <97-98 % ou mot cible <3 occurrences → une passe de réécriture ciblée, pas plus.
   - Révision : second appel "tu es un relecteur natif exigeant ; corrige tout ce qui sonne traduit, toute virgule superflue, toute incohérence de registre" — modèle différent si possible (tester HyperCLOVA X via CLOVA Studio comme réviseur : meilleur juge du naturel coréen, et Pierre est en Corée donc l'inscription Naver Cloud est simple).

3. **Glossaire : dictionnaire réel obligatoire.** Intégrer l'API krdict (gratuite, définitions apprenants, traductions françaises) via krdict.py. Le LLM désambiguïse le sens en contexte et peut simplifier la définition, mais la source de vérité est le dictionnaire. Tap-to-reveal, pas d'affichage systématique (préserver l'effort de récupération).

4. **Garder l'effort actif malgré le "sans effort perçu".** La leçon Storyfier : lecture plaisante ≠ rétention. Le mix prévu (contenu + flashcards) est le bon, mais ordonner : lire le brief → 3-5 questions cloze sur les mots cibles dans les phrases mêmes du texte → les mots ratés repartent dans la file SRS et **réapparaissent dans le brief du surlendemain** (la boucle Lenguia/SRS-Stories). Le contenu *est* la révision.

5. **TTS dès la V1, c'est quasi gratuit.** ~1-2 €/mois pour un brief audio quotidien. Commencer avec gpt-4o-mini-tts (instructions de style) ou Gemini TTS (multi-speaker pour dialogues à deux voix, format très Didi Podcast) ; A/B avec Clova Voice si la prosodie déçoit. Le mode lecture+écoute simultanées est le format le plus soutenu par la recherche sur l'input compréhensible.

6. **STT : reporter.** Whisper fine-tuné coréen ou Clova Speech sont mûrs pour une future pratique orale (retelling façon RetAssist), mais ne pas confondre STT et feedback de prononciation. Pas en V1.

7. **Budget qualité : investir dans le prompt, pas dans l'infra.** Les gains viennent, dans l'ordre : (a) few-shot de coréen parlé réel, (b) consigne de registre explicite, (c) vérification lexicale déterministe + une réécriture, (d) passe de révision par second modèle. Le fine-tuning et le constrained decoding sont documentés comme inutiles ou contre-productifs à cette échelle.

8. **Contrôle qualité minimal humain.** Prévoir un bouton "ce passage sonne bizarre" qui logge le texte : Pierre est son propre évaluateur natif-adjacent après 8 ans en Corée, et ce signal permettra d'itérer sur le prompt — c'est le garde-fou que Beelinguapp n'a pas eu.

---

### Sources principales

- [SRS-Stories (arXiv 2512.18362)](https://arxiv.org/html/2512.18362) · [Storyfier (UIST 2023)](https://dl.acm.org/doi/10.1145/3586183.3606786) · [Alignment Drift (arXiv 2505.08351)](https://arxiv.org/html/2505.08351v1) · [Beginner-Friendly LLMs / JLPT (arXiv 2506.04072)](https://arxiv.org/pdf/2506.04072)
- [KatFishNet (arXiv 2503.00032, ACL 2025)](https://arxiv.org/abs/2503.00032) · [XDAC (ACL 2025)](https://aclanthology.org/2025.acl-long.1108/) · [KoGEM (arXiv 2506.01237)](https://arxiv.org/pdf/2506.01237) · [HyperCLOVA X](https://clova.ai/en/hyperclova) / [KED Global](https://www.kedglobal.com/artificial-intelligence/newsView/ked202402270003)
- [Survey CTG (ACM Computing Surveys)](https://dl.acm.org/doi/full/10.1145/3617680) · [Lexical Complexity Controlled Generation (arXiv 2211.14540)](https://arxiv.org/pdf/2211.14540) · [Contrôle linguistique par prompt, espagnol débutant](https://www.researchgate.net/publication/400345278_Linguistic_control_in_AI_text_generation_An_accessible_prompt-based_approach_targeting_L2_Spanish_absolute_beginners)
- [TTMIK sur ChatGPT en coréen](https://blog.talktomeinkorean.com/how-to-use-chatgpt-to-maximize-your-korean-practice/) · [Ace-CEFR (arXiv 2506.14046)](https://arxiv.org/pdf/2506.14046) · [Évaluation hybride TOPIK](https://www.researchgate.net/publication/396040352_A_Hybrid_System_for_Automated_Assessment_of_Korean_L2_Writing_Integrating_Linguistic_Features_with_LLM)
- TTS/STT : [OpenAI TTS pricing](https://texttolab.com/blog/openai-tts-pricing) · [Comparatif TTS 2026](https://awesomeagents.ai/pricing/voice-tts-pricing/) · [Chirp 3 HD](https://docs.cloud.google.com/text-to-speech/docs/chirp3-hd) · [Clova Voice](https://www.ncloud.com/product/aiService/clovaVoice) · [ElevenLabs v3 vs v2 en coréen](https://elevenlabs-lab.com/en/post/44) · [Whisper fine-tuné coréen](https://huggingface.co/ghost613/whisper-large-v3-turbo-korean)
- Produits : [Lenguia](https://www.lenguia.com/) · [Beelinguapp AI](https://beelinguapp.com/blog/ai-and-beelinguapp:-crafting-the-perfect-stories-for-language-learning) / [critique Lingopie](https://lingopie.com/blog/beelinguapp-review/) · [Speak (Forbes)](https://www.forbes.com/sites/rashishrivastava/2025/11/12/this-startup-is-racing-duolingo-to-replace-human-language-tutors-with-ai/) · [krdict.py](https://github.com/omarkmu/krdict.py)
