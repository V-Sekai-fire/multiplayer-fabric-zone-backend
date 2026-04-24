# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee
defmodule Uro.VSekai.Zone do
  use Ecto.Schema

  import Ecto.Changeset

  alias OpenApiSpex.Schema
  alias Uro.Accounts.User

  @derive {Jason.Encoder,
           only: [
             :user,
             :address,
             :port,
             :map,
             :name,
             :current_users,
             :max_users
           ]}

  schema "zones" do
    belongs_to(:user, Uro.Accounts.User, foreign_key: :user_id, type: :binary_id)

    field(:address, :string)
    field(:port, :integer)
    field(:map, :string)
    field(:name, :string)

    field(:current_users, :integer, default: 0)
    field(:max_users, :integer, default: 32)
    field(:cert_hash, :string)
    field(:last_put_at, :utc_datetime_usec)
    field(:status, :string, default: "public")
    field(:public, :boolean, default: true)

    timestamps()
  end

  @json_schema %Schema{
    title: "Zone",
    type: :object,
    required: [:address, :port, :map, :name],
    properties: %{
      user: User.json_schema(),
      address: %Schema{type: :string, description: "Hostname or IP of the zone server"},
      port: %Schema{type: :integer, description: "UDP port (pool: 7443–7542)"},
      map: %Schema{type: :string},
      name: %Schema{type: :string},
      current_users: %Schema{type: :integer},
      max_users: %Schema{type: :integer},
      cert_hash: %Schema{
        type: :string,
        description:
          "Base64-encoded SHA-256 fingerprint of the zone server's self-signed TLS certificate. Pin this value when opening a WebTransport connection."
      }
    }
  }

  def json_schema, do: @json_schema

  def to_json_schema(%__MODULE__{} = zone) do
    %{
      user: User.to_limited_json_schema(zone.user),
      address: to_string(zone.address),
      port: zone.port,
      map: to_string(zone.map),
      name: to_string(zone.name),
      cert_hash: zone.cert_hash || "",
      status: zone.status || "public",
      public: zone.public,
      desync_index_url: Uro.VSekai.get_desync_url_for_map(zone.map)
    }
  end

  @doc false
  def changeset(zone, attrs) do
    zone
    |> cast(attrs, [
      :user_id,
      :address,
      :port,
      :map,
      :name,
      :current_users,
      :max_users,
      :cert_hash,
      :status,
      :public
    ])
    |> validate_required([:address, :port, :map, :name])
  end
end
