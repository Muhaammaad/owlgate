# OwlGate

Phoenix app for access governance flows: request → review → provision → revoke, with an immutable audit trail and role-aware policies.

Architecture and lifecycle diagrams are documented in [`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md).
The implementation handoff blueprint lives in [`docs/OWLGATE_IMPLEMENTATION_BLUEPRINT.md`](./docs/OWLGATE_IMPLEMENTATION_BLUEPRINT.md).

## Requirements

- Elixir ~> 1.15 and Erlang/OTP compatible with Phoenix 1.8
- PostgreSQL

## Setup

```bash
mix setup
```

This installs dependencies, creates the database, runs migrations, and seeds demo users (see `priv/repo/seeds.exs`).

## Configuration

**Development.** Optional `.env` / `.env.local` in the project root, loaded via `Dotenvy` in `config/runtime.exs` when `MIX_ENV=dev` (defaults in `config/dev.exs` are overridden here). Shell exports override file entries. Template: [`.env.example`](./.env.example).

- `DATABASE_USER`, `DATABASE_PASSWORD`, `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_NAME`

**Test.** Unchanged defaults in `config/test.exs` (no Dotenv dependency).

**Production.** No committed `.env`. The host injects configuration; `config/runtime.exs` requires at least:

- `DATABASE_URL`, `SECRET_KEY_BASE`, `PHX_HOST`

Optional: `PORT`, `POOL_SIZE`, `PUBLIC_BASE_URL`, `ECTO_IPV6`, `PHX_SERVER`, `DNS_CLUSTER_QUERY`.

CI/CD and deployment options are outlined in **[`docs/DEPLOYMENT_AND_CI.md`](./docs/DEPLOYMENT_AND_CI.md)**.

### Language (English/German)

- Supported locales: `en`, `de`
- Switch language by visiting:
  - `/locale/en`
  - `/locale/de`
- Locale is persisted in the browser session and applies to controllers + LiveView.

## Run locally

```bash
mix phx.server
```

Then open [http://localhost:4000](http://localhost:4000). After seeding, sign in with `employee@owlgate.local`, `manager@owlgate.local`, or `admin@owlgate.local` (password in seed output).

Dev-only routes (when enabled): Live Dashboard at `/dev/dashboard`, Swoosh mailbox preview at `/dev/mailbox`.

## JSON API (minimal)

Session-authenticated JSON endpoints mirror the LiveView flows. Sign in via the browser (or any client that preserves the session cookie), then call:

| Method | Path | Notes |
| --- | --- | --- |
| POST | `/api/access-requests` | Body: `application_id`, `reason`, optional `subject_user_id` (admins). Rate limited per IP (Hammer). |
| POST | `/api/access-requests/:id/approve` | Reviewer (manager/admin). |
| POST | `/api/access-requests/:id/deny` | Body: optional `reason`. Reviewer. |
| POST | `/api/access-grants/:id/revoke` | Reviewer. |
| GET | `/api/audit-events` | Query: `action`, `entity_type`, `limit` (1–500). Employees see a scoped feed; managers/admins see global. |

Send `Accept: application/json` and `Content-Type: application/json` where applicable. **State-changing requests (POST)** use the same **`protect_from_forgery`** plug as HTML: send header **`x-csrf-token`** with the value from the layout meta tag `<meta name="csrf-token" content="...">` (or `X-CSRF-Token`). `GET /api/audit-events` does not require the token.

`ExUnit`’s `build_conn/0` skips CSRF for tests; production and manual `curl` must include a valid token after signing in.

Errors return JSON objects such as `%{error: "forbidden"}` with appropriate HTTP status codes.

Audit rows written during these requests include `client_ip` and `user_agent` in `metadata` when the request passes through the API plugs.

## Docker Compose (app + PostgreSQL)

For a one-command local boot (no host Elixir/Postgres needed):

```bash
docker compose up --build
```

This starts:

- `postgres` on `localhost:5432`
- Phoenix app on [http://localhost:4000](http://localhost:4000)

The app container runs `mix deps.get`, creates/migrates the dev database, then starts `mix phx.server`.
If port `5432` clashes locally, update the left-hand mapping in [`docker-compose.yml`](./docker-compose.yml).

To stop services:

```bash
docker compose stop
docker compose start
```

To remove containers but keep DB/build volumes:

```bash
docker compose down
```

For a clean reboot (removes Postgres data and cached build/deps volumes):

```bash
docker compose down -v
docker compose up --build
```

Persistence notes:

- Compose project name is pinned (`name: owlgate`) so volume names stay stable across reboots.
- Named volumes are pinned as `owlgate_postgres_data`, `owlgate_mix_deps`, and `owlgate_mix_build`.
- Avoid `docker compose down -v` or `docker system prune --volumes` unless you intentionally want a full reset.

## Tests & CI

Local:

```bash
mix test
```

Full pipeline (format check, warnings-as-errors compile, **Credo**, **Sobelow**, tests)—same as GitHub Actions:

```bash
mix ci
```

CI workflow: [`.github/workflows/ci.yml`](./.github/workflows/ci.yml) (PostgreSQL 16 service, `mix ci`).

Misc: `mix credo`, `mix sobelow_ci` (Sobelow with [`.sobelow-conf`](./.sobelow-conf)). **Dialyzer** is intentionally not wired (heavy); add later if desired.

## Learn more

- Phoenix: https://www.phoenixframework.org/
