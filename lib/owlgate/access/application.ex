defmodule OwlGate.Access.Application do
  @moduledoc """
  Application entity representing a SaaS integration target in OwlGate.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias OwlGate.Accounts.User
  alias OwlGate.Access.AccessRequest

  @risk_levels [:low, :medium, :high]
  @slug_cleanup_regex ~r/[^a-z0-9\-]+/u
  @slug_validation_regex ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/

  schema "applications" do
    field :name, :string
    field :slug, :string
    field :risk_level, Ecto.Enum, values: @risk_levels
    field :active, :boolean, default: true
    field :requires_mfa, :boolean, default: false

    belongs_to :owner, User
    has_many :access_requests, AccessRequest

    timestamps(type: :utc_datetime)
  end

  def changeset(application, attrs) do
    application
    |> cast(attrs, [:name, :slug, :risk_level, :active, :requires_mfa, :owner_id])
    |> validate_required([:name, :slug, :risk_level, :owner_id])
    |> update_change(:slug, &normalize_slug/1)
    |> validate_length(:slug, min: 3)
    |> validate_format(:slug, @slug_validation_regex)
    |> unique_constraint(:slug)
    |> check_constraint(:slug, name: :applications_slug_format_check)
    |> foreign_key_constraint(:owner_id)
  end

  defp normalize_slug(slug) when is_binary(slug),
    do: slug |> String.trim() |> String.downcase() |> String.replace(@slug_cleanup_regex, "-")

  defp normalize_slug(slug), do: slug
end
