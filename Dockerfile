# =============================================================================
# Multi-stage Dockerfile for the lanke-2.0 Next.js monorepo
#
# Build a specific app with:
#   docker build --build-arg APP_DIR=apps/web      -t lanke-web      .
#   docker build --build-arg APP_DIR=apps/user-ui  -t lanke-user-ui  .
#
# Run:
#   docker run -p 3001:3001 --env-file .env.production lanke-web
# =============================================================================

# ---------- 1. Dependencies -----------------------------------------------
FROM node:20-alpine AS deps
RUN corepack enable && corepack prepare pnpm@11.22.0 --activate
WORKDIR /repo

# Copy the manifests Turborepo/pnpm need to resolve the workspace.
COPY pnpm-workspace.yaml package.json pnpm-lock.yaml* .npmrc ./
COPY apps ./apps
COPY packages ./packages

RUN pnpm install --frozen-lockfile

# ---------- 2. Build ------------------------------------------------------
FROM deps AS builder
ARG APP_DIR
ENV NEXT_TELEMETRY_DISABLED=1

WORKDIR /repo/apps/$(basename ${APP_DIR})
RUN pnpm build

# ---------- 3. Runner -----------------------------------------------------
FROM node:20-alpine AS runner
ARG APP_DIR
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

WORKDIR /app

# Non-root user
RUN addgroup --system --gid 1001 nodejs \
 && adduser  --system --uid 1001 nextjs

# Copy the standalone server output from Next.js
COPY --from=builder --chown=nextjs:nodejs /repo/${APP_DIR}/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /repo/${APP_DIR}/.next/static     ./${APP_DIR}/.next/static
COPY --from=builder --chown=nextjs:nodejs /repo/${APP_DIR}/public           ./${APP_DIR}/public

USER nextjs
EXPOSE 3000

CMD ["node", "server.js"]
