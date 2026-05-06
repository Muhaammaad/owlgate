defmodule OwlGateWeb.Plugs.RateLimitApi do
  @moduledoc """
  IP-based fixed-window rate limiting via Hammer (see config `:hammer`).

  Applied only to routes that opt in (e.g. access request creation).
  """

  import Plug.Conn

  @default_limit 60
  @default_scale_ms 60_000

  def init(opts) do
    limit = Keyword.get(opts, :limit, @default_limit)
    scale_ms = Keyword.get(opts, :scale_ms, @default_scale_ms)
    prefix = Keyword.get(opts, :id_prefix, "api_access_request_create")

    %{limit: limit, scale_ms: scale_ms, prefix: prefix}
  end

  def call(conn, opts) do
    ip =
      conn.remote_ip
      |> :inet.ntoa()
      |> List.to_string()

    id = "#{opts.prefix}:#{ip}"

    case Hammer.check_rate(id, opts.scale_ms, opts.limit) do
      {:allow, _} ->
        conn

      {:deny, _} ->
        retry_after = max(1, div(opts.scale_ms, 1000))

        body =
          Jason.encode!(%{
            error: "rate_limited",
            retry_after_seconds: retry_after
          })

        conn
        |> put_resp_header("retry-after", Integer.to_string(retry_after))
        |> put_resp_content_type("application/json")
        |> send_resp(429, body)
        |> halt()
    end
  end
end
