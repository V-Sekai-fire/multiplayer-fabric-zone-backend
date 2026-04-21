# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee
defmodule Uro.SharedContent.SharedFile do
  import Ecto.Changeset
  use Uro.SharedContent.SharedContent

  alias OpenApiSpex.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Phoenix.Param, key: :id}
  @asset_pipeline_properties %{
    store_url: %Schema{
      type: :string,
      nullable: true,
      description: "Raw upload location in VersityGW"
    },
    chunks: %Schema{
      type: :array,
      items: %Schema{type: :object},
      nullable: true,
      description: "casync chunk descriptors [{hash, offset, length}]"
    },
    baked_url: %Schema{
      type: :string,
      nullable: true,
      description:
        "casync .caidx index URL in VersityGW; null until the baker container completes"
    }
  }

  def json_schema do
    base = super()
    %{base | properties: Map.merge(base.properties, @asset_pipeline_properties)}
  end

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
