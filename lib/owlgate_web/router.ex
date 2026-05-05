defmodule OwlGateWeb.Router do
  use OwlGateWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OwlGateWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug OwlGateWeb.Plugs.AssignCurrentUser
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", OwlGateWeb do
    pipe_through :browser

    get "/", PageController, :home

    live_session :operator do
      live "/dashboard", DashboardLive
      live "/access-requests", AccessRequestLive.Index
      live "/access-requests/:id", AccessRequestLive.Show
    end
  end

  if Application.compile_env(:owlgate, :dev_routes, false) do
    scope "/dev", OwlGateWeb do
      pipe_through :browser

      get "/session", DevSessionController, :new
      post "/session", DevSessionController, :create
      delete "/session", DevSessionController, :delete
    end

    # Enable LiveDashboard and Swoosh mailbox preview in development
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: OwlGateWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
