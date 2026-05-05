defmodule OwlGate.Repo do
  use Ecto.Repo,
    otp_app: :owlgate,
    adapter: Ecto.Adapters.Postgres
end
