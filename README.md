# OwlGate

Phoenix app for access governance flows: request → review → provision → revoke, with an immutable audit trail and role-aware policies.

## Requirements

- Elixir ~> 1.15 and Erlang/OTP compatible with Phoenix 1.8
- PostgreSQL

## Setup

```bash
mix setup
```

This installs dependencies, creates the database, runs migrations, and seeds demo users (see `priv/repo/seeds.exs`).

## Configuration

Development and test use local defaults in `config/dev.exs` and `config/test.exs`.

Production reads environment variables from `config/runtime.exs`, including:

- `DATABASE_URL`, `SECRET_KEY_BASE`, `PHX_HOST` (required in prod)
- `PORT`, `POOL_SIZE`, `PUBLIC_BASE_URL`, `ECTO_IPV6`, `PHX_SERVER`, `DNS_CLUSTER_QUERY` (optional)

Set these in your host environment or process manager; Phoenix does not load a `.env` file unless you add tooling for it.

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

Send `Accept: application/json` and `Content-Type: application/json` where applicable. Errors return JSON objects such as `%{error: "forbidden"}` with appropriate HTTP status codes.

Audit rows written during these requests include `client_ip` and `user_agent` in `metadata` when the request passes through the API plugs.

## Tests

```bash
mix test
```

Optional quality tooling (Credo, Sobelow, Dialyzer) can be added for CI as needed.

## Learn more

- Phoenix: https://www.phoenixframework.org/
