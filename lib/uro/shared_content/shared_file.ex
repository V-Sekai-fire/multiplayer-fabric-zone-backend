# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee
defmodule Uro.SharedContent.SharedFile do
  import Ecto.Changeset
  use Uro.SharedContent.SharedContent

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Phoenix.Param, key: :id}
  schema "shared_files" do
    shared_content_fields()

    field :store_url, :string
    field :chunks, {:array, :map}
    field :baked_url, :string

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(shared_file, attrs) do
    shared_file
    |> shared_content_changeset(attrs)
    |> cast(attrs, [:store_url, :chunks, :baked_url])
  end

  @doc false
  def upload_changeset(shared_file, attrs) do
    shared_content_upload_changeset(shared_file, attrs)
  end

  @doc false
  def bake_changeset(shared_file, attrs) do
    shared_file
    |> cast(attrs, [:baked_url])
    |> validate_required([:baked_url])
  end
end
