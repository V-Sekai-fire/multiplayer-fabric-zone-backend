# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee
defmodule Uro.VSekai.Booth do
  use Ecto.Schema

  import Ecto.Changeset

  alias Uro.Accounts.User
  alias Uro.VSekai.Zone

  schema "booths" do
    belongs_to(:zone, Zone, foreign_key: :zone_id, type: :binary_id)
    belongs_to(:user, User, foreign_key: :user_id, type: :binary_id)

    field(:name, :string)
    field(:description, :string)

    timestamps()
  end

  @doc false
  def changeset(booth, attrs) do
    booth
    |> cast(attrs, [:zone_id, :user_id, :name, :description])
    |> validate_required([:zone_id, :name])
    |> assoc_constraint(:zone)
    |> assoc_constraint(:user)
  end
end
