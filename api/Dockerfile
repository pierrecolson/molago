# Node sert les routes, et rien d'autre : les sous-titres arrivent en JSON d'un
# fournisseur (voir transcript.mjs), donc plus de Python ni de yt-dlp à tenir.
FROM node:22-slim
WORKDIR /app
COPY *.mjs ./
EXPOSE 8080
CMD ["node", "/app/server.mjs"]
