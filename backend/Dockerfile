FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev --no-audit

FROM node:20-alpine
LABEL org.opencontainers.image.source="https://github.com/shopmicro/backend"
LABEL org.opencontainers.image.description="ShopMicro backend service"

# Run as non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app

COPY --from=builder /app/node_modules ./node_modules
COPY server.js ./

RUN chown -R appuser:appgroup /app
USER appuser

ENV NODE_ENV=production
ENV PORT=8080

EXPOSE 8080

HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:8080/health || exit 1

CMD ["node", "server.js"]
