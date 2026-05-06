defmodule OwlGateWeb.Live.StatusFilter do
  @moduledoc "Parses `<select>` status values against an allowed atom list."
  use Gettext, backend: OwlGateWeb.Gettext

  @type status_atom :: atom()

  @spec parse(String.t() | nil, [status_atom()]) ::
          {:ok, status_atom() | nil} | {:error, String.t()}
  def parse(nil, _allowed), do: {:ok, nil}

  def parse(raw, allowed) when is_binary(raw) do
    raw = String.trim(raw)

    if raw == "" do
      {:ok, nil}
    else
      case Enum.find(allowed, &(Atom.to_string(&1) == raw)) do
        nil -> {:error, gettext("Invalid status filter.")}
        atom -> {:ok, atom}
      end
    end
  end

  def parse(_, _allowed), do: {:ok, nil}

  @doc """
  Updates `filter_key` from the raw param and clears or sets `error_key` when provided.
  """
  def put_filter(socket, raw, allowed, opts) do
    filter_key = Keyword.fetch!(opts, :filter_key)
    error_key = Keyword.get(opts, :error_key)

    case parse(raw, allowed) do
      {:ok, status} ->
        socket
        |> Phoenix.Component.assign(filter_key, status)
        |> maybe_clear_error(error_key)

      {:error, msg} ->
        maybe_put_error(socket, error_key, msg)
    end
  end

  defp maybe_clear_error(socket, nil), do: socket

  defp maybe_clear_error(socket, key) do
    Phoenix.Component.assign(socket, key, nil)
  end

  defp maybe_put_error(socket, nil, _msg), do: socket

  defp maybe_put_error(socket, key, msg) do
    Phoenix.Component.assign(socket, key, msg)
  end
end
