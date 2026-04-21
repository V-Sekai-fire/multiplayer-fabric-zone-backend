# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee
defmodule Uro.VSekai do
  @moduledoc """
  The VSekai context.
  """

  import Ecto.Query, warn: false
  alias Uro.Repo

  alias Uro.VSekai.Zone

  def zone_freshness_time_in_seconds, do: 30

  def list_zones do
    Zone
    |> Repo.all()
    |> Repo.preload(user: [:user])
  end

  def list_fresh_zones do
    stale_timestamp =
      DateTime.add(DateTime.utc_now(), -zone_freshness_time_in_seconds(), :second)

    Repo.all(from z in Zone, where: z.updated_at > ^stale_timestamp, preload: [:user])
  end

  def get_zone!(id) do
    Zone
    |> Repo.get!(id)
    |> Repo.preload(user: [:user])
  end

  def create_zone(attrs \\ %{}) do
    zone_data = Map.get(attrs, "shard", %{})
    flattened_attrs = Map.merge(Map.drop(attrs, ["shard"]), zone_data)

    %Zone{}
    |> Zone.changeset(flattened_attrs)
    |> Repo.insert()
  end

  def update_zone(%Zone{} = zone, attrs) do
    zone
    |> Zone.changeset(attrs)
    |> Repo.update(force: true)
  end

  def delete_zone(%Zone{} = zone) do
    Repo.delete(zone)
  end

  def change_zone(%Zone{} = zone) do
    Zone.changeset(zone, %{})
  end

  def get_zone_by_address(address) when is_nil(address), do: nil

  def get_zone_by_address(address) do
    Repo.get_by(Zone, address: address)
  end
end
