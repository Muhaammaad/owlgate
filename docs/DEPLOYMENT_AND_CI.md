# CI/CD and deployment (OwlGate)

> Deployment/hosting is out of scope for now. This doc covers **local + CI tooling** wired in-repo.

## GitHub Actions

Workflow: **[`.github/workflows/ci.yml`](../.github/workflows/ci.yml)**

- Erlang **26.x**, Elixir **1.15.x**
- Postgres **16** service (healthcheck)
- `mix deps.get` → **`mix ci`** (`MIX_ENV=test` via `mix.exs` `cli`/`:preferred_envs`)

## Local CI mirror

```bash
mix ci
```

This runs: format check → compile `--warnings-as-errors` → **Credo** → **Sobelow** (`mix sobelow_ci`) → tests.

## Credo

- Config: **[`.credo.exs`](../.credo.exs)** (`strict: true`)
- Checks that clash with Phoenix / LiveView patterns (global alias ordering, nesting depth in admin LiveViews, single-condition `cond`, etc.) are **disabled with intent** — re-enable selectively as you refactor.

## Sobelow

- Config: **[`.sobelow-conf`](../.sobelow-conf)** — explicit **`router: "lib/owlgate_web/router.ex"`** so Config checks (CSRF / CSP / headers) always target the Phoenix router; **`exit: "low"`** makes CI fail on any finding. No module ignores by default.
- **CSRF:** `:api` pipeline includes **`protect_from_forgery`**; POSTs require **`x-csrf-token`** (see README).
- **CSP:** **`put_secure_browser_headers/2`** receives an explicit **`content-security-policy`** in **`router.ex`** (`@csp`) so Sobelow’s static check passes.

Runner: **`mix sobelow_ci`** wraps `mix sobelow --config --quiet`.

## Docker Compose

**[`docker-compose.yml`](../docker-compose.yml)** defines **Postgres only** for dev. The Phoenix app stays on the host (`mix phx.server`) unless you add an app service later.

## Deployment (later)

Production still uses **`config/runtime.exs`** (`DATABASE_URL`, `SECRET_KEY_BASE`, `PHX_HOST`, …). Ship with `mix release` + host-managed env when ready.
