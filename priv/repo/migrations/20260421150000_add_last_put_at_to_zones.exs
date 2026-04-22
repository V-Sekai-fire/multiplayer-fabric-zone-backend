defmodule Uro.Repo.Migrations.AddLastPutAtToZones do
  use Ecto.Migration

  def change do
    alter table(:zones) do
      add :last_put_at, :utc_datetime_usec, null: true
    end

    # Seed from updated_at so existing live zones are not immediately culled.
    execute "UPDATE zones SET last_put_at = updated_at", ""
  end
end
