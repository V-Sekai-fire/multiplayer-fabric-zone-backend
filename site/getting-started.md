# Getting started

## Prerequisites

- Docker and Docker Compose
- `git` with submodule support
- An `.env` file in `multiplayer-fabric-hosting/` (see below)

## Clone

```sh
git clone --recurse-submodules <root-url>
git submodule update --init --recursive
```

## Configure

Create `multiplayer-fabric-hosting/.env`:

```sh
# Public hostnames
URL=https://hub-700a.chibifire.com/api/v1/
ROOT_ORIGIN=https://hub-700a.chibifire.com
FRONTEND_URL=https://hub-700a.chibifire.com/

# Zone server
ZONE_HOST=zone-700a.chibifire.com
ZONE_PORT=443
# SHA-256 fingerprint of the zone server's self-signed TLS cert (base64)
# Leave empty until the zone server has generated its cert.
ZONE_CERT_HASH_B64=

# Object storage (VersityGW, S3-compatible)
AWS_S3_BUCKET=uro-uploads
AWS_S3_ENDPOINT=http://versitygw:7070
AWS_ACCESS_KEY_ID=minioadmin
AWS_SECRET_ACCESS_KEY=minioadmin

# Phoenix internals
PHOENIX_KEY_BASE=<64-char random string>
JOKEN_SIGNER=<32-char random string>
```

Generate `PHOENIX_KEY_BASE`:
```sh
mix phx.gen.secret
```

## Start the stack

```sh
cd multiplayer-fabric-hosting
docker compose up -d
```

Services started (in order): `crdb-certs-init` → `crdb` → `versitygw` →
`versitygw-init` → `zone-backend` → `zone-server`.

`crdb-certs-init` generates a CA cert, node cert, and `root` client cert into
the `crdbcerts` Docker volume on first boot (idempotent). CockroachDB and
zone-backend both mount this volume; zone-backend connects with
`sslmode=verify-full` using the generated client certificate.

## Smoke check

```sh
# zone-backend via Caddy reverse proxy
curl -s https://hub-700a.chibifire.com/health
# {"services":{"uro":"healthy"}}

# zone-backend direct (bypasses Cloudflare)
curl -s http://localhost:4000/health
# {"services":{"uro":"healthy"}}

# CockroachDB admin UI
open http://localhost:8181

# VersityGW S3 API
curl -s http://localhost:7070/
```

## Run database migrations

Migrations run automatically when `zone-backend` starts. To run manually:

```sh
docker exec multiplayer-fabric-hosting-zone-backend-1 \
  /app/bin/uro eval "Uro.Release.migrate()"
```

## Restart a single service

```sh
cd multiplayer-fabric-hosting
docker compose restart zone-backend
```

## View logs

```sh
docker logs -f multiplayer-fabric-hosting-zone-backend-1
docker logs -f multiplayer-fabric-hosting-zone-server-1
```

## Stop the stack

```sh
cd multiplayer-fabric-hosting
docker compose down
```

To also remove volumes (wipes all data, including TLS certs and database):

```sh
docker compose down -v
```

New TLS certs are generated automatically on the next `docker compose up`.

## Local development (zone-backend without Docker)

Requires Elixir 1.18+, Erlang/OTP 27+, and a running CockroachDB on port 26257.

```sh
cd multiplayer-fabric-zone-backend
mix deps.get
mix ecto.create
mix ecto.migrate
mix phx.server
```

Environment variables used locally:

```sh
export DATABASE_URL="postgresql://vsekai:vsekai@localhost:26257/vsekai?sslmode=disable"
export AWS_S3_BUCKET=uro-uploads
export AWS_S3_ENDPOINT=http://localhost:7070
export AWS_ACCESS_KEY_ID=minioadmin
export AWS_SECRET_ACCESS_KEY=minioadmin
```
