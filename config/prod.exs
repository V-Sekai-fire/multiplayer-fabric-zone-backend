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

# OpenTelemetry: ship spans + logs to multiplayer-fabric-observability over
# Fly's 6PN private network. Uses OTLP/HTTP (4318) which is simpler than
# OTLP/gRPC over plain 6PN (no TLS overhead). Endpoint is overridable via
# OTEL_EXPORTER_OTLP_ENDPOINT for local dev.
otel_endpoint =
  System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT") ||
    "http://multiplayer-fabric-observability.internal:4318"

config :opentelemetry,
  span_processor: :batch,
  traces_exporter: :otlp,
  resource: %{
    "service.name" => "multiplayer-fabric-uro",
    "service.version" => to_string(Application.spec(:uro, :vsn) || "0.0.0"),
    "deployment.environment" => "fly-iad"
  }

config :opentelemetry_exporter,
  otlp_protocol: :http_protobuf,
  otlp_endpoint: otel_endpoint
