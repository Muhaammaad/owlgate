defmodule OwlGate.Audit.RequestContext do
  @moduledoc """
  Request-scoped metadata (client IP, user agent) merged into `OwlGate.Audit.log/5`
  when set by `OwlGateWeb.Plugs.AuditRequestContext`.
  """

  @key {:owlgate, :audit_request_context}

  @doc """
  Stores context for the current process and clears it on `conn` completion.
  """
  def attach(%Plug.Conn{} = conn) do
    meta = build_meta(conn)
    Process.put(@key, meta)

    Plug.Conn.register_before_send(conn, fn c ->
      Process.delete(@key)
      c
    end)
  end

  @doc false
  def peek do
    Process.get(@key)
  end

  defp build_meta(conn) do
    %{"client_ip" => format_ip(conn.remote_ip), "user_agent" => user_agent(conn)}
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp format_ip(ip) when tuple_size(ip) == 4 or tuple_size(ip) == 8 do
    ip |> :inet.ntoa() |> List.to_string()
  end

  defp format_ip(_), do: nil

  defp user_agent(conn) do
    case Plug.Conn.get_req_header(conn, "user-agent") do
      [h | _] -> String.slice(h, 0, 500)
      _ -> nil
    end
  end
end
