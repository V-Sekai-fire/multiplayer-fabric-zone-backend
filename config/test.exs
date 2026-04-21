import Config

config :uro, Uro.Repo,
  show_sensitive_data_on_connection_error: true,
  url: System.get_env("TEST_DATABASE_URL"),
  username: "vsekai",
  password: "vsekai",
  hostname: "localhost",
  port: 26257,
  database: "vsekai_test",
  stacktrace: true,
  migration_lock: false,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10
