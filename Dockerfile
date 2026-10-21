FROM node:22-slim AS builder

WORKDIR /app

ARG CLIENT_RELEASE_REPO=graypawn/telegram-web-relay-client
ARG CLIENT_VERSION=12.0.20-relay.6

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl unzip python3 make g++ \
  && rm -rf /var/lib/apt/lists/*

COPY package*.json ./
RUN npm ci --omit=dev

RUN curl -fL --retry 3 \
    "https://github.com/${CLIENT_RELEASE_REPO}/releases/download/client_v${CLIENT_VERSION}/telegram-relay-client-${CLIENT_VERSION}-dist.zip" \
    -o /tmp/client-dist.zip \
  && mkdir -p /app/client-dist \
  && unzip -q /tmp/client-dist.zip -d /app/client-dist \
  && test -f /app/client-dist/index.html \
  && rm /tmp/client-dist.zip

FROM node:22-slim AS runtime

WORKDIR /app

ENV NODE_ENV=production
ENV V2_DIST_PATH=/app/client-dist

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/client-dist ./client-dist
COPY server.js chat-archive.js package.json ./
COPY lib ./lib
COPY public ./public

EXPOSE 9087

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||9087)+'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "server.js"]
