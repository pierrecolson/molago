# L'API de capture. Aucune dépendance : `node:http` suffit pour deux routes, et
# une dépendance de moins est une dépendance de moins à tenir à jour sur un VPS
# qui héberge cinq autres piles.
FROM node:22-slim
WORKDIR /app
COPY *.mjs ./
EXPOSE 8080
CMD ["node", "/app/server.mjs"]
