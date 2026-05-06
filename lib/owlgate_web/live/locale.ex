defmodule OwlGateWeb.Live.Locale do
  @moduledoc """
  Ensures LiveView process locale follows the browser session locale.
  """

  import Phoenix.Component

  alias OwlGateWeb.Gettext, as: WebGettext

  def on_mount(:default, _params, session, socket) do
    locale = normalize_locale(session["locale"])

    Gettext.put_locale(OwlGateWeb.Gettext, locale)

    {:cont, assign(socket, :locale, locale)}
  end

  defp normalize_locale(locale) when is_binary(locale) do
    if locale in WebGettext.supported_locales(), do: locale, else: WebGettext.default_locale()
  end

  defp normalize_locale(_), do: WebGettext.default_locale()
end
