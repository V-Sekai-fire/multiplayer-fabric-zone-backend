# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee
defmodule Uro.ZoneChannel do
  use Uro, :channel

  # Client joins "zone:{zone_id}" and receives the desync index URL immediately.
  # When the zone server sends a PUT /shards/:id heartbeat, zone-backend
  # broadcasts "zone_updated" to all subscribers so clients fetch fresh chunks.
  def join("zone:" <> zone_id, _params, socket) do
    case Uro.VSekai.get_zone!(zone_id) do
      zone ->
        desync_url = Uro.VSekai.get_desync_url_for_map(zone.map)
        {:ok, %{desync_index_url: desync_url}, socket}
    end
  rescue
    Ecto.NoResultsError -> {:error, %{reason: "zone not found"}}
  end
end
