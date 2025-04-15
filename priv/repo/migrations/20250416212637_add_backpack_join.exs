defmodule Uro.Repo.Migrations.AddBackpackJoin do
  use Ecto.Migration

  def change do
    create table(:backpack_join, primary_key: false) do
      add :id, :uuid, primary_key: true
<<<<<<< HEAD
      add :backpack_id, references(:users, type: :binary_id), null: false

      add :map_id, references(:maps, type: :binary_id)
      add :avatar_id, references(:avatars, type: :binary_id)
      add :prop_id, references(:props, type: :binary_id)
=======
      add :owner_id, references(:users, type: :uuid)

      add :map_id, references(:maps, type: :uuid)
      add :avatar_id, references(:avatars, type: :uuid)
      add :prop_id, references(:props, type: :uuid)
>>>>>>> b303d3a (using one join table)
      timestamps()
    end
  end
end
