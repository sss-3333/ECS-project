# ---- Builder stage ----
# Installs dependencies in a full Node image (has npm, shell, build tools
# if any native deps ever need compiling). Nothing from this stage ends up
# in the final image except whats explicitly copied out.
FROM node:20-alpine AS builder

WORKDIR /build

COPY app/package.json app/package-lock.json* ./
RUN npm install --omit=dev

COPY app/ ./

# ---- Runtime stage ----
# Distroless: no shell, no package manager, no OS utilities — just the
# Node runtime and our app. Smaller attack surface than alpine, and it
# runs as a non-root user ("nonroot") by default, satisfying the
# non-root requirement without any extra USER/adduser steps.
FROM gcr.io/distroless/nodejs20-debian12 AS runtime

WORKDIR /app

COPY --from=builder /build/node_modules ./node_modules
COPY --from=builder /build/server.js ./
COPY --from=builder /build/store.js ./
COPY --from=builder /build/data.json ./
COPY --from=builder /build/package.json ./

# App listens on 3000 internally (non-root can't bind <1024) — see plan
# notes. Exposed as 80 externally via Docker/ALB port mapping.
ENV PORT=3000
EXPOSE 3000

CMD ["server.js"]