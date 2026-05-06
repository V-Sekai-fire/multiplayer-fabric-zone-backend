#!/bin/sh
# Write CRDB mTLS certs from Fly secrets to disk, then start Uro.
set -e

CERT_DIR=/tmp/crdb_certs
mkdir -p "$CERT_DIR"

if [ -n "$CRDB_CA_CRT" ]; then
  printf '%s' "$CRDB_CA_CRT"             > "$CERT_DIR/ca.crt"
  printf '%s' "$CRDB_CLIENT_WRITER_CRT"  > "$CERT_DIR/client.gateway_writer.crt"
  printf '%s' "$CRDB_CLIENT_WRITER_KEY"  > "$CERT_DIR/client.gateway_writer.key"
  chmod 600 "$CERT_DIR/client.gateway_writer.key"

  export CRDB_CA_CERT="$CERT_DIR/ca.crt"
  export CRDB_CLIENT_CERT="$CERT_DIR/client.gateway_writer.crt"
  export CRDB_CLIENT_KEY="$CERT_DIR/client.gateway_writer.key"
fi

# Skip ecto.create — database is provisioned externally (gateway_writer lacks CREATEDB).
exec iex -S mix do ecto.migrate, run priv/repo/test_seeds.exs, phx.server
