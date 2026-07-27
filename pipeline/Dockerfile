# La fabrique nocturne. Elle ne tourne pas en permanence : le cron de l'hôte
# lance un conteneur, il fabrique la journée, il meurt. Pas de démon cron dans
# l'image, donc rien qui puisse dériver silencieusement.
FROM node:22-slim

WORKDIR /app

# Aucune dépendance : le script n'utilise que le `fetch` de Node et son module
# `fs`. Rien à installer, rien à mettre à jour, rien à auditer.
COPY build-day.mjs ./

# La sortie est montée depuis l'hôte, pas écrite dans l'image.
VOLUME /out

ENTRYPOINT ["node", "/app/build-day.mjs", "--out", "/out"]
