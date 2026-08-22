# Dockerizing lanke-2.0 (Neon Database)

This monorepo is Dockerized to run the **same** application code against two
different database backends, switched entirely via the `DATABASE_URL` env var:

| Environment | Database                | Source of `DATABASE_URL`             |
| ----------- | ----------------------- | ------------------------------------ |
| Dev         | **Neon Local** (Docker) | `.env.development` → `neon-local:5432` |
| Prod        | **Neon Cloud**          | `.env.production` → `*.neon.tech` (injected by the platform in real life) |

> Reference: <https://neon.com/docs/local/neon-local>

---

## Files added

```
.
├── Dockerfile                  # multi-stage, Next.js standalone output
├── .dockerignore
├── docker-compose.dev.yml      # app + neon-local
├── docker-compose.prod.yml     # app only — Neon Cloud
├── .env.development            # commits OK (no secrets)
└── .env.production             # template only — never commit real secrets
```

The Dockerfile builds whichever app you pass via `--build-arg APP_DIR=apps/...`.

---

## 1. Development — Neon Local

Neon Local is a Docker image (`neondatabase/neon_local`) that proxies Postgres
on `:5432` but is backed by a real **ephemeral branch** in your Neon project.
On every container start it creates a fresh branch; on stop it deletes it
(set `NEON_DELETE_BRANCH=false` to keep it for debugging).

### Prereqs

* Docker + Docker Compose v2
* A Neon project + API key (only required if you want the ephemeral branch
  to be a *real* Neon branch — `CREATE_BRANCH=false` runs in fully-local mode).

### Start the dev stack

```bash
# 1. (optional) link Neon Local to a real Neon project for branch mirroring
export NEON_API_KEY=<your-neon-api-key>
export NEON_PROJECT_ID=<your-neon-project-id>
export NEON_PARENT_BRANCH_ID=main

# 2. Boot Neon Local + both Next.js apps
docker compose --env-file .env.development -f docker-compose.dev.yml up --build
```

You should see:

| Service     | URL                            |
| ----------- | ------------------------------ |
| `web`       | <http://localhost:3001>        |
| `user-ui`   | <http://localhost:3000>        |
| `neon-local`| `postgres://neon:npg@localhost:5432/neondb` |

Inside the Docker network the app talks to `neon-local:5432`. From your host
use `localhost:5432`. Same auth, same DB — both resolve to the ephemeral
branch.

### Tearing down / resetting

```bash
# Stop containers (deletes the ephemeral branch)
docker compose -f docker-compose.dev.yml down

# Wipe volumes too
docker compose -f docker-compose.dev.yml down -v
```

---

## 2. Production — Neon Cloud

In production there is **no Neon Local proxy**. The app talks straight to
Neon's serverless Postgres over TLS.

### Build the images

```bash
docker build --build-arg APP_DIR=apps/web     -t lanke-web:prod     .
docker build --build-arg APP_DIR=apps/user-ui -t lanke-user-ui:prod .
```

### Run with Docker Compose (local sanity-check only)

```bash
# Put the real Neon URL into .env.production first, then:
docker compose --env-file .env.production -f docker-compose.prod.yml up -d
```

> ⚠️ Don't actually deploy this way with the URL on disk. In production the
> `DATABASE_URL` must come from your platform's secret store.

### Run on a host (Fly.io / Railway / Render / ECS / K8s / etc.)

The image only needs:

```
DATABASE_URL=postgres://user:pass@ep-xxx.region.aws.neon.tech/neondb?sslmode=require
NODE_ENV=production
PORT=3001
HOSTNAME=0.0.0.0
```

Set those four and expose `PORT`. Done.

---

## 3. How the env switch works

`DATABASE_URL` is the *only* thing that changes:

* `docker-compose.dev.yml` injects `.env.development`, whose `DATABASE_URL`
  points at the `neon-local` service.
* `docker-compose.prod.yml` injects `.env.production`, whose `DATABASE_URL`
  is your real Neon Cloud URL.

Both compose files build the same image. The application code reads
`process.env.DATABASE_URL` and never knows whether it's talking to a
local proxy or Neon Cloud — that's the whole point of Neon Local.

### `.env.development`

```env
DATABASE_URL=postgres://neon:npg@neon-local:5432/neondb
NODE_ENV=development
```

### `.env.production` (template — fill in or override via secrets)

```env
DATABASE_URL=postgres://USER:PASSWORD@HOST.neon.tech/neondb?sslmode=require
NODE_ENV=production
```

---

## 4. Useful one-liners

```bash
# Open a psql shell into Neon Local from your host
docker exec -it lanke-neon-local psql -U neon -d neondb

# Tail only the app logs
docker compose -f docker-compose.dev.yml logs -f web user-ui

# Rebuild after a code change
docker compose -f docker-compose.dev.yml up --build
```
