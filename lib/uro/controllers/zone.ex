defmodule Uro.ZoneController do
  use Uro, :controller

  @doc """
  GET /zones — returns the statically-configured zone server(s) from env vars.

  Env vars (set in multiplayer-fabric-hosting/.env):
    ZONE_HOST          — hostname, e.g. zone-700a.chibifire.com
    ZONE_PORT          — integer port, default 443
    ZONE_CERT_HASH_B64 — base64 of the zone server cert SHA-256 fingerprint
  """
  def index(conn, _params) do
    host      = System.get_env("ZONE_HOST")
    port      = System.get_env("ZONE_PORT", "443") |> String.to_integer()
    cert_hash = System.get_env("ZONE_CERT_HASH_B64", "")

    zones =
      case host do
        nil  -> []
        host -> [%{address: host, port: port, cert_hash: cert_hash}]
      end

    json(conn, %{data: %{zones: zones}})
  end
end
