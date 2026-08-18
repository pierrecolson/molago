# Transcript YouTube par Supadata — design validé

Date : 18 août 2026

## But

Une URL YouTube collée dans Molago redonne un transcript coréen minuté, par un
chemin qui ne dépend ni de la réputation d'une adresse IP ni d'une machine
allumée à la maison.

## Cause racine

Deux tentatives ont échoué, pour deux raisons distinctes.

`yt-dlp` sur Hostinger reçoit « Sign in to confirm you're not a bot » : l'adresse
est celle d'un centre de données. Le wiki de `yt-dlp` est explicite — fournir un
PO token ne lève plus le contrôle dans la majorité des cas, c'est la réputation
de l'adresse qui décide. Aucun réglage ne répare ça.

L'import sur l'appareil (PR #49) avait la bonne adresse mais le mauvais moteur :
`swift-youtube-metadata` 0.1.0 fait une requête HTTP nue vers `timedtext`,
exactement la surface que YouTube a durcie. Le modèle était juste, la librairie
non.

## Ce qui a été écarté

- **Un NAS personnel** : résout pour une personne, plafonne dès les premières
  dizaines d'utilisateurs — une adresse résidentielle unique encaisse quelques
  centaines de requêtes avant les premiers 429 — et suppose une machine allumée.
- **`yt-dlp` derrière des proxies résidentiels loués** : passe l'échelle, mais on
  garderait l'entretien de `yt-dlp` *et* on assumerait le scraping soi-même.
- **Transcrire l'audio** : il faudrait d'abord obtenir l'audio, ce qui est plus
  interdit que de lire des sous-titres. C'est une piste pour du contenu que
  l'utilisateur possède, pas pour YouTube.

## Parcours

1. L'utilisateur colle une URL et touche `Add`.
2. L'app valide que l'URL appartient à YouTube — avant tout accès réseau, donc un
   mauvais lien ne dépense jamais un crédit.
3. L'app demande le transcript à `POST /u/<id>/transcript`.
4. Le VPS interroge Supadata (`lang=ko`, mode natif épinglé) et, en parallèle,
   `videos.list` de l'API YouTube officielle pour le titre, la chaîne, la durée
   et la miniature.
5. Le VPS renvoie des segments minutés en secondes. Il ne stocke rien.
6. Apple Translation traduit les segments sur l'appareil, par lots.
7. L'app écrit un fichier JSON par import dans iCloud, comme depuis la PR #49.

## Pourquoi les métadonnées ne passent pas par Supadata

Le second endpoint de Supadata est facturé un crédit, ce qui diviserait par deux
un quota gratuit de 100 par mois. `videos.list` coûte 1 unité sur 10 000
gratuites par jour, et c'est la seule route officielle du dossier : autant poser
ce morceau correctement.

## Ce que le fournisseur ne décide pas

L'app ne connaît qu'une adresse. Tout ce qui touche à Supadata vit dans
`api/transcript.mjs`. En changer — pour TranscriptAPI, pour un worker maison —
ne touche pas une version déjà publiée. C'est la seule assurance qui vaille
contre la disparition d'un fournisseur.

## Traduction

Apple Translation continue de fournir l'anglais, sur l'appareil. L'anglais que
YouTube renvoie parfois est ignoré : un seul chemin de traduction donne un
résultat homogène d'une vidéo à l'autre.

Les captures photo restent traduites côté serveur par le modèle. L'OCR arrive en
désordre et doit être reconstruit avant d'être traduit — ce n'est pas le même
problème, et les deux chemins sont assumés.

## États et messages

- Import : `Preparing the transcript…`
- URL invalide : `Paste a YouTube video link.`
- Service indisponible : `Molago couldn't reach the transcript service. Try again in a moment.`
- Traduction indisponible : `The transcript couldn't be translated. Download Korean and English in Settings, then try again.`
- Sauvegarde impossible : `The transcript was translated but couldn't be saved. Check that Molago can use iCloud, then try again.`

Une vidéo sans transcript coréen reste ajoutée avec un transcript vide et demeure
regardable dans le lecteur.

## Contraintes

- Aucune clé n'atteint l'app. Elles vivent dans le `.env` du VPS.
- Le mode natif de Supadata est épinglé : la génération par IA est facturée
  2 crédits par minute et ne doit jamais partir toute seule.
- Aucun changement visuel, aucune animation ajoutée.
- Plus aucun appel `yt-dlp`, et plus de Python dans l'image de l'API.
- Les vérifications réelles partent du VPS (voir `CLAUDE.md`) : les clés sont
  restreintes à ses adresses.

## Le plafond, pour plus tard

Il n'existe aucune route officielle vers les sous-titres d'une vidéo tierce :
`captions.download` exige d'être propriétaire ou d'avoir l'autorisation OAuth du
propriétaire. Les Developer Policies interdisent le scraping et l'obtention de
données scrapées ; la règle App Store 5.2.3 demande des preuves de droits.

Ce qui tient Molago du bon côté est déjà en place : le lecteur officiel, aucun
média téléchargé, aucun catalogue dans l'app, et **un transcript par utilisateur,
jamais partagé**. Cette dernière ligne est celle à ne pas franchir — mutualiser
les transcripts côté serveur ferait passer Molago d'un outil de lecture à une
redistribution de sous-titres.

Le jour du Store, la question est produit, pas technique.

## Validation

1. Depuis le VPS, Supadata renvoie 63 segments coréens minutés pour
   `zC4aRaHI-yw` — le repère mesuré par le spike iOS.
2. `POST /u/<id>/transcript` sur Hostinger renvoie les mêmes 63 segments.
3. Une URL non YouTube est refusée avant tout accès réseau.
4. Le lien de référence produit un import complet, visible dans Library et
   lisible hors connexion.
5. Réimporter la même vidéo remplace son fichier sans créer de doublon.
6. Service injoignable : message lisible, aucune trace technique brute.
7. Une vidéo sans sous-titres coréens s'importe et reste regardable.
