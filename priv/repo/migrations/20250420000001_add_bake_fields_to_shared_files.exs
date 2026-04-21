defmodule Uro.Repo.Migrations.AddBakeFieldsToSharedFiles do
  use Ecto.Migration

  def change do
    alter table(:shared_files) do
      add :store_url,  :string,  null: true
      add :chunks,     :jsonb,   null: true
      add :baked_url,  :string,  null: true
    end
  end
end
