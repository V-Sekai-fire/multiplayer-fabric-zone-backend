defmodule Uro.Repo.Migrations.RenameShardsToZones do
  use Ecto.Migration

  def change do
    rename table(:shards), to: table(:zones)
  end
end
