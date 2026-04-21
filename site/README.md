# Multiplayer Fabric documentation

An open-source social VR platform built on a custom Godot Engine fork.

## Contents

| Document | What it covers |
|----------|---------------|
| [Architecture](architecture.md) | Service topology, data flow, key design decisions |
| [Getting started](getting-started.md) | Clone, configure, run the stack locally |
| [API reference](api.md) | HTTP endpoints exposed by `zone-backend` |
| [Authentication](authentication.md) | Pow session auth |
| [Asset pipeline](assets.md) | Upload → casync bake → manifest → zone instance |
| [Zones](zones.md) | Zone model, topology, registration protocol |
| [Zone console](zone-console.md) | `zone_console` CLI: commands and wire protocol |
| [Development](development.md) | Test commands, build targets, red-green-refactor workflow |
| [PoC runbook](poc-runbook.md) | End-to-end walkthrough: two users co-present in a zone |

## Repository layout

```
multiplayer-fabric/              ← root (submodule index)
  multiplayer-fabric-zone-backend/   Phoenix API server (Uro)
  multiplayer-fabric-zone-console/   Elixir CLI connecting to zone servers
  multiplayer-fabric-hosting/        docker-compose stack
  multiplayer-fabric-deploy/         Elixir deploy tooling + Hilbert curve lib
  multiplayer-fabric-taskweft/       Task scheduler (Elixir + C++20 NIFs)
  multiplayer-fabric-godot/          Godot Engine fork (C++)
  multiplayer-fabric-sandbox/        RISC-V sandbox kernel
  multiplayer-fabric-predictive-bvh/ Lean 4 formal proofs
  multiplayer-fabric-desync/         Go desync-style chunk store
  multiplayer-fabric-humanoid-project/ Reference humanoid scenes
  aria-storage/                      AriaStorage Elixir lib (casync format)
```
