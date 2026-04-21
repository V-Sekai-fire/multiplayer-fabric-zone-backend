# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee
defmodule Uro.Repo.Migrations.RenameShardsToZones do
  use Ecto.Migration

  def change do
    rename table(:shards), to: table(:zones)
  end
end
