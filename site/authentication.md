# Authentication

`zone-backend` uses Pow session tokens for authentication. The session token is
written to `conn.assigns[:current_user]` so all downstream controller code is
uniform regardless of how the session was established.

## Request pipeline order

```
Pow.Plug.Authentication    ← fetches current_user from session token
```

## Pow session tokens

`POST /session` (game client) or `POST /login` (web client) returns a Bearer
token and a renew token. The Bearer token is sent as:

```
Authorization: Bearer <token>
```

Tokens are stored in CockroachDB and rotate on renew. Use `POST /session/renew`
with the renew token to get a new session without re-entering credentials.

## Authorization pipelines

`router.ex` defines several permission pipelines:

| Pipeline | Plug(s) | Used for |
|----------|---------|----------|
| `:api` | `Pow.Plug.Authentication` | All routes |
| `:authenticated` | `Pow.Plug.RequireAuthenticated` | Write routes on `/users` |
| `:authenticated_admin` | `RequireAuthenticated` + `RequireAdmin` | `/admin` |
| `:authenticated_user` | `ChooseAuth` | Dashboard, `/profile`, `/session` reads |
| `:authenticated_shared_file` | `RequireSharedFileUploadPermission` | Storage writes + bake |
| `:dashboard_avatars` | `RequireAvatarUploadPermission` | Avatar uploads |
| `:dashboard_maps` | `RequireMapUploadPermission` | Map uploads |
| `:dashboard_props` | `RequirePropUploadPermission` | Prop uploads |
