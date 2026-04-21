# Authentication

`zone-backend` supports two authentication paths in the same request pipeline:
Pow session tokens and Clerk JWTs. Both paths write `conn.assigns[:current_user]`
so downstream code is identical either way.

## Request pipeline order

```
Plug.ClerkAuthentication   ← checks Bearer token for Clerk JWT
Pow.Plug.Authentication    ← falls through to Pow if current_user not yet set
```

Pow skips its fetch when `conn.assigns[:current_user]` is already set, so the
two plugs are non-conflicting.

## Pow session tokens

`POST /session` (game client) or `POST /login` (web client) returns a Bearer
token and a renew token. The Bearer token is sent as:

```
Authorization: Bearer <token>
```

Tokens are stored in CockroachDB and rotate on renew. Use `POST /session/renew`
with the renew token to get a new session without re-entering credentials.

## Clerk JWT authentication

Clerk issues JWTs signed with RS256 or EC keys. The `ClerkAuthentication` plug:

1. Reads the `Authorization: Bearer <jwt>` header.
2. Decodes the JWT payload (base64url, segment 2) and checks `iss` against
   `CLERK_ISSUER`.
3. Fetches `CLERK_ISSUER/.well-known/jwks.json` (cached 5 minutes in ETS).
4. Verifies the JWT signature against all JWKS keys (RS256 and EC).
5. Validates `iss`, `exp`, `nbf`, and `sub` claims.
6. Looks up the Uro user via `user_identities(provider="clerk", uid=<sub>)`.
7. If no identity exists, creates a new `users` row and `user_identities` join
   record via PowAssent.

### Required environment variable

```
CLERK_ISSUER=https://your-instance.clerk.accounts.dev
```

### User identity storage

Clerk users are stored in the `user_identities` table with `provider="clerk"` and
`uid=<clerk subject claim>`. The `users` table needs no extra columns. The email,
username, and display name are taken from the JWT claims on first login.

If the JWT carries no email, authentication is rejected with `{:error, :missing_email}`.

### JWKS cache

The JWKS document is cached in ETS under the `:clerk_jwks_cache` table with a
5-minute TTL. On expiry the next request refetches from Clerk's `.well-known`
endpoint. Cache misses during network failures fall back to the previous cached
value when available.

## Authorization pipelines

`router.ex` defines several permission pipelines:

| Pipeline | Plug(s) | Used for |
|----------|---------|----------|
| `:api` | `ClerkAuthentication`, `Pow.Plug.Authentication` | All routes |
| `:authenticated` | `Pow.Plug.RequireAuthenticated` | Write routes on `/users` |
| `:authenticated_admin` | `RequireAuthenticated` + `RequireAdmin` | `/admin` |
| `:authenticated_user` | `ChooseAuth` | Dashboard, `/profile`, `/session` reads |
| `:authenticated_shared_file` | `RequireSharedFileUploadPermission` | Storage writes + bake |
| `:dashboard_avatars` | `RequireAvatarUploadPermission` | Avatar uploads |
| `:dashboard_maps` | `RequireMapUploadPermission` | Map uploads |
| `:dashboard_props` | `RequirePropUploadPermission` | Prop uploads |

`ChooseAuth` accepts either a Pow session or a Clerk JWT (whichever was already
set by the earlier plugs in the pipeline).
