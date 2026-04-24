defmodule Uro.Repo.Migrations.AddLastPutAtToZones do
  use Ecto.Migration

  # CockroachDB does not allow reading a newly-added column in the same
  # transaction as the ALTER TABLE that created it. Disabling the DDL
  # transaction causes the ALTER to commit before the UPDATE runs.
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    alter table(:zones) do
      add :last_put_at, :utc_datetime_usec, null: true
    end

    flush()

    # Seed from updated_at so existing live zones are not immediately culled.
    execute "UPDATE zones SET last_put_at = updated_at", ""
  end
end
