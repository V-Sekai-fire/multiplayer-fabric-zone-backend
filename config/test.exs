# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee
import Config

crdb_ssl =
  case System.get_env("CRDB_CA_CERT") do
    nil ->
      crdb_certs = Path.expand("../../multiplayer-fabric-hosting/certs/crdb", __DIR__)
      if File.exists?(Path.join(crdb_certs, "ca.crt")) do
        [
          cacertfile: Path.join(crdb_certs, "ca.crt"),
          certfile: Path.join(crdb_certs, "client.root.crt"),
          keyfile: Path.join(crdb_certs, "client.root.key"),
          verify: :verify_peer,
          server_name_indication: ~c"crdb"
        ]
      else
        false
      end

    ca ->
      [
        cacertfile: ca,
        certfile: System.get_env("CRDB_CLIENT_CERT"),
        keyfile: System.get_env("CRDB_CLIENT_KEY"),
        verify: :verify_peer,
        server_name_indication: ~c"crdb"
      ]
  end

config :uro, Uro.Repo,
  show_sensitive_data_on_connection_error: true,
  url:
    System.get_env(
      "TEST_DATABASE_URL",
      "postgresql://root@localhost:26257/vsekai_test?sslmode=verify-full"
    ),
  stacktrace: true,
  migration_lock: false,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  ssl: crdb_ssl
