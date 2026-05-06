defmodule OwlGateWeb.LocaleController do
  use OwlGateWeb, :controller

  alias OwlGateWeb.Gettext

  @session_key "locale"

  def switch(conn, %{"locale" => locale}) do
    locale =
      if locale in Gettext.supported_locales() do
        locale
      else
        Gettext.default_locale()
      end

    conn
    |> put_session(@session_key, locale)
    |> redirect(to: return_to(conn))
  end

  defp return_to(conn) do
    case get_req_header(conn, "referer") do
      [url | _] ->
        %URI{path: path, query: query} = URI.parse(url)

        case {path, query} do
          {nil, _} -> ~p"/"
          {path, nil} -> path
          {path, query} -> path <> "?" <> query
        end

      _ ->
        ~p"/"
    end
  end
end
