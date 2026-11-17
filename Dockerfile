# syntax=docker/dockerfile:1.7
FROM node:24.22.3-alpine3.24 AS dependencies
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm --mount=type=secret,id=proxy_ca \
    if [ -f /run/secrets/proxy_ca ]; then export NODE_EXTRA_CA_CERTS=/run/secrets/proxy_ca; fi; \
    npm ci --omit=dev --ignore-scripts && npm cache clean --force

FROM alpine:3.24.4 AS runtime
ARG APP_VERSION=1.0.0
ARG VCS_REF=unknown
LABEL org.opencontainers.image.title="DevOps Assessment" \
      org.opencontainers.image.description="Observable Node.js assessment service" \
      org.opencontainers.image.source="https://github.com/Iftisam-sandik/devops-engineer-assessment" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}"
ENV NODE_ENV=production PORT=8080 LOG_LEVEL=info ENVIRONMENT=production APP_VERSION=${APP_VERSION}
RUN addgroup -g 1000 node && adduser -D -H -u 1000 -G node node
COPY --from=dependencies /usr/local/bin/node /usr/local/bin/node
COPY --from=dependencies /usr/lib/libstdc++.so.6* /usr/lib/
COPY --from=dependencies /usr/lib/libgcc_s.so.1 /usr/lib/
COPY --from=dependencies /usr/lib/libatomic.so.1* /usr/lib/
WORKDIR /app
COPY --from=dependencies --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node package.json ./
COPY --chown=node:node src ./src
USER node
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e 'fetch("http://127.0.0.1:"+process.env.PORT+"/health").then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))'
STOPSIGNAL SIGTERM
CMD ["node", "src/server.js"]
