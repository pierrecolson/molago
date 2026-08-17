# Node sert les routes. yt-dlp ne télécharge jamais la vidéo : il ne récupère
# que ses métadonnées et ses pistes de sous-titres.
FROM node:22-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 python3-pip ca-certificates \
    && pip3 install --break-system-packages --no-cache-dir yt-dlp \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY *.mjs ./
EXPOSE 8080
CMD ["node", "/app/server.mjs"]
