# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule Uro.Repo.Migrations.AddStatusAndPublicToZones do
  use Ecto.Migration

  def change do
    alter table(:zones) do
      add :status, :string, default: "public", null: false
      add :public, :boolean, default: true, null: false
    end
  end
end
