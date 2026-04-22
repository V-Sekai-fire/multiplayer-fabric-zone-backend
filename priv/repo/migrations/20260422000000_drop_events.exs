# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee
defmodule Uro.Repo.Migrations.DropEvents do
  use Ecto.Migration

  def up do
    drop table(:events)
  end

  def down do
    create table(:events) do
      add :description, :string
      add :name, :string
      add :start_date, :utc_datetime
      add :end_date, :utc_datetime

      timestamps()
    end
  end
end
