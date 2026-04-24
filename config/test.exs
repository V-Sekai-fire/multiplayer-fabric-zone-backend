# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee
import Config

crdb_certs = Path.expand("../../multiplayer-fabric-hosting/certs/crdb", __DIR__)

config :uro, Uro.Repo,
  show_sensitive_data_on_connection_error: true,
  url:
    System.get_env(
      "TEST_DATABASE_URL",
      "postgresql://root@localhost:26257/vsekai_test"
    ),
  stacktrace: true,
  migration_lock: false,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  ssl: [
    cacertfile: Path.join(crdb_certs, "ca.crt"),
    certfile: Path.join(crdb_certs, "client.root.crt"),
    keyfile: Path.join(crdb_certs, "client.root.key"),
    verify: :verify_peer,
    server_name_indication: ~c"crdb"
  ]
