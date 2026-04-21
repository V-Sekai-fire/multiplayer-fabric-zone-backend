# Zone console

`zone_console` is an Elixir escript (CLI) that connects to `zone-backend` for
asset management and to zone servers via WebTransport for live world interaction.
Source: `multiplayer-fabric-zone-console/`.

## Build

```sh
cd multiplayer-fabric-zone-console
mix deps.get
mix escript.build
# produces ./zone_console binary
```

The escript runs on any machine with the Erlang runtime installed. For a fully
self-contained binary use `mix release`.

## Commands

### login

```
> login
Username/email: operator@example.com
Password: ****
Logged in as operator
```

Calls `POST /session` and stores the Bearer token in process state.

### upload

```
> upload path/to/scene.tscn
Uploaded scene.tscn as 550e8400-e29b-41d4-a716-446655440000
```

Calls `POST /storage` with the file as multipart. Returns the asset UUID.

### bake-status

```
> bake-status 550e8400-...
Baking... (polling every 2 s)
Baked. baked_url = http://localhost:7070/uro-uploads/550e8400-....caidx
```

Polls `POST /storage/:id/manifest` until `baked_url` is set.

### join

```
> join 0
Joined zone 0 at zone-700a.chibifire.com:443
```

Connects to the zone server at the address returned by `GET /shards`, using
the `cert_hash` from the zone record for certificate pinning.

### instance

```
> instance 550e8400-... 0.0 1.0 0.0
Instance request sent for asset 550e8400-... at (0.0, 1.0, 0.0)
```

Sends a `CMD_INSTANCE_ASSET` packet to the connected zone server. See wire
format below.

### entities

```
> entities
[zone 0]  id=42  pos=(0.00, 1.00, 0.00)  type=scene  asset=550e8400-...
```

Prints the current entity snapshot from the zone server.

## Wire protocol

### CMD_INSTANCE_ASSET packet (100 bytes)

```
Offset  Size  Type     Field
0       2     uint16   opcode  (low byte = 0x04 = CMD_INSTANCE_ASSET)
2       4     uint32   asset_id (lower 32 bits of UUID)
6       4     float32  cx (position x, metres)
10      4     float32  cy (position y, metres)
14      4     float32  cz (position z, metres)
18      82    bytes    reserved / padding
```

The packet is always exactly 100 bytes. The opcode is in the low byte
(`value &&& 0xFF == 0x04`).

Source: `lib/zone_console/zone_client.ex` — `encode_instance/8`.

Verified by PropCheck properties in
`test/zone_console/zone_client_encoding_test.exs`:
- Packet size is exactly 100 bytes
- Opcode low byte equals 4
- `asset_id` round-trips through encode/decode
- Target position round-trips as float32

## UroClient API

`ZoneConsole.UroClient` wraps the HTTP API:

```elixir
client = ZoneConsole.UroClient.new("https://hub-700a.chibifire.com")
{:ok, authed} = ZoneConsole.UroClient.login(client, email, password)
{:ok, id}     = ZoneConsole.UroClient.upload_asset(authed, path, filename)
{:ok, m}      = ZoneConsole.UroClient.get_manifest(authed, id)
# m["baked_url"] is nil until baker completes
```

## ZoneClient API

`ZoneConsole.ZoneClient` manages the WebTransport connection:

```elixir
{:ok, zc} = ZoneConsole.ZoneClient.start_link(url, cert_pin, zone_id, self())
ZoneConsole.ZoneClient.send_instance(zc, asset_id, cx, cy, cz)
# zone server sends entity snapshot back:
receive do
  {:zone_entities, entities} -> ...
end
ZoneConsole.ZoneClient.stop(zc)
```

## Environment variables for tests

```sh
URO_BASE_URL=https://hub-700a.chibifire.com
URO_EMAIL=operator@example.com
URO_PASSWORD=<password>
ZONE_SERVER_URL=https://zone-700a.chibifire.com
ZONE_CERT_PIN=<SHA-256 fingerprint>
TEST_SCENE_PATH=../multiplayer-fabric-humanoid-project/humanoid/scenes/mire.tscn
AWS_S3_BUCKET=uro-uploads
AWS_S3_ENDPOINT=http://localhost:7070
AWS_ACCESS_KEY_ID=minioadmin
AWS_SECRET_ACCESS_KEY=minioadmin
```

Run integration tests (requires live stack):

```sh
cd multiplayer-fabric-zone-console
mix test --only prod
```
