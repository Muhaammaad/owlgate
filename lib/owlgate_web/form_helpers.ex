defmodule OwlGateWeb.FormHelpers do
  @moduledoc "Shared form / changeset helpers for LiveViews."

  @doc """
  Flattens a changeset into a single human-readable string for inline errors.
  """
  @spec format_changeset_errors(Ecto.Changeset.t()) :: String.t()
  def format_changeset_errors(cs) do
    Ecto.Changeset.traverse_errors(cs, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map_join("; ", fn {field, errs} ->
      "#{field}: #{Enum.join(errs, ", ")}"
    end)
  rescue
    ArgumentError ->
      inspect(cs.errors)
  end
end
