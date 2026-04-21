# PoC runbook

End-to-end walkthrough: two users co-present in a V-Sekai zone. This page
connects the individual docs into a single reproducible sequence.

Prerequisites: stack running (`docker compose up -d`), two terminal sessions,
`zone_console` binary built (`mix escript.build` in `multiplayer-fabric-zone-console/`).

---

## Step 1 — User A: login

```sh
> login
Username/email: user-a@example.com
Password: ****
Logged in as user-a
```

See [Authentication](authentication.md) for token details.

---

## Step 2 — User A: upload an avatar scene

```sh
> upload path/to/avatar.tscn
Uploaded avatar.tscn as <ASSET_ID>
```

The scene must be a Godot packed scene (`.tscn` or `.scn`) conforming to the
`VSKAvatarValidator` allowlist. See [Asset pipeline](assets.md).

---

## Step 3 — Wait for bake

```sh
> bake-status <ASSET_ID>
Baking... (polling every 2 s)
Baked. baked_url = http://versitygw:7070/uro-uploads/<ASSET_ID>.caidx
```

The baker container validates the scene via `VSKImporter`, exports a cleaned
binary `.scn`, chunks it with AriaStorage, and writes `baked_url` to
CockroachDB. See [Asset pipeline § Full pipeline](assets.md).

---

## Step 4 — User A: join a zone

```sh
> join 0
Joined zone 0 at zone-700a.chibifire.com:7443
```

`GET /shards` returns the registered zone list. `join 0` connects to the first
entry via WebTransport, pinning the certificate using `cert_hash`.
See [Zones](zones.md) and [Zone console § join](zone-console.md).

---

## Step 5 — User A: instance the asset

```sh
> instance <ASSET_ID> 0.0 1.0 0.0
Instance request sent for asset <ASSET_ID> at (0.0, 1.0, 0.0)
```

Sends `CMD_INSTANCE_ASSET` (100-byte packet, opcode 0x04) to the zone server.
The authority zone (determined by `hilbert3D(pos)`) fetches the `.caidx`,
reassembles the `.scn` from chunks, and instances the entity.
See [Zone console § Wire protocol](zone-console.md).

---

## Step 6 — User A: verify entity appears

```sh
> entities
[zone 0]  id=42  pos=(0.00, 1.00, 0.00)  type=scene  asset=<ASSET_ID>
```

Proves cycle 9: asset instanced and visible in entity list.

---

## Step 7 — User B: login, join same zone

In a second terminal:

```sh
> login
Username/email: user-b@example.com
Password: ****
Logged in as user-b
> join 0
Joined zone 0 at zone-700a.chibifire.com:7443
```

---

## Step 8 — User B: verify entity from User A is visible

```sh
> entities
[zone 0]  id=42  pos=(0.00, 1.00, 0.00)  type=scene  asset=<ASSET_ID>
```

Same entity ID and position as seen by User A. Proves cycle 10: two clients
co-present, entity instanced by one client observed by the other.

This is the minimal V-Sekai PoC.

---

## Monitoring

```sh
# Baker logs
docker logs <baker-container-id>

# Confirm baked_url set in DB
docker exec multiplayer-fabric-hosting-crdb-1 \
  /cockroach/cockroach sql --insecure \
  -e "SELECT id, baked_url IS NOT NULL FROM vsekai.shared_files \
      ORDER BY inserted_at DESC LIMIT 5;"

# Confirm UDP 7443 reachable
nc -u -w2 zone-700a.chibifire.com 7443 && echo "UDP open"
```

See [Getting started](getting-started.md) for full stack setup.
