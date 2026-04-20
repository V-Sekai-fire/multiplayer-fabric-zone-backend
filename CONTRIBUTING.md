# Contributing

The Phoenix backend server (Uro) for V-Sekai zone management.  Handles
user accounts, asset storage (S3 via Waffle), zone lifecycle, and
WebTransport datagrams.  Backed by PostgreSQL and Redis; deployed via
Docker Compose with a Caddy reverse proxy.  The `frontend/` directory
contains a Next.js React app served by the same host.

Built strictly red-green-refactor: every feature is driven by a failing
test, committed when green, then any cleanup is done with the test
still green.

## Guiding principles

- **RED first, always.** Write a failing ExUnit or integration test
  before writing implementation code.  Controller tests use
  `Phoenix.ConnTest`; context tests exercise the business logic
  directly.
- **Error tuples, not exceptions.** Ecto changesets surface validation
  errors as `{:error, changeset}`.  External service failures
  (S3, Redis) return `{:error, reason}`.  Do not rescue exceptions
  from the database layer and re-raise; let Ecto return the tuple.
- **Credentials never in source.** All secrets come from environment
  variables loaded via `runtime.exs`.  Do not hardcode API keys,
  database passwords, or S3 credentials in any committed file.
- **Migrations are forward-only.** Once a migration is merged to main,
  do not alter it.  Fixes to a broken migration require a new
  migration.  Every migration must include a `down/0` that reverts it
  cleanly.
- **Commit every green.** One commit per feature or fix cycle.  Messages
  use sentence case; do not use Conventional Commits prefixes (`feat:`,
  `fix:`, `chore:`, etc.).

## Workflow

```
# Start dependencies
docker compose up -d postgres redis

mix deps.get
mix ecto.create && mix ecto.migrate
mix test

# Run the server
mix phx.server
```

For the frontend:

```
cd frontend && npm install && npm run dev
```

## Design notes

### Asset storage

File uploads are handled by Waffle with an S3 backend (`AWS_S3_BUCKET`,
`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_ENDPOINT_URL`).
Local disk storage is used in `dev` and `test` environments only; never
use local disk storage in production.  Upload definitions live in
`lib/uro/uploaders/`; each uploader specifies allowed MIME types and
maximum file size.

### WebTransport datagrams

Zone-to-client real-time data is sent via WebTransport datagrams rather
than WebSockets.  The WebTransport endpoint is registered in the router
as a custom plug.  Datagram handlers must be stateless — session state
lives in the zone server process, not in the endpoint.

### Redis session store

`redix` is used for session storage and pub/sub between zone nodes.
The Redis connection pool is managed by a supervised pool in
`lib/uro/redis/`.  Do not call `Redix` directly from controller code;
go through the context module.

### Email validation

`email_checker` validates email addresses at registration.  It performs
DNS MX record lookups; in tests, stub the DNS call rather than making
real network requests.
