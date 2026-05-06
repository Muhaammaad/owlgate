defmodule OwlGateWeb.Api.Params do
  @moduledoc false

  @doc "Parses a positive integer path segment or query value for API routes."
  @spec parse_path_id(term()) :: {:ok, pos_integer()} | :error
  def parse_path_id(id) when is_integer(id) and id > 0, do: {:ok, id}

  def parse_path_id(bin) when is_binary(bin) do
    case Integer.parse(bin) do
      {n, ""} when n > 0 -> {:ok, n}
      _ -> :error
    end
  end

  def parse_path_id(_), do: :error
end
