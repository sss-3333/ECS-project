# ---- Builder stage ----
FROM node:20-alpine AS builder

WORKDIR /build

COPY app/package.json app/package-lock.json* ./
RUN npm install --omit=dev

COPY app/ ./

# ---- Runtime stage ----
FROM gcr.io/distroless/nodejs20-debian12 AS runtime

WORKDIR /app

COPY --from=builder /build/node_modules ./node_modules
COPY --from=builder /build/server.js ./
COPY --from=builder /build/store.js ./
COPY --from=builder /build/data.json ./
COPY --from=builder /build/package.json ./
COPY --from=builder /build/public ./public

ENV PORT=3000
EXPOSE 3000

CMD ["server.js"]