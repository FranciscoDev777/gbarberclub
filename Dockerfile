FROM node:22-bookworm-slim

WORKDIR /app

ENV NODE_ENV=production

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       python3 \
       make \
       g++ \
    && rm -rf /var/lib/apt/lists/*

COPY package.json package-lock.json ./

RUN npm ci --omit=dev \
    && npm rebuild sqlite3 --build-from-source \
    && apt-get purge -y --auto-remove python3 make g++ \
    && rm -rf /var/lib/apt/lists/*

COPY . .

EXPOSE 3000

CMD ["node", "server.js"]