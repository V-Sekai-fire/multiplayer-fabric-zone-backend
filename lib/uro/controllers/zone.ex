defmodule Uro.ZoneController do
  use Uro, :controller

  alias Uro.VSekai

  @doc """
  GET /zones — returns all fresh shards as zones.

  Zone servers register via POST /shards (including cert_hash) and
  stay alive via PUT /shards/:id heartbeats every 30 s. The shard
  freshness window is 30 s; stale entries are culled by ShardJanitor.
  """
  def index(conn, _params) do
    zones =
      VSekai.list_fresh_shards()
      |> Enum.map(fn shard ->
        %{
          address:   shard.address,
          port:      shard.port,
          cert_hash: shard.cert_hash || ""
        }
      end)

    json(conn, %{data: %{zones: zones}})
  end
end
