# Produit

<!-- impeccable:product-schema 1 -->

## Plateforme et utilisateur

Application iOS native, personnelle et mono-utilisateur. Elle s’adresse à un Français installé depuis longtemps à Séoul, lecteur autonome du hangul, qui veut progresser avec du coréen réel plutôt qu’avec des exercices ou du contenu imposé.

## Promesse

MoLago transforme ce que l’utilisateur choisit — une photo de sa vie quotidienne ou une vidéo YouTube — en contenu coréen qu’il peut lire, traduire, retrouver et relier à son Wordbook.

Le contenu est toujours initié par l’utilisateur. Aucun article, abonnement, notification ou coût IA n’est déclenché automatiquement.

## Surfaces

- **Library** : `Recent` contient exactement les trois derniers imports, quelle que soit leur date ; `Older` contient le reste sous forme de lignes, chacune portant la même vignette que sa carte. Le titre de l’écran est écrit dans le fil, sans barre de navigation.
- **Capture** : prendre une photo, choisir une photo ou coller directement une URL YouTube.
- **Reader photo** : texte coréen reconstruit, anglais à la demande et retour vers la photo originale.
- **Reader YouTube** : lecteur intégré qui reste visible pendant le défilement, transcript synchronisé sous la vidéo, anglais à la demande, tap sur un mot pour sa fiche et tap sur la minute pour déplacer la vidéo. La lecture reprend en fermant la fiche seulement si elle jouait auparavant.
- **Wordbook** : collection choisie de mots, avec la phrase et la source où chacun a été rencontré. Pour un mot sino-coréen, la fiche montre ses briques Hanja et une famille fondée sur le caractère chinois réellement partagé.
- **Search** : recherche commune dans les imports et les mots gardés.

## Règles produit

1. Zéro dette et zéro culpabilité : aucun compteur de retard, aucune série, aucune pile à rattraper.
2. L’utilisateur choisit tout ce qui entre dans la bibliothèque.
3. Les transcripts importés restent lisibles si YouTube est hors ligne, supprimé ou privé.
4. Photo et YouTube utilisent le même gabarit de carte dans Recent.
5. Le coréen est affiché par défaut ; l’anglais apparaît seulement après une action.
6. Une vidéo sans transcript reste regardable et l’absence est annoncée clairement.
7. Les appels IA éventuels n’ont lieu qu’après un import ou la consultation explicite d’un mot. Une fiche enrichie est mémorisée et ne redépense pas de crédits.

## Langage visuel

- Fond chaud et calme, encre sombre, orange de marque.
- Composants, navigation et typographie système iOS.
- Couleur par surfaces utiles, sans dégradés ni ornements gratuits.
- Mouvement discret, transitions système et respect de Reduce Motion.
- Touches d’au moins 44 points et Dynamic Type sur le texte d’interface.

## Voix de l’interface

L’interface est en anglais ; le contenu est en coréen et les traductions en anglais. Elle annonce un état et une issue sans reproche. Les contrôles nomment leur action. Les erreurs expliquent ce qui s’est passé et ce qui reste disponible.

## Hors périmètre actuel

- Abonnement ou import automatique d’une chaîne YouTube.
- Recommandations de podcasts.
- Téléchargement ou réhébergement des vidéos.
- Articles quotidiens générés, voix de synthèse et notification matinale.
- Flashcards, scores, séries et gamification.

## Source validée

`docs/plans/2026-08-17-import-only-library-design.md` décrit le parcours, les états et les critères de validation actuels. Les anciens documents de génération quotidienne restent historiques et ne décrivent plus le produit actif.
