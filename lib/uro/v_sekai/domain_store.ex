# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule Uro.VSekai.DomainStore do
  @moduledoc """
  Loads RECTGTN domain JSON-LD files from `priv/domains/`.

  Domain files are named `<key>.jsonld`. The key is application-defined —
  it can be a species name, an NPC role, a workflow name, or anything else.
  The planner (`EntityPlanner`) is key-agnostic; this module is the only
  place that knows about the file layout.
  """

  @doc "Load a domain by key. Returns `{:ok, json_string}` or `{:error, reason}`."
  @spec load(String.t()) :: {:ok, String.t()} | {:error, term()}
  def load(key) when is_binary(key) do
    path = Application.app_dir(:uro, "priv/domains/#{key}.jsonld")

    case File.read(path) do
      {:ok, _} = ok -> ok
      {:error, :enoent} -> {:error, {:domain_not_found, key}}
      err -> err
    end
  end

  @doc "List all available domain keys."
  @spec list() :: [String.t()]
  def list do
    dir = Application.app_dir(:uro, "priv/domains")

    case File.ls(dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".jsonld"))
        |> Enum.map(&Path.rootname/1)

      {:error, _} ->
        []
    end
  end
end
