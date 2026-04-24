# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee
import Config

config :uro, Uro.Endpoint, server: true

# Unused (no static files)
# config :uro, Uro.Endpoint, cache_static_manifest: "priv/static/cache_manifest.json"

config :uro, Uro.Mailer,
  adapter: Swoosh.Adapters.Sendgrid,
  api_key: System.get_env("SENDGRID_API_KEY", "")

# Do not print debug messages in production.
config :logger, level: :info

# Use S3-compatible storage (versitygw) for Waffle uploads and aria-storage chunks.
# AWS_S3_ENDPOINT is set to http://versitygw:7070 in the hosting docker-compose.
config :waffle, storage: Waffle.Storage.S3

config :ex_aws,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}]

config :ex_aws, :s3,
  scheme: "http://",
  host: System.get_env("VERSITYGW_HOST", "versitygw"),
  port: String.to_integer(System.get_env("VERSITYGW_PORT", "7070"))
