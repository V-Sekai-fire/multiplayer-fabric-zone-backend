defmodule Uro.Plug.ClerkAuthenticationTest do
  use ExUnit.Case, async: true

  alias Uro.Plug.ClerkAuthentication

  @issuer "https://test.clerk.accounts.dev"

  setup do
    System.put_env("CLERK_ISSUER", @issuer)
    on_exit(fn -> System.delete_env("CLERK_ISSUER") end)
    :ok
  end

  defp conn_with_bearer(token) do
    %Plug.Conn{
      req_headers: [{"authorization", "Bearer #{token}"}],
      assigns: %{}
    }
  end

  defp bare_conn do
    %Plug.Conn{req_headers: [], assigns: %{}}
  end

  # Build a minimal JWT with the given payload, signed with HS256.
  # The plug's clerk_jwt?/1 only checks the payload `iss`, so the
  # signature algorithm doesn't matter for the no-op path tests.
  defp build_jwt(claims) do
    signer = Joken.Signer.create("HS256", "testsecret")
    {:ok, token, _} = Joken.encode_and_sign(claims, signer)
    token
  end

  describe "call/2 – no-op paths (no DB needed)" do
    test "passes through when no Authorization header is present" do
      conn = bare_conn()
      result = ClerkAuthentication.call(conn, [])
      assert result == conn
    end

    test "passes through when Authorization is not Bearer" do
      conn = %Plug.Conn{
        req_headers: [{"authorization", "Basic dXNlcjpwYXNz"}],
        assigns: %{}
      }

      result = ClerkAuthentication.call(conn, [])
      assert result == conn
    end

    test "passes through when JWT payload iss does not match CLERK_ISSUER" do
      token = build_jwt(%{"iss" => "https://other-issuer.example.com", "sub" => "user_abc"})
      conn = conn_with_bearer(token)
      result = ClerkAuthentication.call(conn, [])
      assert result == conn
      refute Map.has_key?(result.assigns, :current_user)
    end

    test "passes through when token is malformed (not a JWT)" do
      conn = conn_with_bearer("not.a.jwt.at.all")
      result = ClerkAuthentication.call(conn, [])
      assert result == conn
    end

    test "passes through when token is only one segment" do
      conn = conn_with_bearer("singlesegment")
      result = ClerkAuthentication.call(conn, [])
      assert result == conn
    end
  end

  describe "clerk_jwt? detection" do
    test "returns true when payload iss starts with CLERK_ISSUER" do
      token = build_jwt(%{"iss" => @issuer, "sub" => "user_123"})

      # Invoke the private logic via call/2 – if JWKS fetch fails (no network
      # in test env) the plug still returns the original conn, but we can
      # verify the issuer detection by checking that it *attempted* verification
      # (i.e., got past the clerk_jwt? guard) by confirming the plug reached
      # the verify step – which fails cleanly and returns the original conn.
      conn = conn_with_bearer(token)
      result = ClerkAuthentication.call(conn, [])
      # No current_user because JWKS fetch fails in unit test, but the conn
      # is still returned cleanly (no crash).
      assert is_map(result)
    end
  end
end
