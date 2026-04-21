# Development

## Red-green-refactor

Every feature and every fix is driven by a failing test committed before any
implementation code:

1. RED — write a test that fails with a specific, load-bearing error message.
   Verify the message is load-bearing: briefly break the assertion to confirm
   the failure is not vacuous.
2. GREEN — write the minimum code to make the test pass. No extra abstractions.
3. REFACTOR — clean up with tests still green. One commit per cycle.

The TDD arc must be legible in `git log`.

## Test commands

| Submodule | Command | Framework |
|-----------|---------|-----------|
| `multiplayer-fabric-zone-backend` | `mix test` | ExUnit |
| `multiplayer-fabric-zone-console` | `mix test` | ExUnit + PropCheck |
| `multiplayer-fabric-taskweft` | `mix test --include property` | ExUnit + PropCheck |
| `multiplayer-fabric-deploy` | `mix test` | ExUnit |
| `multiplayer-fabric-desync` | `go test ./...` | Go testing |
| `multiplayer-fabric-sandbox` | `ctest --test-dir build` | CMake / CTest + ASAN |

Integration tests require a live stack. Tag them `@tag :prod` and run with
`mix test --only prod`.

## Commit message style

Sentence case, imperative verb, no `type(scope):` prefix, under 72 characters.

```
Add CMD_INSTANCE_ASSET to peer command enum
Fix mix.exs missing closing bracket in deps list
Update zone-console submodule pointer
```

No `feat:`, `fix:`, `chore:`, or any other Conventional Commits prefix.

## Submodule workflow

```sh
# Clone everything
git clone --recurse-submodules <root-url>
git submodule update --init --recursive

# Work inside a submodule
cd multiplayer-fabric-zone-backend
git checkout -b my-feature
# ... make changes, commit, push ...
cd ..

# Record the updated pointer in the root repo
git add multiplayer-fabric-zone-backend
git commit -m "Update zone-backend submodule pointer"
```

Never commit changes to submodule files from the root repo. Always `cd` into
the submodule first.

## Elixir conventions

- Use PropCheck generators rather than mocks. If a generator is hard to write,
  the API surface is too wide.
- Functions return `{:ok, value}` / `{:error, reason}` at every boundary.
  `raise` is for programmer errors (wrong argument type, missing config at boot),
  never for runtime conditions.
- Migrations are forward-only. Once merged to main, never alter a migration.
  Fixes require a new migration. Every migration must include a `down/0`.

## C++ conventions

- `-fsanitize=address,undefined` on every Debug build. An ASAN/UBSAN finding is
  a RED, not a warning.
- No dynamic allocation in hot paths. Use `std::array`, `std::span`, or a bump
  allocator.
- Never hand-edit `predictive_bvh.h` — regenerate with `lake exe bvh-codegen`.

## Lean 4 proofs

All physics and geometry invariants live in `multiplayer-fabric-predictive-bvh`.
No `sorry` may remain in any proof under `PredictiveBVH/`. When porting an
algorithm to C++ or Elixir, follow the Lean proof — if the implementation
differs, fix the implementation.

```sh
cd multiplayer-fabric-predictive-bvh
lake build   # must complete 313 jobs with no errors
```

## Godot fork assembly

`multiplayer-fabric-godot/multiplayer-fabric` is a generated branch assembled
from feature branches. Never commit unique work directly to it.

```sh
cd multiplayer-fabric-merge
elixir update_godot_v_sekai.exs --dry-run   # preview
elixir update_godot_v_sekai.exs             # live assembly + push
```

## Building Docker images

```sh
# Zone server (editor=no, smaller)
cd multiplayer-fabric-godot
docker build --target zone-server \
  -t multiplayer-fabric-godot-server:latest -f Dockerfile .

# Baker (editor=yes, used for headless import via vsk_importer_exporter)
# Populate the build context from multiplayer-fabric-baker first:
bash baker/populate-vsk-project.sh [../multiplayer-fabric-baker]
docker build -t multiplayer-fabric-godot-baker:latest -f Dockerfile.baker .
```

`multiplayer-fabric-baker` is the canonical minimal Godot project (15 MB,
stripped of XR/UI/animation addons). When `multiplayer-fabric-rx` changes,
regenerate it with:

```sh
bash baker/regenerate-baker-project.sh [../multiplayer-fabric-rx] [../multiplayer-fabric-baker]
# then commit + push multiplayer-fabric-baker
```

## Asset streaming implementation status

| Cycle | Feature | Status |
|-------|---------|--------|
| 1 | `UroClient.login/3` | done |
| 2 | `UroClient.upload_asset/3` — chunk → VersityGW → uro manifest | done |
| 3 | `UroClient.get_manifest/2` | done |
| 4 | `CMD_INSTANCE_ASSET` wire encoding (100-byte packet) | done |
| 5 | `instance` console command — sends packet to zone server | done |
| 6 | Asset baker — Docker `editor=yes`, casync `.caidx` output, vsk i/o script | done |
| 7 | Zone orchestrator — Docker `editor=no` zone server lifecycle, port pool UDP 7443–7542 | planned |
| 8 | Godot zone handler — authority zone runs instance pipeline | planned |
| 9 | Round-trip smoke test — upload → instance → entity list on prod | planned |
| 10 | Multi-platform verification — macOS + Linux + Windows, AccessKit | planned |
