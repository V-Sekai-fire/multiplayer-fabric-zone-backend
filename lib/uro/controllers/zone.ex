defmodule Uro.ZoneController do
  use Uro, :controller

  alias OpenApiSpex.Schema
  alias Uro.Repo
  alias Uro.VSekai
  alias Uro.VSekai.Zone

  tags(["zones"])

  def ensure_has_address(conn, params) do
    if !Map.has_key?(params, "address") do
      Map.put(params, "address", to_string(:inet_parse.ntoa(conn.remote_ip)))
    else
      params
    end
  end

  def ensure_user_is_current_user_or_nil(conn, params) do
    if Uro.Helpers.Auth.signed_in?(conn) do
      Map.put(params, "user_id", Uro.Helpers.Auth.get_current_user(conn).id)
    else
      Map.put(params, "user_id", nil)
    end
  end

  def can_connection_modify_zone(conn, zone) do
    if zone.user != nil and
         Uro.Helpers.Auth.signed_in?(conn) and
         zone.user == Uro.Helpers.Auth.get_current_user(conn) do
      true
    else
      if zone.user == nil and
           zone.address == to_string(:inet_parse.ntoa(conn.remote_ip)) do
        true
      else
        false
      end
    end
  end

  operation(:index,
    operation_id: "listZones",
    summary: "List Zones",
    responses: [
      ok: {
        "",
        "application/json",
        %Schema{
          type: :array,
          items: Zone.json_schema()
        }
      }
    ]
  )

  def index(conn, _params) do
    zones = VSekai.list_fresh_zones()
    zones_json = Enum.map(zones, fn x -> Zone.to_json_schema(x) end)

    conn
    |> put_status(200)
    |> json(%{data: %{shards: zones_json}})
  end

  operation(:create,
    operation_id: "createZone",
    summary: "Create Zone",
    request_body: {
      "",
      "application/json",
      Zone.json_schema()
    },
    responses: [
      ok: {
        "",
        "application/json",
        %Schema{
          type: :object,
          required: [:id],
          properties: %{
            id: %Schema{
              type: :string
            }
          }
        }
      }
    ]
  )

  def create(conn, zone_params) do
    zone_params = ensure_has_address(conn, zone_params)

    conn
    |> ensure_user_is_current_user_or_nil(zone_params)
    |> VSekai.create_zone()
    |> case do
      {:ok, zone} ->
        conn
        |> put_status(200)
        |> json(%{data: %{id: to_string(zone.id)}})

      {:error, %Ecto.Changeset{}} ->
        json_error(conn)
    end
  end

  operation(:update,
    operation_id: "updateZone",
    summary: "Update Zone",
    parameters: [
      id: [
        in: :path,
        schema: %Schema{
          type: :string
        }
      ]
    ],
    responses: [
      ok: {
        "",
        "application/json",
        Zone.json_schema()
      }
    ]
  )

  def update(conn, %{"id" => id, "shard" => zone_params}) do
    zone = VSekai.get_zone!(id)

    if can_connection_modify_zone(conn, zone) do
      case VSekai.update_zone(zone, zone_params) do
        {:ok, zone} ->
          conn
          |> put_status(200)
          |> json(%{data: %{id: to_string(zone.id)}})

        {:error, %Ecto.Changeset{}} ->
          json_error(conn)
      end
    else
      json_error(conn)
    end
  end

  def update(conn, %{"id" => id}) do
    update(conn, %{"id" => id, "shard" => %{}})
  end

  operation(:delete,
    operation_id: "deleteZone",
    summary: "Delete Zone",
    parameters: [
      id: [
        in: :path,
        schema: %Schema{
          type: :string
        }
      ]
    ],
    responses: [
      ok: {
        "",
        "application/json",
        success_json_schema()
      }
    ]
  )

  def delete(conn, %{"id" => id}) do
    zone =
      Uro.VSekai.Zone
      |> Repo.get!(id)
      |> Repo.preload(:user)
      |> Repo.preload(user: [:user_privilege_ruleset])

    if can_connection_modify_zone(conn, zone) do
      case VSekai.delete_zone(zone) do
        {:ok, zone} ->
          conn
          |> put_status(200)
          |> json(%{data: %{id: to_string(zone.id)}})

        {:error, %Ecto.Changeset{}} ->
          json_error(conn)
      end
    else
      json_error(conn)
    end
  end
end
