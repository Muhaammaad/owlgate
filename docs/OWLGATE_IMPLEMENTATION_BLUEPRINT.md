# OwlGate Implementation Blueprint

This document is the execution handoff for building OwlGate as a production-grade Phoenix application aligned to Access Governance workflows (request, approval, provision, revoke, audit).

## 1) Product Goal

Build a small but serious access lifecycle system that demonstrates:

- role-aware access requests and approvals
- policy enforcement (no self-approval, owner/risk gates)
- asynchronous provisioning/revocation via jobs
- immutable audit timeline
- clean modular architecture
- strong tests, error handling, and secure defaults

## 2) Tech Stack

- Elixir + Phoenix (latest stable)
- Phoenix LiveView (operator/admin UI)
- Ecto + PostgreSQL
- Oban (jobs/retries/idempotency)
- Pow (optional, minimal auth only) or generated auth if preferred
- ExUnit + StreamData (property tests where useful)
- Sobelow (security scan)
- Credo + formatter + dialyzer (quality gates)

## 3) High-Level Architecture

- `lib/owlgate/` -> domain/business logic (contexts only)
- `lib/owlgate_web/` -> web layer (controllers, LiveViews, plugs, views)
- `lib/owlgate/workers/` -> Oban jobs
- `lib/owlgate/connectors/` -> provisioning adapter behavior + mock adapters
- `lib/owlgate/policies/` -> authorization policy modules
- `lib/owlgate/audit/` -> event writer/query
- `priv/repo/migrations/` -> schema migrations

Rule: web layer orchestrates, contexts decide, workers execute side effects.

## 4) Core Contexts and Modules

### 4.1 Accounts

- `OwlGate.Accounts.User`
  - fields: `email`, `name`, `role` (`employee|manager|admin`), `manager_id`, `mfa_required`
  - constraints: unique email, role enum check
- `OwlGate.Accounts` context
  - user CRUD and role updates

### 4.2 Access Control

- `OwlGate.Access.Application`
  - fields: `name`, `slug`, `risk_level` (`low|medium|high`), `owner_id`, `active`
- `OwlGate.Access.AccessRequest`
  - fields: `user_id`, `application_id`, `reason`, `status`, `reviewed_by_id`, `reviewed_at`, `expires_at`, `request_token`
  - status enum: `pending|approved|denied|provisioning|active|revoking|revoked|failed`
- `OwlGate.Access.AccessGrant`
  - fields: `user_id`, `application_id`, `status`, `granted_by_id`, `granted_at`, `revoked_at`, `external_ref`
- `OwlGate.Access` context
  - `create_request/2`
  - `approve_request/2`
  - `deny_request/2`
  - `mark_provisioning/1`
  - `activate_grant/2`
  - `request_revoke/2`
  - `complete_revoke/1`

### 4.3 Policy

- `OwlGate.Policy.AccessPolicy`
  - `can_request?/2`
  - `can_review?/2`
  - `can_self_approve?/2` -> always false
  - `requires_app_owner_approval?/1` (high risk)

### 4.4 Audit

- `OwlGate.Audit.Event`
  - fields: `actor_id`, `action`, `entity_type`, `entity_id`, `metadata`, `occurred_at`
- `OwlGate.Audit.log/5`
  - append-only event recording on every state transition

### 4.5 Connectors and Workers

- `OwlGate.Connectors.Adapter` behavior
  - `provision(map()) :: {:ok, map()} | {:error, term()}`
  - `revoke(map()) :: {:ok, map()} | {:error, term()}`
- `OwlGate.Connectors.MockSlack` (or MockGoogleWorkspace)
- `OwlGate.Connectors.Dispatcher`
  - maps app slug/type -> adapter
- `OwlGate.Workers.ProvisionAccessJob`
- `OwlGate.Workers.RevokeAccessJob`

## 5) End-to-End Flows

### 5.1 Access Request

1. employee submits request for an application with reason
2. policy checks run (role, existing active grant, app active)
3. request inserted with status `pending`
4. audit event `access_request.created`

### 5.2 Approval / Denial

1. manager/admin reviews `pending`
2. deny path -> status `denied`, audit `access_request.denied`
3. approve path:
   - enforce no self-approval
   - if high-risk app, enforce owner/admin rule
   - transition to `provisioning`
   - enqueue `ProvisionAccessJob`
   - audit `access_request.approved`

### 5.3 Provisioning

1. worker uses idempotency key (`request_id + action`)
2. calls connector adapter
3. success:
   - create/activate grant
   - request -> `active`
   - audit `access_grant.activated`
4. failure:
   - request -> `failed`
   - audit `access_provision.failed`
   - retry via Oban policy

### 5.4 Revoke

1. manager/admin triggers revoke on active grant
2. grant/request move to revoking state, enqueue revoke job
3. connector revoke call
4. success -> statuses `revoked`, audit `access_grant.revoked`

## 6) LiveView UI Scope

- `DashboardLive` -> counts (pending, active, failed)
- `AccessRequestLive.Index` -> list with filters + create request CTA
- `AccessRequestLive.Show` -> timeline + approve/deny actions (authorized)
- `GrantLive.Index` -> active/revoking/revoked grants + revoke action
- `ApplicationLive.Index` -> app list/create/update for admin
- `AuditLive.Index` -> immutable audit feed with filters

UI principles:

- server-side authorization checks for each action
- optimistic feedback only after successful transition
- show explicit state badges and error reasons

## 7) Security Requirements

- enforce authorization in contexts, not only LiveView
- role checks for each mutation
- prevent self-approval
- validate and sanitize params with changesets
- use UUIDs for external IDs (optional but preferred)
- no secrets in repo; `.env.example` only
- CSRF/session defaults retained
- rate-limit request creation endpoint/live action (plug + basic bucket)
- audit sensitive actions with actor identity and source IP/user agent metadata

## 8) Error Handling and Edge Cases

Must handle:

- duplicate request for same user/app while active or pending
- approval race conditions (double-click / concurrent reviewers)
- worker retries and dead-letter handling
- connector timeout and partial failure
- revoked app (inactive) while requests still pending
- manager without permission trying to approve high-risk app
- stale LiveView state (record changed by another operator)

Implementation patterns:

- use `Ecto.Multi` for transitions that must stay atomic
- use optimistic lock (`lock_version`) on mutable critical records
- map domain errors to explicit tuples (`{:error, :duplicate_request}` etc.)
- central error translation for LiveView flash and API JSON

## 9) API Endpoints (minimal)

- `POST /api/access-requests`
- `POST /api/access-requests/:id/approve`
- `POST /api/access-requests/:id/deny`
- `POST /api/access-grants/:id/revoke`
- `GET /api/audit-events`

All mutating routes require authenticated actor with role checks.

Implementation notes (current):

- Authentication uses the **same session cookie** as the HTML UI (`fetch_session` + `AssignCurrentUser`). Clients obtain a session by signing in through `/login`, then reuse the cookie for JSON requests.
- `POST /api/access-requests` is **rate limited** per client IP (Hammer / configured backend).
- Sensitive audit metadata (`client_ip`, `user_agent`) is merged into `Audit.log/5` metadata for API-driven mutations that run the audit request plug (see `README.md`).

## 10) Testing Strategy

### Unit

- changesets validation and constraints
- policy function coverage
- connector dispatcher routing

### Integration

- request -> approve -> active happy path
- request -> deny
- provisioning failure + retry behavior
- revoke happy/failure paths

### LiveView

- role-gated action visibility
- event handlers produce correct transitions
- stale action handling

### Worker tests

- idempotency behavior
- retry and terminal failure behavior

### Security and quality gates

- run `mix test --cover`
- run `mix credo --strict`
- run `mix sobelow --config`
- run `mix dialyzer` in CI

## 11) CI/CD and Repo Standards

- GitHub Actions (or Bitbucket pipelines) with stages:
  1. format check
  2. compile with warnings as errors
  3. test
  4. credo
  5. sobelow
- commit hooks for formatting and linting
- semantic, scoped commit messages
