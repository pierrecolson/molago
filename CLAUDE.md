# Conventions de travail

## Les vérifications réelles partent du VPS

Toute commande qui appelle une API externe ou qui vérifie la stack déployée se
lance **depuis le VPS**, jamais depuis une machine locale ni depuis une session
distante :

```bash
ssh root@srv1405219.hstgr.cloud "curl -s '...'"
```

Ce n'est pas une préférence de confort. Les clés d'API sont restreintes aux
adresses du VPS — `76.13.181.11` et `2a02:4780:5e:ae3f::1` — donc un appel lancé
d'ailleurs renvoie un `403` qui n'apprend rien sur le code. Tester depuis la
machine qui appellera vraiment vérifie d'un seul geste la clé, sa restriction, la
connectivité sortante et la réponse du fournisseur.

Cela couvre : les appels à Supadata et à la YouTube Data API, les requêtes vers
les routes de `molago.srv1405219.hstgr.cloud`, et toute vérification d'après
déploiement.

Cela ne couvre pas les tests unitaires (`node --test api/*.test.mjs`) : ils sont
purs, n'ouvrent aucune connexion, et se lancent là où l'on écrit le code. Un test
qui aurait besoin du réseau pour passer est un test à corriger, pas à déplacer.
