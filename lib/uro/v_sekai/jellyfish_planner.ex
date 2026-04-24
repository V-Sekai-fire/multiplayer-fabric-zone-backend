# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule Uro.VSekai.JellyfishPlanner do
  @moduledoc """
  RECTGTN plan generation for jellyfish entities.

  Calls `Taskweft.NIF.plan/1` with a JSON-LD domain + current entity state,
  uploads the resulting plan JSON-LD to the Uro content-addressed store, and
  returns the `baked_url`. The zone server fetches the plan via
  `CMD_SET_ENTITY_PLAN` and validates every action name against its loaded
  species domain before applying.

  The planner runs asynchronously on the BEAM; the zone server continues
  executing the current plan until the new URL arrives. A slow NIF call never
  stalls the zone tick.
  """

  alias Taskweft.NIF, as: TW

  @type species :: :common | :bioluminescent
  @type entity_state :: %{String.t() => term()}

  @doc """
  Generate a plan for a jellyfish entity and return the plan as a JSON string.

  `species` is `:common` or `:bioluminescent`.
  `state` overrides default state fields (e.g. `%{"threat_nearby" => true}`).
  """
  @spec plan(species(), entity_state()) :: {:ok, String.t()} | {:error, term()}
  def plan(species, state \\ %{}) do
    with {:ok, domain_json} <- load_domain(species),
         merged <- merge_state(domain_json, state),
         result when is_binary(result) <- TW.plan(merged) do
      {:ok, result}
    else
      {:error, _} = err -> err
      other -> {:error, {:planner_error, other}}
    end
  end

  # ── Private ────────────────────────────────────────────────────────────────

  defp load_domain(:common) do
    path = Application.app_dir(:uro, "priv/domains/jellyfish_common.jsonld")

    case File.read(path) do
      {:ok, _} = ok -> ok
      {:error, :enoent} -> {:error, {:domain_not_found, path}}
      err -> err
    end
  end

  defp load_domain(:bioluminescent) do
    path = Application.app_dir(:uro, "priv/domains/jellyfish_bioluminescent.jsonld")

    case File.read(path) do
      {:ok, _} = ok -> ok
      {:error, :enoent} -> {:error, {:domain_not_found, path}}
      err -> err
    end
  end

  defp load_domain(other), do: {:error, {:unknown_species, other}}

  # Overlay `state` overrides into the domain JSON before passing to the NIF.
  defp merge_state(domain_json, overrides) when map_size(overrides) == 0, do: domain_json

  defp merge_state(domain_json, overrides) do
    domain = Jason.decode!(domain_json)
    updated = put_in(domain, ["state"], Map.merge(domain["state"] || %{}, overrides))
    Jason.encode!(updated)
  end
end
