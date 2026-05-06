#!/bin/sh
# Write CRDB mTLS certs from Fly secrets to disk, then start Uro.
# ReBAC separation:
#   ecto.migrate  → gateway_admin (DDL privilege, uses MIGRATION_DATABASE_URL)
#   phx.server    → gateway_writer (DML only, uses DATABASE_URL)
set -e

CERT_DIR=/tmp/crdb_certs
mkdir -p "$CERT_DIR"

if [ -n "$CRDB_CA_CRT" ]; then
  printf '%s' "$CRDB_CA_CRT"             > "$CERT_DIR/ca.crt"
  printf '%s' "$CRDB_CLIENT_WRITER_CRT"  > "$CERT_DIR/client.gateway_writer.crt"
  printf '%s' "$CRDB_CLIENT_WRITER_KEY"  > "$CERT_DIR/client.gateway_writer.key"
  chmod 600 "$CERT_DIR/client.gateway_writer.key"
fi

if [ -n "$CRDB_CLIENT_ADMIN_CRT" ]; then
  printf '%s' "$CRDB_CLIENT_ADMIN_CRT"   > "$CERT_DIR/client.gateway_admin.crt"
  printf '%s' "$CRDB_CLIENT_ADMIN_KEY"   > "$CERT_DIR/client.gateway_admin.key"
  chmod 600 "$CERT_DIR/client.gateway_admin.key"
fi

export CRDB_CA_CERT="$CERT_DIR/ca.crt"
export CRDB_CLIENT_CERT="$CERT_DIR/client.gateway_writer.crt"
export CRDB_CLIENT_KEY="$CERT_DIR/client.gateway_writer.key"
export CRDB_ADMIN_CERT="$CERT_DIR/client.gateway_admin.crt"
export CRDB_ADMIN_KEY="$CERT_DIR/client.gateway_admin.key"

# Run migrations as gateway_admin (DDL), then serve as gateway_writer (DML).
exec iex -S mix do ecto.migrate --repo Uro.Repo.Migration, run priv/repo/test_seeds.exs, phx.server
