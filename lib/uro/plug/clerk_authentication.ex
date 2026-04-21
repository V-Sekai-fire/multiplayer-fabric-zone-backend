defmodule Uro.Plug.ClerkAuthentication do
  @moduledoc """
  Pow plug that accepts Clerk session JWTs as Bearer tokens.

  Works alongside `Uro.Plug.Authentication`. When the Bearer token is a
  valid Clerk JWT this plug verifies it against Clerk's JWKS, then
  finds or creates the Uro user via the `user_identities` join table
  (provider="clerk", uid=<clerk sub>). No extra columns on `users`.

  If the token is not a Clerk JWT the plug is a no-op, letting the
  existing Pow Bearer token flow continue.

  ## Configuration

  Required env var:
    CLERK_ISSUER=https://moral-mule-32.clerk.accounts.dev

  JWKS is fetched from <CLERK_ISSUER>/.well-known/jwks.json and
  cached in ETS for 5 minutes.

  ## Placement in router pipeline

  Add BEFORE `Uro.Plug.Authentication` in the `:api` pipeline:

      plug Uro.Plug.ClerkAuthentication

  Writes `conn.assigns[:current_user]` and `conn.assigns[:access_token]`
  so downstream Pow helpers (`Pow.Plug.current_user/1` etc.) work unchanged.
  """

  @behaviour Plug

  import Plug.Conn

  alias Uro.Accounts
  alias Uro.UserIdentities
  alias Uro.UserIdentities.UserIdentity
  alias Uro.Repo

  @provider "clerk"
  @ets_table :clerk_jwks_cache
  @cache_ttl_ms 5 * 60 * 1_000

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    with {:ok, jwt}    <- fetch_bearer(conn),
         true          <- clerk_jwt?(jwt),
         {:ok, claims} <- verify_clerk_jwt(jwt),
         {:ok, user}   <- upsert_user(claims) do
      conn
      |> assign(:current_user, user)
      |> assign(:access_token, jwt)
    else
      _ -> conn
    end
  end

  # ── Bearer extraction ─────────────────────────────────────────────────────────

  defp fetch_bearer(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token | _] -> {:ok, String.trim(token)}
      _                        -> :error
    end
  end

  # Returns true only when the JWT payload `iss` matches the configured Clerk issuer.
  defp clerk_jwt?(jwt) do
    with [_, payload_b64 | _] <- String.split(jwt, "."),
         padded                <- pad_base64(payload_b64),
         {:ok, json}           <- Base.url_decode64(padded, padding: false),
         {:ok, claims}         <- Jason.decode(json) do
      String.starts_with?(claims["iss"] || "", clerk_issuer())
    else
      _ -> false
    end
  end

  # ── JWT verification ──────────────────────────────────────────────────────────

  defp verify_clerk_jwt(jwt) do
    with {:ok, jwks}   <- fetch_jwks(),
         {:ok, claims} <- verify_with_jwks(jwt, jwks) do
      validate_claims(claims)
    end
  end

  defp verify_with_jwks(jwt, jwks) do
    (jwks["keys"] || [])
    |> Enum.reduce_while({:error, :no_matching_key}, fn key, _acc ->
      case try_verify(jwt, key) do
        {:ok, claims} -> {:halt, {:ok, claims}}
        _             -> {:cont, {:error, :no_matching_key}}
      end
    end)
  end

  defp try_verify(jwt, %{"kty" => "RSA", "n" => n, "e" => e}) do
    signer = Joken.Signer.create("RS256", %{"n" => n, "e" => e})
    Joken.verify(jwt, signer)
  rescue
    _ -> {:error, :verify_failed}
  end

  defp try_verify(jwt, %{"kty" => "EC", "crv" => crv, "x" => x, "y" => y}) do
    alg    = ec_alg(crv)
    signer = Joken.Signer.create(alg, %{"crv" => crv, "x" => x, "y" => y})
    Joken.verify(jwt, signer)
  rescue
    _ -> {:error, :verify_failed}
  end

  defp try_verify(_, _), do: {:error, :unsupported_key_type}

  defp ec_alg("P-256"), do: "ES256"
  defp ec_alg("P-384"), do: "ES384"
  defp ec_alg("P-521"), do: "ES512"
  defp ec_alg(_),       do: "ES256"

  defp validate_claims(claims) do
    now    = System.system_time(:second)
    issuer = clerk_issuer()

    cond do
      claims["iss"] != issuer      -> {:error, :invalid_issuer}
      (claims["exp"] || 0) < now   -> {:error, :token_expired}
      (claims["nbf"] || 0) > now   -> {:error, :token_not_yet_valid}
      is_nil(claims["sub"])        -> {:error, :missing_sub}
      true                         -> {:ok, claims}
    end
  end

  # ── JWKS with ETS cache ───────────────────────────────────────────────────────

  defp fetch_jwks do
    ensure_ets_table()
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@ets_table, :jwks) do
      [{:jwks, jwks, fetched_at}] when now - fetched_at < @cache_ttl_ms ->
        {:ok, jwks}

      _ ->
        url = "#{clerk_issuer()}/.well-known/jwks.json"

        case HTTPoison.get(url, [], recv_timeout: 5_000) do
          {:ok, %{status_code: 200, body: body}} ->
            with {:ok, jwks} <- Jason.decode(body) do
              :ets.insert(@ets_table, {:jwks, jwks, now})
              {:ok, jwks}
            end

          {:error, reason} ->
            {:error, {:jwks_fetch_failed, reason}}
        end
    end
  end

  defp ensure_ets_table do
    case :ets.whereis(@ets_table) do
      :undefined -> :ets.new(@ets_table, [:named_table, :public, read_concurrency: true])
      _          -> @ets_table
    end
  end

  # ── User upsert via user_identities ──────────────────────────────────────────

  # Look up user_identities(provider="clerk", uid=sub), then upsert via
  # PowAssent so the relation stays normalised in the join table.
  defp upsert_user(%{"sub" => uid} = claims) do
    case find_by_identity(uid) do
      %Uro.Accounts.User{} = user ->
        {:ok, user}

      nil ->
        create_via_pow_assent(uid, claims)
    end
  end

  defp upsert_user(_), do: {:error, :missing_sub}

  defp find_by_identity(uid) do
    import Ecto.Query

    result =
      Repo.one(
        from ui in UserIdentity,
          where: ui.provider == ^@provider and ui.uid == ^uid,
          join: u in assoc(ui, :user),
          select: u
      )

    result && Repo.preload(result, :user_privilege_ruleset)
  rescue
    DBConnection.ConnectionError -> nil
    Ecto.QueryError               -> nil
  end

  defp create_via_pow_assent(_uid, %{"email" => email}) when not is_binary(email) or email == "" do
    {:error, :missing_email}
  end

  defp create_via_pow_assent(uid, claims) do
    user_identity_params = %{
      "provider" => @provider,
      "uid"      => uid
    }

    username = derive_username(claims)

    user_params = %{
      "email"        => claims["email"],
      "username"     => username,
      "display_name" => claims["name"] || username
    }

    case UserIdentities.create_user(user_identity_params, user_params, %{"email" => claims["email"]}) do
      {:ok, user}      -> {:ok, user}
      {:error, reason} -> {:error, {:create_failed, reason}}
    end
  end

  # ── Helpers ───────────────────────────────────────────────────────────────────

  defp derive_username(%{"username" => u}) when is_binary(u) and u != "", do: u
  defp derive_username(%{"email" => e}) when is_binary(e) do
    base   = e |> String.split("@") |> List.first() |> String.replace(~r/[^a-zA-Z0-9_]/, "_")
    suffix = :rand.uniform(9999) |> Integer.to_string()
    "#{base}_#{suffix}"
  end
  defp derive_username(_), do: "clerk_#{Pow.UUID.generate() |> String.slice(0..7)}"

  defp pad_base64(b64) do
    case rem(byte_size(b64), 4) do
      2 -> b64 <> "=="
      3 -> b64 <> "="
      _ -> b64
    end
  end

  defp clerk_issuer do
    System.get_env("CLERK_ISSUER") ||
      raise "CLERK_ISSUER env var must be set (e.g. https://your-instance.clerk.accounts.dev)"
  end
end
