# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee
import Config

config :uro, Uro.Repo,
  show_sensitive_data_on_connection_error: true,
  url:
    System.get_env(
      "TEST_DATABASE_URL",
      "postgresql://root@localhost:26257/vsekai_test?sslmode=disable"
    ),
  stacktrace: true,
  migration_lock: false,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  ssl: false
