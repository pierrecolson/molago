# MoLago import-only library — design validé

Date : 17 août 2026

## But

MoLago ne fabrique plus de contenu automatiquement. La bibliothèque contient uniquement ce que l’utilisateur choisit d’importer : une photo ou une vidéo YouTube.

Le premier cas YouTube est Didi’s Korean Podcast, mais aucune chaîne n’est ajoutée automatiquement et l’abonnement à une chaîne reste hors périmètre.

## Décisions produit

- Supprimer les quatre articles quotidiens, y compris Vie pratique.
- Supprimer la notification du matin devenue sans objet.
- Conserver la capture photo actuelle, déclenchée uniquement par l’utilisateur.
- Ajouter un champ URL YouTube directement dans l’écran Capture, avec le bouton `Add`.
- Ne pas ajouter d’écran intermédiaire avant le collage du lien.
- Renommer `Notebook` en `Wordbook` dans toute l’interface.

## Bibliothèque

La page principale comporte deux sections :

- `Recent` : les trois derniers imports, sans limite de temps.
- `Older` : tous les imports précédents.

Un import peut donc rester dans `Recent` pendant plusieurs semaines. Au quatrième import, le plus ancien des trois descend dans `Older`.

Les cartes de `Recent` utilisent un gabarit unique pour Photo et YouTube : même largeur, même hauteur totale, même hauteur d’image, même hauteur de texte, même rayon et mêmes marges.

- Photo : la vraie photo de l’utilisateur remplit la zone image.
- YouTube : la miniature YouTube remplit la même zone image.
- `Older` conserve le principe actuel : des lignes compactes séparées par un filet.
- Quand la bibliothèque est vide : `Nothing here yet` puis `Add a photo or YouTube video to start your library.`

## Import YouTube

L’API accepte seulement des URL `youtube.com` ou `youtu.be`. Elle utilise `yt-dlp` sans shell pour :

1. lire l’identifiant, le titre, la chaîne, la durée et la miniature ;
2. télécharger les sous-titres coréens et anglais disponibles ;
3. convertir les repères temporels en phrases synchronisées ;
4. aligner l’anglais sur les repères coréens ;
5. traduire par OpenRouter seulement si aucune piste anglaise n’est disponible ;
6. annoter les mots coréens avec le moteur de glossaire existant afin de conserver le tap sur un mot et l’ajout au Wordbook ;
7. enregistrer l’import dans les fichiers JSON déjà utilisés par l’application.

Une vidéo sans sous-titres coréens reste importable et lisible, mais affiche `No Korean transcript available.` sous le lecteur.

L’import est un geste explicite : les appels IA éventuels n’ont lieu qu’après `Add`. La consultation explicite d’un mot peut également enrichir sa fiche une seule fois ; le résultat est ensuite réutilisé depuis le cache lexical. Aucun crédit n’est dépensé en arrière-plan.

## Lecteur vidéo

- Lecteur YouTube intégré en haut via l’API IFrame officielle dans `WKWebView`.
- Le lecteur reste fixé et légèrement surélevé pendant que le transcript défile dessous.
- Sous-titres masqués dans le lecteur ; le transcript est affiché sous la vidéo.
- Coréen affiché par défaut ; bouton existant pour afficher l’anglais sous chaque phrase.
- La phrase correspondant au temps courant est surlignée et centrée automatiquement.
- Toucher un mot met la vidéo en pause et ouvre sa fiche. Seul le repère temporel déplace la vidéo à cet endroit.
- Fermer la fiche, garder le mot ou le marquer comme connu reprend la lecture uniquement si la vidéo tournait avant le tap.
- Une petite dérive temporaire de synchronisation est acceptable.
- Aucun lecteur vocal ou audio séparé pour une vidéo.

### États du lecteur

- Chargement : le lecteur YouTube conserve sa propre surface de chargement.
- Hors connexion : `You’re offline` / `The transcript is still available.` / bouton `Try again`.
- Vidéo supprimée ou privée : `Video unavailable` / `It may have been removed or made private.`
- Intégration refusée par YouTube : `This video can’t play here` / bouton `Open on YouTube`.

Dans tous ces cas, le transcript déjà importé reste lisible.

## Wordbook

- Toute occurrence visible de `Notebook` devient `Wordbook`.
- La fiche d’un mot utilise la typographie système, sans motifs floraux ni grands caractères décoratifs.
- Elle conserve deux sections : `Where you met it` et `Word family`.
- `Where you met it` montre le contenu d’origine, la phrase exacte et, pour YouTube, le repère temporel permettant de rouvrir la vidéo au bon endroit.
- `How it’s built` décompose les mots sino-coréens en syllabe, Hanja et sens. `Same root` montre trois à cinq mots partageant le même caractère chinois exact ; une réponse IA mélangée est filtrée avant affichage.
- `Word family` reste une liste simple avec séparateurs.
- L’action discrète devient `Remove from Wordbook`.

## Stockage et hors ligne

- L’API expose un index `library` construit à partir des imports existants ; elle ne nécessite pas de base de données.
- L’application conserve cet index et les miniatures sur l’appareil.
- Les anciennes captures photo sont reprises dans la nouvelle bibliothèque.
- Les anciens articles automatiques peuvent rester sur le disque, mais ils ne sont plus affichés.
- Le transcript est stocké avec l’import et ne dépend plus de la disponibilité future de la vidéo.

## Arrêt de la fabrique

- La fabrique nocturne n’est plus un service déployé par MoLago.
- Le script de déploiement ne construit et ne lance plus la fabrique.
- Un ancien cron qui tente encore de lancer le service échoue sans produire de contenu ; il pourra être supprimé du VPS lors du prochain déploiement.

## Hors périmètre

- Abonnement à une chaîne YouTube.
- Import automatique de Didi ou d’une autre chaîne.
- Téléchargement de la vidéo ou de son audio.
- Modification ou hébergement des vidéos YouTube.
- Nouveau système de recommandation, de score ou de progression.

## Critères de validation

1. Une URL Didi valide crée un import avec miniature, lecteur et transcript coréen synchronisé.
2. La traduction anglaise s’affiche uniquement après action de l’utilisateur.
3. Une photo et une vidéo ont des cartes `Recent` strictement identiques en dimensions.
4. Le quatrième import pousse le plus ancien dans `Older`, quelle que soit sa date.
5. Une vidéo indisponible conserve son transcript.
6. Une URL non YouTube ou malformée est refusée avec un message utile.
7. Aucun article quotidien ni notification du matin n’est produit ou affiché.
8. `Wordbook` remplace `Notebook` et la fiche garde son contexte d’origine.
