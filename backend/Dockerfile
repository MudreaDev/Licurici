# syntax=docker/dockerfile:1
# Imagine multi-stage (README §18): build separat de runtime, utilizator non-root, fără secrete.
# Aceeași imagine rulează API-ul (dist/main.js) și worker-ul (dist/worker.js) — ADR-05.

FROM node:24-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
# --ignore-scripts: nu rulăm scripturi de instalare ale dependențelor (supply chain).
RUN npm ci --ignore-scripts

FROM deps AS build
COPY . .
# `prisma generate` nu se conectează la bază; URL-ul e doar un substituent cerut de config.
RUN DATABASE_URL=postgresql://build:build@localhost:5432/build npx prisma generate \
 && npx nest build

# Etapa folosită de serviciul `migrate` (are Prisma CLI).
FROM build AS migrate
CMD ["npx", "prisma", "migrate", "deploy"]

FROM build AS prune
RUN npm prune --omit=dev --ignore-scripts

FROM node:24-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /app
COPY --from=prune --chown=node:node /app/node_modules ./node_modules
COPY --from=prune --chown=node:node /app/dist ./dist
COPY --chown=node:node package.json ./
USER node
EXPOSE 3000
HEALTHCHECK --interval=15s --timeout=3s --start-period=20s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health || exit 1
CMD ["node", "dist/main.js"]
