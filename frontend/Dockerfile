FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
ARG VITE_BACKEND_URL=http://backend:8080
ARG VITE_ML_URL=http://ml-service:5000
ENV VITE_BACKEND_URL=$VITE_BACKEND_URL
ENV VITE_ML_URL=$VITE_ML_URL
RUN npm run build

FROM nginx:1.25-alpine
LABEL org.opencontainers.image.description="ShopMicro frontend"

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

RUN chown -R appuser:appgroup /usr/share/nginx/html
RUN chown -R appuser:appgroup /var/cache/nginx /var/log/nginx /etc/nginx/conf.d
RUN touch /var/run/nginx.pid && chown appuser:appgroup /var/run/nginx.pid

USER appuser

EXPOSE 80

HEALTHCHECK --interval=15s --timeout=5s CMD wget -qO- http://localhost:80/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
