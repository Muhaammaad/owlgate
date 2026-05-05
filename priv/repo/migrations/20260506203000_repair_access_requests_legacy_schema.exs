defmodule OwlGate.Repo.Migrations.RepairAccessRequestsLegacySchema do
  use Ecto.Migration

  @doc """
  Aligns `access_requests` with the current app schema.

  Older dev databases may have applied an earlier revision of
  `create_owlgate_core_tables` (missing `denial_reason`, wrong status CHECK,
  missing partial unique index). This migration is safe to run on fresh DBs too:
  it drops and recreates matching constraints and indexes.
  """

  def up do
    execute "ALTER TABLE access_requests ADD COLUMN IF NOT EXISTS denial_reason text"

    drop_if_exists constraint(:access_requests, :access_requests_status_check)

    create constraint(:access_requests, :access_requests_status_check,
             check:
               "status in ('pending','approved','denied','provisioning','provisioned','failed')"
           )

    drop_if_exists constraint(:access_requests, :access_requests_reviewed_fields_check)

    create constraint(:access_requests, :access_requests_reviewed_fields_check,
             check:
               "(status in ('approved','denied') AND reviewed_by_id is not null AND reviewed_at is not null) OR (status not in ('approved','denied'))"
           )

    drop_if_exists constraint(:access_requests, :access_requests_denial_reason_check)

    create constraint(:access_requests, :access_requests_denial_reason_check,
             check:
               "(status = 'denied' AND denial_reason is not null) OR (status <> 'denied' AND denial_reason is null)"
           )

    drop_if_exists(
      index(:access_requests, [:user_id, :application_id],
        name: :access_requests_one_open_per_user_app_idx
      )
    )

    create unique_index(:access_requests, [:user_id, :application_id],
             where: "status in ('pending','approved','provisioning')",
             name: :access_requests_one_open_per_user_app_idx
           )

    create_if_not_exists index(:access_requests, [:application_id, :status])
  end

  def down do
    raise Ecto.MigrationError,
          "irreversible: legacy repair; use ecto.dump or restore backup if you must roll back"
  end
end
