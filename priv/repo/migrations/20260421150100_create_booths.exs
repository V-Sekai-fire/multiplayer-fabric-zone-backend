defmodule Uro.Repo.Migrations.CreateBooths do
  use Ecto.Migration

  def change do
    create table(:booths, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :zone_id, references(:zones, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: true
      add :name, :string, null: false
      add :description, :text

      timestamps()
    end

    create index(:booths, [:zone_id])
    create index(:booths, [:user_id])
  end
end
