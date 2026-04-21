# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee
defmodule Uro.Repo.Migrations.AddCertHashToShards do
  use Ecto.Migration

  def change do
    alter table(:shards) do
      add :cert_hash, :string, null: true
    end
  end
end
