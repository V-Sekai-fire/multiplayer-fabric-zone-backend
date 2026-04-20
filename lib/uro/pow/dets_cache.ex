defmodule Uro.Pow.DetsCache do
  @moduledoc """
  DETS-backed Pow session cache.

  Stores session tokens on disk via DETS — no external service required.
  Each record is stored as {key, value, expires_at_ms} where expires_at_ms
  is nil for non-expiring entries. Expired entries are pruned lazily on read.
  """

  use GenServer
  @behaviour Pow.Store.Backend.Base

  @table :pow_dets_cache

  # ── GenServer lifecycle ───────────────────────────────────────────────────────

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    path = :filename.join(:code.priv_dir(:uro), ~c"pow_cache.dets")
    {:ok, _} = :dets.open_file(@table, file: path, type: :set)
    {:ok, %{}}
  end

  @impl GenServer
  def terminate(_reason, _state) do
    :dets.close(@table)
  end

  # ── Pow.Store.Backend.Base callbacks ─────────────────────────────────────────

  @impl Pow.Store.Backend.Base
  def put(config, record_or_records) do
    ttl = Pow.Config.get(config, :ttl)
    expires_at = if ttl, do: now_ms() + ttl, else: nil

    record_or_records
    |> List.wrap()
    |> Enum.each(fn {key, value} ->
      :dets.insert(@table, {make_key(config, key), value, expires_at})
    end)

    :ok
  end

  @impl Pow.Store.Backend.Base
  def delete(config, key) do
    :dets.delete(@table, make_key(config, key))
    :ok
  end

  @impl Pow.Store.Backend.Base
  def get(config, key) do
    dets_key = make_key(config, key)
    now = now_ms()

    case :dets.lookup(@table, dets_key) do
      [{^dets_key, value, nil}] ->
        value

      [{^dets_key, value, expires_at}] when expires_at > now ->
        value

      [{^dets_key, _value, _expired}] ->
        :dets.delete(@table, dets_key)
        :not_found

      [] ->
        :not_found
    end
  end

  @impl Pow.Store.Backend.Base
  def all(config, key_match) do
    now = now_ms()
    namespace = Pow.Config.get(config, :namespace, "cache")
    full_match = [namespace | List.wrap(key_match)]

    :dets.match_object(@table, {full_match, :_, :_})
    |> Enum.reject(fn {_key, _value, expires_at} ->
      expires_at != nil and expires_at <= now
    end)
    |> Enum.map(fn {[_ns | key], value, _expires_at} -> {key, value} end)
  end

  # ── helpers ───────────────────────────────────────────────────────────────────

  defp make_key(config, key) do
    namespace = Pow.Config.get(config, :namespace, "cache")
    [namespace | List.wrap(key)]
  end

  defp now_ms, do: System.system_time(:millisecond)
end
