# Architecture

## Service topology

```
Internet
  │
  ▼
Cloudflare edge  (orange cloud on, Full strict SSL)
  │  hub-700a.chibifire.com  DNS A → 173.180.240.105
  │  Router forwards TCP 443 → host machine
  ▼
Caddy:443  (Docker, Cloudflare Origin Certificate)
  │  /api/v1/* and /uploads/*  → uro:4000
  │  everything else           → frontend:3000
  ▼
zone-backend:4000  (Phoenix/Uro, Docker)
  ├── crdb:26257        CockroachDB single-node, ghcr.io/v-sekai/cockroach
  └── versitygw:7070    S3-compatible object store (local POSIX backend)

zone-700a.chibifire.com
  │  DNS A record → 173.180.240.105  (orange cloud OFF — Cloudflare does not proxy UDP)
  │  Router forwards UDP 7443–7542 → host machine  (100-port pool, one port per zone instance)
  ▼
zone-server:7443–7542/udp  (Godot headless, Docker, editor=no build, up to 100 concurrent zones)
  └── WebTransport / QUIC / picoquic
```

All services run in the same Docker Compose project on one host machine.
TLS for the HTTP API is terminated by Caddy using a Cloudflare Origin Certificate
(not a tunnel). The zone server uses a self-signed certificate; clients pin it
via `ZONE_CERT_HASH_B64`.

## Key design decisions

### Cloudflare Origin Certificate for HTTP, direct UDP for WebTransport

`hub-700a.chibifire.com` is proxied by Cloudflare (orange cloud on). TLS
terminates at the Cloudflare edge under Full (strict) SSL mode. Caddy holds
a Cloudflare Origin Certificate and listens on TCP 443; it reverse-proxies
`/api/v1/*` and `/uploads/*` to `uro:4000` and everything else to
`frontend:3000`. No cloudflared tunnel is used.

WebTransport uses QUIC over UDP. Cloudflare does not proxy UDP, so
`zone-700a.chibifire.com` is a plain DNS A record (orange cloud off) pointing
directly to the host machine. The router forwards UDP 7443–7542 to the host;
the orchestrator assigns one port from this pool to each zone server instance.
Clients pin the zone server's self-signed certificate using `ZONE_CERT_HASH_B64`.

### Zone servers

A **zone** is a running WebTransport game server (e.g. `zone-700a.chibifire.com:7443`).
Up to 100 zones can run concurrently on one host, each assigned a distinct port from
the pool UDP 7443–7542. Zone servers register themselves in CockroachDB via
`POST /shards` on boot, then send `PUT /shards/:id` heartbeats every ~25 s.
`ZoneJanitor` culls entries with no heartbeat in 30 s.

### Authority and interest

The zone whose Hilbert range contains `hilbert3D(pos)` is the authority for any
entity at that position. It is the only zone that executes `CMD_INSTANCE_ASSET`.
Neighbouring zones within `AOI_CELLS` receive a `CH_INTEREST` ghost — they do
not re-fetch or re-instance.

### ReBAC access control

The authority zone evaluates `rebacCheck` before instancing. `observe` permission
is public; `modify` requires `owner`. Access policies are stored in CockroachDB
and evaluated by the zone server C++ module.

### Headless asset baking

Zone servers carry no editor code (`editor=no` build). Asset baking runs as a
one-shot Docker container using a Godot `editor=yes` binary. See [Asset pipeline](assets.md).

### casync object storage

Assets are stored in casync format in VersityGW:
- Content-addressed `.cacnk` chunk files (SHA512/256 hash, path `chunks/ab/cd/<hash>.cacnk`)
- `.caidx` directory-tree index that references the chunks

Zone clients reconstruct `.godot/imported/` by fetching the `.caidx` index then
downloading only the missing `.cacnk` chunks. The `AriaStorage` Elixir library
implements both the uploader (baker side) and reader (zone-console side).

### Lean 4 proof authority

All physics, geometry, and algorithmic invariants (Hilbert curve, BVH, interest
management) are formally proved in `multiplayer-fabric-predictive-bvh`. C++ and
Elixir ports must follow the proof, not the other way around. Never hand-edit
`predictive_bvh.h` — regenerate with `lake exe bvh-codegen`.

## Data model

```
users
  id (binary_id)
  email, username, display_name
  ↑ belongs_to
user_identities
  provider ("pow_assent" | "clerk" | …)
  uid (provider-assigned subject)
  ↑ joins to users

shared_files
  id (binary_id)
  name, tags[], is_public
  store_url     raw upload location (VersityGW)
  chunks        [{hash, offset, length}] jsonb
  baked_url     .caidx index URL (set after baker completes)
  uploader_id → users

zones
  id (binary_id)
  address, port
  map, name
  current_users, max_users
  cert_hash     SHA-256 fingerprint of zone server TLS cert
  inserted_at, updated_at  (updated_at used for heartbeat freshness)
```
