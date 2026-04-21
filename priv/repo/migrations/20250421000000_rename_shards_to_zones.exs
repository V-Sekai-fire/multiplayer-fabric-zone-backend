defmodule Uro.Repo.Migrations.RenameShardsToZones do
  use Ecto.Migration

  def up do
    rename table(:shards), to: table(:zones)
  end

  def down do
    rename table(:zones), to: table(:shards)
  end
end
