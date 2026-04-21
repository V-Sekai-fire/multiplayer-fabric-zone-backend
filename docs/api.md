# API reference

Base URL: `https://hub-700a.chibifire.com`

Interactive API docs (OpenAPI): `GET /docs`
Raw OpenAPI spec: `GET /openapi`

## Authentication

Most write endpoints require a session token. Pass it as a Bearer token:

```
Authorization: Bearer <token>
```

Tokens are obtained from `POST /session` (Pow session) or are Clerk JWTs
(verified against `CLERK_ISSUER/.well-known/jwks.json`). See [Authentication](authentication.md).

---

## Health

### GET /health

Returns service health status. No authentication required.

```json
{"services":{"uro":"healthy"}}
```

---

## Session

### POST /session

Login with email and password (game client flow).

Request:
```json
{"user": {"email": "...", "password": "..."}}
```

Response:
```json
{"data": {"token": "<bearer token>", "renew_token": "<renew token>"}}
```

### POST /session/renew

Exchange a renew token for a fresh session token.

### GET /session

Returns the current session user. Requires authentication.

### DELETE /session

Logout (invalidates the current session token). Requires authentication.

### POST /login

Login (web client flow).

### GET /login/:provider

Redirect to OAuth provider login page.

### GET /login/:provider/callback

OAuth provider callback.

---

## Users

### POST /users

Create a new user account.

Request:
```json
{"user": {"email": "...", "password": "...", "username": "..."}}
```

### GET /users

List users. Requires authentication.

### GET /users/:user_id

Get a single user by ID.

### POST /users/:user_id/email

Confirm email address (accepts confirmation token in body).

### PATCH /users/:user_id

Update user fields. Requires authentication.

### PUT /users/:user_id/email

Update email address. Requires authentication.

### PATCH /users/:user_id/email

Resend confirmation email. Requires authentication.

### GET /users/:user_id/friend, POST /users/:user_id/friend, DELETE /users/:user_id/friend

Manage friend relationship with another user. Requires authentication.

---

## Registration (game client)

### POST /registration

Create a new user account using the API key client secret flow.

---

## Profile (game client)

### GET /profile

Returns the current user's profile. Uses `ChooseAuth` (accepts both Pow session
and Clerk JWT).

---

## Zones

Zone servers self-register on boot. The endpoints use the path `/shards`
in the current implementation.

### GET /shards

List all registered zones. No authentication required.

Response:
```json
{
  "data": {
    "shards": [
      {
        "address": "zone-700a.chibifire.com",
        "port": 7443,
        "map": "mire",
        "name": "Zone 700a",
        "current_users": 0,
        "max_users": 32,
        "cert_hash": "<base64 SHA-256>"
      }
    ]
  }
}
```

### POST /shards

Register a new zone (called by zone server on boot). Requires authentication.

Request:
```json
{
  "shard": {
    "address": "zone-700a.chibifire.com",
    "port": 7443,
    "map": "mire",
    "name": "Zone 700a",
    "cert_hash": "<base64 SHA-256>"
  }
}
```

### PUT /shards/:id

Heartbeat update (called by zone server every ~25 s). Updates `updated_at`.
Requires authentication.

### DELETE /shards/:id

Deregister a zone. Requires authentication.

---

## Storage

Files are stored in VersityGW via AriaStorage. Raw uploads are baked asynchronously
into casync format (`.caidx` index + `.cacnk` chunks). See [Asset pipeline](assets.md).

### GET /storage/tag/:tag

List public files with the given tag. No authentication required.

### GET /storage/:id

Get metadata for a single public file. No authentication required.

### POST /storage/:id/manifest

Returns the file's storage manifest: raw upload location, chunk list, and baked URL.

Response:
```json
{
  "data": {
    "store_url": "http://versitygw:7070/uro-uploads/<id>",
    "chunks": [{"hash": "...", "offset": 0, "length": 1048576}],
    "baked_url": "http://versitygw:7070/uro-uploads/<id>.caidx"
  }
}
```

### GET /storage

List all public files (requires `authenticated_shared_file` permission).

### POST /storage

Upload a new file. Requires `authenticated_shared_file` permission.

Request: multipart form with `storage[shared_content_data]` file field.

Response:
```json
{"data": {"id": "<uuid>", "file": {...}}}
```

### PUT /storage/:id

Update file metadata. Requires `authenticated_shared_file` permission.

### DELETE /storage/:id

Delete a file. Requires `authenticated_shared_file` permission.

### POST /storage/:id/bake

Set the `baked_url` on a file record after the baker completes.
Requires `authenticated_shared_file` permission (used by baker container).

Request:
```json
{"baked_url": "http://versitygw:7070/uro-uploads/<id>.caidx"}
```

---

## Avatars

### GET /avatars

List public avatars.

### GET /avatars/:id

Get a single avatar.

### Dashboard (authenticated)

`GET /dashboard/avatars`, `GET /dashboard/avatars/:id`, `POST /dashboard/avatars`,
`PUT /dashboard/avatars/:id`, `DELETE /dashboard/avatars/:id`

Requires `authenticated_user` + `dashboard_avatars` permission.

---

## Maps

### GET /maps

List public maps.

### GET /maps/:id

Get a single map.

### Dashboard (authenticated)

`GET /dashboard/maps`, `GET /dashboard/maps/:id`, `POST /dashboard/maps`,
`PUT /dashboard/maps/:id`, `DELETE /dashboard/maps/:id`

Requires `authenticated_user` + `dashboard_maps` permission.

---

## Props (dashboard only)

`GET /dashboard/props`, `GET /dashboard/props/:id`, `POST /dashboard/props`,
`PUT /dashboard/props/:id`, `DELETE /dashboard/props/:id`

Requires `authenticated_user` + `dashboard_props` permission.

---

## Admin

### GET /admin

Returns server status. Requires admin authentication.
