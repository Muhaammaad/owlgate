defmodule OwlGateWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use OwlGateWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  attr :current_user, :any, default: nil, doc: "signed-in user for operator navigation links"

  def layouts_main_nav(assigns) do
    ~H"""
    <header class="navbar border-b border-base-300 bg-base-100 min-h-14 px-3 sm:px-6 lg:px-8 gap-2 justify-between">
      <div class="navbar-start flex-1 min-w-0 flex flex-wrap items-center gap-x-1 gap-y-2 lg:gap-x-2">
        <%= if @current_user do %>
          <div class="dropdown dropdown-bottom dropdown-start lg:hidden">
            <div tabindex="0" role="button" class="btn btn-ghost btn-square" aria-label="Open menu">
              <.icon name="hero-bars-3" class="size-6" />
            </div>
            <ul
              tabindex="0"
              class="dropdown-content menu menu-sm z-[100] mt-2 w-56 rounded-box border border-base-300 bg-base-100 p-2 shadow-lg"
            >
              <li>
                <.link navigate={~p"/dashboard"} class="justify-between">
                  {gettext("Dashboard")}
                </.link>
              </li>
              <li>
                <.link navigate={~p"/access-requests"} class="justify-between">
                  {gettext("Requests")}
                </.link>
              </li>
              <li>
                <.link navigate={~p"/grants"} class="justify-between">{gettext("Grants")}</.link>
              </li>
              <li>
                <.link navigate={~p"/audit-events"} class="justify-between">{gettext("Audit")}</.link>
              </li>
              <%= if OwlGate.Policy.AdminPolicy.admin?(@current_user) do %>
                <li>
                  <.link navigate={~p"/admin/users"} class="justify-between">
                    {gettext("Users")}
                  </.link>
                </li>
                <li>
                  <.link navigate={~p"/admin/applications"} class="justify-between">
                    {gettext("Apps")}
                  </.link>
                </li>
              <% end %>
              <li>
                <form action={~p"/logout"} method="post" class="w-full">
                  <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
                  <input type="hidden" name="_method" value="delete" />
                  <button type="submit" class="btn btn-outline btn-sm w-full">
                    {gettext("Sign out")}
                  </button>
                </form>
              </li>
            </ul>
          </div>
        <% end %>
        <a href="/" class="btn btn-ghost btn-sm gap-2 px-2 normal-case min-h-10 shrink-0">
          <img src={~p"/images/logo.svg"} width="32" height="32" class="shrink-0" alt="" />
          <span class="text-sm font-semibold truncate">OwlGate</span>
        </a>

        <%= if @current_user do %>
          <nav
            class="hidden lg:flex flex-row flex-wrap items-center gap-1 pl-1 border-l border-base-300/60 ml-1"
            aria-label="Main"
          >
            <.link navigate={~p"/dashboard"} class="btn btn-ghost btn-sm">
              {gettext("Dashboard")}
            </.link>
            <.link navigate={~p"/access-requests"} class="btn btn-ghost btn-sm">
              {gettext("Requests")}
            </.link>
            <.link navigate={~p"/grants"} class="btn btn-ghost btn-sm">{gettext("Grants")}</.link>
            <.link navigate={~p"/audit-events"} class="btn btn-ghost btn-sm">
              {gettext("Audit")}
            </.link>
            <%= if OwlGate.Policy.AdminPolicy.admin?(@current_user) do %>
              <.link navigate={~p"/admin/users"} class="btn btn-ghost btn-sm">
                {gettext("Users")}
              </.link>
              <.link navigate={~p"/admin/applications"} class="btn btn-ghost btn-sm">
                {gettext("Apps")}
              </.link>
            <% end %>
          </nav>
        <% end %>
      </div>

      <div class="navbar-end flex-none gap-2 shrink-0">
        <.locale_switcher />
        <%= if @current_user do %>
          <form action={~p"/logout"} method="post" class="hidden lg:block">
            <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
            <input type="hidden" name="_method" value="delete" />
            <button type="submit" class="btn btn-outline btn-sm">{gettext("Sign out")}</button>
          </form>
        <% end %>
        <.theme_toggle />
      </div>
    </header>
    """
  end

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :current_user, :any, default: nil, doc: "signed-in user for operator navigation"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <.layouts_main_nav current_user={@current_user} />

    <main class="px-4 py-10 sm:py-14 sm:px-6 lg:px-8 lg:py-16">
      <div class="mx-auto max-w-4xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end

  def locale_switcher(assigns) do
    ~H"""
    <div class="join">
      <.link navigate={~p"/locale/en"} class="btn btn-xs join-item">EN</.link>
      <.link navigate={~p"/locale/de"} class="btn btn-xs join-item">DE</.link>
    </div>
    """
  end
end
