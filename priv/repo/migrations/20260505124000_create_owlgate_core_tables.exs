defmodule OwlGate.Repo.Migrations.CreateOwlgateCoreTables do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :name, :string, null: false
      add :role, :string, null: false
      add :mfa_required, :boolean, null: false, default: false
      add :manager_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, ["lower(email)"], name: :users_lower_email_idx)
    create index(:users, [:manager_id])

    create constraint(:users, :users_role_check,
             check: "role in ('employee', 'manager', 'admin')"
           )

    create constraint(:users, :users_manager_not_self_check,
             check: "manager_id is null OR manager_id <> id"
           )

    create table(:applications) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :risk_level, :string, null: false
      add :active, :boolean, null: false, default: true
      add :requires_mfa, :boolean, null: false, default: false
      add :owner_id, references(:users, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:applications, [:slug])
    create index(:applications, [:owner_id])

    create constraint(:applications, :applications_risk_level_check,
             check: "risk_level in ('low', 'medium', 'high')"
           )

    create constraint(:applications, :applications_slug_format_check,
             check: "slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'"
           )

    create table(:access_requests) do
      add :reason, :text, null: false
      add :denial_reason, :text
      add :status, :string, null: false
      add :expires_at, :utc_datetime
      add :reviewed_at, :utc_datetime
      add :request_token, :uuid, null: false
      add :lock_version, :integer, null: false, default: 1

      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :application_id, references(:applications, on_delete: :delete_all), null: false
      add :reviewed_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:access_requests, [:request_token])
    create index(:access_requests, [:user_id, :application_id, :status])
    create index(:access_requests, [:reviewed_by_id])
    create index(:access_requests, [:status, :inserted_at])
    create index(:access_requests, [:application_id, :status])

    create unique_index(:access_requests, [:user_id, :application_id],
             where: "status in ('pending','approved','provisioning')",
             name: :access_requests_one_open_per_user_app_idx
           )

    create constraint(:access_requests, :access_requests_status_check,
             check:
               "status in ('pending','approved','denied','provisioning','provisioned','failed')"
           )

    create constraint(:access_requests, :access_requests_reviewed_fields_check,
             check:
               "(status in ('approved','denied') AND reviewed_by_id is not null AND reviewed_at is not null) OR (status not in ('approved','denied'))"
           )

    create constraint(:access_requests, :access_requests_denial_reason_check,
             check:
               "(status = 'denied' AND denial_reason is not null) OR (status <> 'denied' AND denial_reason is null)"
           )

    create table(:access_grants) do
      add :status, :string, null: false
      add :external_ref, :string
      add :granted_at, :utc_datetime
      add :revoked_at, :utc_datetime
      add :lock_version, :integer, null: false, default: 1

      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :application_id, references(:applications, on_delete: :delete_all), null: false
      add :granted_by_id, references(:users, on_delete: :nilify_all), null: false
      add :access_request_id, references(:access_requests, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:access_grants, [:user_id, :application_id, :status])
    create index(:access_grants, [:application_id, :status])
    create unique_index(:access_grants, [:access_request_id])

    create unique_index(:access_grants, [:user_id, :application_id],
             where: "status = 'active'",
             name: :access_grants_one_active_per_user_app_idx
           )

    create constraint(:access_grants, :access_grants_status_check,
             check: "status in ('active','revoking','revoked','failed')"
           )

    create constraint(:access_grants, :access_grants_time_consistency_check,
             check:
               "(status in ('active','failed') AND revoked_at is null) OR (status in ('revoking','revoked'))"
           )

    create table(:audit_events) do
      add :action, :string, null: false
      add :entity_type, :string, null: false
      add :entity_id, :bigint, null: false
      add :metadata, :map, null: false, default: %{}
      add :occurred_at, :utc_datetime, null: false

      add :actor_id, references(:users, on_delete: :nilify_all), null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:audit_events, [:actor_id])
    create index(:audit_events, [:entity_type, :entity_id])
    create index(:audit_events, [:action])
    create index(:audit_events, [:occurred_at])
  end
end
