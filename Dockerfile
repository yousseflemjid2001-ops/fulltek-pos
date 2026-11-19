FROM node:22-alpine

WORKDIR /app

# Copie des fichiers de configuration
COPY apps/cloud-api/package*.json ./

# Dépendances (modules natifs Node.js)
RUN if [ -f package-lock.json ]; then npm ci --omit=dev; fi

# Copie du code source et schémas
COPY apps/cloud-api/src ./src
COPY apps/cloud-api/prisma ./prisma

# Dossier persistant pour la base de données SQLite
RUN mkdir -p /app/data

ENV PORT=4000
ENV NODE_ENV=production
ENV DB_PATH=/app/data/fulltek.db

EXPOSE 4000

VOLUME ["/app/data"]

CMD ["node", "--no-warnings", "src/server.js"]
