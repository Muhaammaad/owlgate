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
    plug :fetch_session
    plug OwlGateWeb.Plugs.AssignCurrentUser
  end

  pipeline :api_authenticated do
    plug OwlGateWeb.Plugs.RequireAuthenticatedJson
  end

  pipeline :api_reviewer do
    plug OwlGateWeb.Plugs.RequireAuthenticatedJson
    plug OwlGateWeb.Plugs.RequireReviewerJson
  end

  scope "/", OwlGateWeb do
    pipe_through :browser

    get "/", PageController, :home

    get "/login", UserSessionController, :new
    post "/login", UserSessionController, :create
    delete "/logout", UserSessionController, :delete

    get "/register", UserRegistrationController, :new
    post "/register", UserRegistrationController, :create

    live_session :operator,
      on_mount: [{OwlGateWeb.Live.Auth, :require_authenticated_user}] do
      live "/dashboard", DashboardLive
      live "/access-requests", AccessRequestLive.Index
      live "/access-requests/:id", AccessRequestLive.Show
      live "/grants", GrantLive.Index
      live "/audit-events", AuditLive.Index
    end
  end

  scope "/admin", OwlGateWeb.Admin, as: :admin do
    pipe_through :browser

    live_session :admin,
      on_mount: [{OwlGateWeb.Live.Auth, :require_admin}] do
      live "/users", UserLive.Index
      live "/users/new", UserLive.Form, :new
      live "/users/:id/edit", UserLive.Form, :edit
      live "/applications", ApplicationLive.Index
      live "/applications/new", ApplicationLive.Form, :new
      live "/applications/:id/edit", ApplicationLive.Form, :edit
    end
  end

  scope "/api", OwlGateWeb.Api do
    pipe_through [:api, :api_authenticated]

    post "/access-requests", AccessRequestController, :create
    get "/audit-events", AuditEventController, :index
  end

  scope "/api", OwlGateWeb.Api do
    pipe_through [:api, :api_reviewer]

    post "/access-requests/:id/approve", AccessRequestController, :approve
    post "/access-requests/:id/deny", AccessRequestController, :deny
    post "/access-grants/:id/revoke", AccessGrantController, :revoke
  end

  if Application.compile_env(:owlgate, :dev_routes, false) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: OwlGateWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
