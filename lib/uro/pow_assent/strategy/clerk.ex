defmodule Uro.PowAssent.Strategy.Clerk do
  @moduledoc """
  PowAssent OIDC strategy for Clerk.com.

  Clerk exposes a standard OIDC discovery document at:
    <issuer>/.well-known/openid-configuration

  This strategy uses `Assent.Strategy.OIDC.Base` to handle the full
  authorization code → token exchange → ID token verification flow.
  The Clerk user identity is stored in `user_identities` as:
    provider = "clerk"
    uid      = <Clerk sub claim>

  ## Configuration (via existing config.exs env-var pattern)

  Set these env vars:
    OAUTH2_CLERK_STRATEGY=Uro.PowAssent.Strategy.Clerk
    OAUTH2_CLERK_CLIENT_ID=<Clerk OAuth App client_id>
    OAUTH2_CLERK_CLIENT_SECRET=<Clerk OAuth App client_secret>
    CLERK_ISSUER=https://moral-mule-32.clerk.accounts.dev

  The OAUTH2_CLERK_* vars are picked up automatically by the existing
  config.exs pattern.  CLERK_ISSUER is read at runtime via `default_config/1`.

  ## Normalised user map

  PowAssent requires the normalised map to include `"sub"` and `"email"`.
  Clerk OIDC claims include both.  A `"username"` is derived from the
  Clerk `username` claim or the email local part.
  """

  use Assent.Strategy.OIDC.Base

  @impl true
  def default_config(_config) do
    issuer =
      System.get_env("CLERK_ISSUER") ||
        raise "CLERK_ISSUER env var must be set (e.g. https://moral-mule-32.clerk.accounts.dev)"

    [
      base_url:             issuer,
      openid_configuration: "#{issuer}/.well-known/openid-configuration",
      authorization_params: [scope: "openid email profile"],
      client_authentication_method: "client_secret_post"
    ]
  end

  @impl true
  def normalize(_config, user) do
    # user is the merged map of ID token claims + userinfo endpoint claims.
    # Return the PowAssent-standard shape: {:ok, normalised, extra}
    normalised = %{
      "sub"      => user["sub"],
      "email"    => user["email"],
      "username" => user["username"] || derive_username(user),
      "name"     => full_name(user),
      "image"    => user["image_url"] || user["picture"]
    }

    {:ok, normalised, user}
  end

  defp full_name(%{"given_name" => f, "family_name" => l})
       when is_binary(f) and is_binary(l),
       do: "#{f} #{l}"
  defp full_name(%{"name" => n}) when is_binary(n), do: n
  defp full_name(_), do: nil

  defp derive_username(%{"email" => e}) when is_binary(e) do
    e |> String.split("@") |> List.first() |> String.replace(~r/[^a-zA-Z0-9_]/, "_")
  end
  defp derive_username(_), do: "clerk_user"
end
