# multiplayer-fabric-zone-backend

Phoenix/Elixir backend (Uro) for the Multiplayer Fabric social VR platform.

## Quick start

### Prerequisites

- Docker and Docker Compose
- An `.env` file in `multiplayer-fabric-hosting/` (see below)

### Clone

```sh
git clone --recurse-submodules <root-url>
git submodule update --init --recursive
```

### Configure

Create `multiplayer-fabric-hosting/.env`:

```sh
URL=https://hub-700a.chibifire.com/api/v1/
ROOT_ORIGIN=https://hub-700a.chibifire.com
FRONTEND_URL=https://hub-700a.chibifire.com/

ZONE_HOST=zone-700a.chibifire.com
ZONE_PORT=443
ZONE_CERT_HASH_B64=       # SHA-256 fingerprint of zone server TLS cert (base64)

AWS_S3_BUCKET=uro-uploads
AWS_S3_ENDPOINT=http://versitygw:7070
AWS_ACCESS_KEY_ID=minioadmin
AWS_SECRET_ACCESS_KEY=minioadmin

PHOENIX_KEY_BASE=<64-char random — run: mix phx.gen.secret>
JOKEN_SIGNER=<32-char random>
```

### Start

```sh
cd multiplayer-fabric-hosting
docker compose up -d
```

### Smoke check

```sh
curl -s https://hub-700a.chibifire.com/health
# {"services":{"uro":"healthy"}}

curl -s http://localhost:4000/health   # direct, bypasses Cloudflare
```

### Local development (without Docker)

Requires Elixir 1.18+, Erlang/OTP 27+, CockroachDB on port 26257.

```sh
cd multiplayer-fabric-zone-backend
mix deps.get
mix ecto.create && mix ecto.migrate
mix phx.server
```

```sh
export DATABASE_URL="postgresql://vsekai:vsekai@localhost:26257/vsekai?sslmode=disable"
export AWS_S3_BUCKET=uro-uploads
export AWS_S3_ENDPOINT=http://localhost:7070
export AWS_ACCESS_KEY_ID=minioadmin
export AWS_SECRET_ACCESS_KEY=minioadmin
```

## Architecture and design

See module docs (`mix docs`) — key entry points:

| Module | Covers |
|--------|--------|
| `Uro` | Service topology, data model, key design decisions |
| `Uro.ZoneController` | Zone registration, heartbeat, WebTransport wire protocol |
| `Uro.StorageController` | Asset pipeline: upload → bake → casync → manifest |
| `Uro.AuthenticationController` | Pow session auth, OAuth2 pipelines |
| `Uro.VSekai.ZoneJanitor` | Zone staleness and cleanup |

OpenAPI spec (Swagger UI): `https://hub-700a.chibifire.com/api/v1/docs`

## Agent guidance

See [AGENTS.md](AGENTS.md) for test commands, TDD rules, PoC runbook, and
implementation cycle status.
