# Import YouTube local — design validé

Date : 17 août 2026

## But

Une URL YouTube ajoutée dans Molago devient un transcript coréen traduit en anglais sans faire télécharger les sous-titres par Hostinger et sans service payant de transcript.

## Cause racine

`yt-dlp` fonctionne depuis une connexion personnelle mais YouTube refuse l’adresse de centre de données de Hostinger avec une demande de connexion. Changer les options de `yt-dlp` ne change pas la réputation de cette adresse. Le spike iOS a récupéré 63 segments coréens pour `zC4aRaHI-yw` en 1,17 seconde.

## Parcours

1. L’utilisateur colle une URL YouTube et touche `Add`.
2. L’app valide que l’URL appartient à YouTube.
3. `YouTubeTranscript` récupère sur l’iPhone les métadonnées et le transcript coréen minuté.
4. Le framework Apple Translation traduit les segments en anglais, par lots.
5. L’app construit le même `LibraryItem` que le serveur produisait, avec un mot tappable par bloc coréen.
6. Un fichier JSON autonome est écrit dans iCloud Documents. Sans iCloud, le même fichier reste dans Application Support sur l’appareil.
7. Au retour à Library, `DayStore` fusionne les imports iCloud, le cache local et les imports historiques du serveur. Pour un même `slot`, la version iCloud est prioritaire.

## Stockage et synchronisation

Chaque import vit dans `Documents/imports/<slot>.json`. Un fichier par import évite qu’un appareil écrase toute la bibliothèque écrite par un autre. Sur un autre appareil, Molago demande le téléchargement des espaces réservés iCloud avant de décoder les fichiers disponibles.

Le cache `library-cache.json` reste local pour l’ouverture immédiate. Il est régénéré à partir des sources fusionnées ; il n’est pas la source de vérité synchronisée.

## Traduction et vocabulaire

Apple Translation fournit la traduction anglaise des phrases. Le modèle coréen–anglais peut être téléchargé au premier import et les traductions suivantes fonctionnent sur l’appareil.

Les mots du transcript sont immédiatement tappables, mais ne sont pas pré-enrichis. Leur fiche utilise le chemin de consultation explicite déjà existant. La suppression complète de Hostinger pour la photo et l’enrichissement lexical n’appartient pas à ce changement.

## États et messages

- Import : `Preparing the transcript…` puis `The first translation may download Korean and English.`
- URL invalide : `Paste a YouTube video link.`
- Réseau ou YouTube indisponible : `YouTube couldn’t provide this transcript. Check your connection and try again.`
- Traduction indisponible : `The transcript couldn’t be translated. Download Korean and English in Settings, then try again.`
- Sauvegarde impossible : `The transcript was translated but couldn’t be saved. Check that Molago can use iCloud, then try again.`

Une vidéo sans transcript coréen reste ajoutée avec un transcript vide et demeure regardable dans le lecteur.

## Contraintes

- iOS 18 minimum, Swift 6.
- Dépendance `swift-youtube-metadata` épinglée à `0.1.0` et produit `YouTubeTranscript` seulement.
- Aucun changement visuel, aucune animation ajoutée.
- Aucun appel Supadata.
- Aucun appel à la route Hostinger `/youtube`.

## Validation

1. Le lien `zC4aRaHI-yw` produit un import local avec titre, miniature, 63 segments coréens minutés et traduction anglaise sur un iPhone physique.
2. L’import apparaît dans Library après fermeture de Capture et reste lisible hors connexion.
3. Le fichier d’import apparaît sur un second appareil connecté au même compte iCloud.
4. Réimporter la même vidéo remplace son fichier sans créer de doublon.
5. Une URL non YouTube est refusée avant tout accès réseau.
6. Aucun message ne montre une commande `yt-dlp` ou une erreur technique brute.

## Ce qui a remplacé ce document (18 août 2026)

Ce design est **caduc**. Le modèle était juste — l'import part de l'appareil,
Apple Translation traduit, le fichier vit dans iCloud — mais le moteur ne l'était
pas : `swift-youtube-metadata` 0.1.0 interroge `timedtext` par une requête HTTP
nue, exactement la surface que YouTube a durcie. La dépendance a été retirée.

Les sous-titres viennent désormais de `POST /u/<id>/transcript` sur le VPS, qui
lit Supadata pour le coréen et la YouTube Data API pour les métadonnées. Les deux
contraintes ci-dessus — « Aucun appel Supadata », « Aucun appel à la route
Hostinger » — ne tiennent donc plus. Elles sont laissées telles quelles : elles
disent ce qu'on croyait le 17 août, et l'histoire ne se réécrit pas.

Le reste du document vaut toujours : le parcours, les messages d'état, et la
règle qu'une vidéo sans transcript coréen reste importable et regardable.

Voir [`2026-08-18-supadata-transcript-design.md`](2026-08-18-supadata-transcript-design.md).
