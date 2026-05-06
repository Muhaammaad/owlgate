defmodule OwlGateWeb.Plugs.SetLocale do
  @moduledoc """
  Sets gettext locale from query param or session.

  Supported locales are read from `OwlGateWeb.Gettext`.
  """

  import Plug.Conn

  alias OwlGateWeb.Gettext, as: WebGettext

  @session_key "locale"

  def init(opts), do: opts

  def call(conn, _opts) do
    conn = fetch_query_params(conn)

    locale =
      conn.params["locale"]
      |> normalize_locale()
      |> case do
        nil -> get_session(conn, @session_key) |> normalize_locale()
        chosen -> chosen
      end
      |> case do
        nil -> WebGettext.default_locale()
        chosen -> chosen
      end

    Gettext.put_locale(OwlGateWeb.Gettext, locale)

    conn
    |> maybe_store_locale(locale)
    |> assign(:locale, locale)
  end

  defp maybe_store_locale(conn, locale) do
    if get_session(conn, @session_key) == locale do
      conn
    else
      put_session(conn, @session_key, locale)
    end
  end

  defp normalize_locale(locale) when is_binary(locale) do
    locale = String.trim(locale)

    if locale in WebGettext.supported_locales() do
      locale
    else
      nil
    end
  end

  defp normalize_locale(_), do: nil
end
