defmodule OwlGateWeb.Plugs.AuditRequestContext do
  @moduledoc """
  Captures HTTP metadata for the current request into process storage so
  `OwlGate.Audit.log/5` can attach `client_ip` and `user_agent`.
  """

  def init(opts), do: opts

  def call(conn, _opts), do: OwlGate.Audit.RequestContext.attach(conn)
end
