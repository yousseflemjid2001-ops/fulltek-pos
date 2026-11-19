FROM node:22-alpine

WORKDIR /app

# Copie des fichiers de configuration
COPY package*.json ./

# Dépendances (optionnelles, cloud-api utilise les modules natifs node:sqlite, node:crypto, node:http)
RUN if [ -f package-lock.json ]; then npm ci --omit=dev; fi

# Copie du code source et schémas
COPY src ./src
COPY prisma ./prisma

# Dossier persistant pour la base de données SQLite
RUN mkdir -p /app/data

ENV PORT=4000
ENV NODE_ENV=production
ENV DB_PATH=/app/data/fulltek.db

EXPOSE 4000

VOLUME ["/app/data"]

CMD ["node", "--no-warnings", "src/server.js"]
