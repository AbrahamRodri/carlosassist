defmodule CarlosassistWeb.Router do
  use CarlosassistWeb, :router

  import CarlosassistWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CarlosassistWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", CarlosassistWeb do
    pipe_through :browser

    get "/", PageController, :home
    # Uploaded profile pics live outside priv/static (Fly volume in prod)
    get "/uploads/profile_pics/:filename", UploadsController, :profile_pic
  end

  # Other scopes may use custom stacks.
  # scope "/api", CarlosassistWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:carlosassist, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: CarlosassistWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", CarlosassistWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{CarlosassistWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", CarlosassistWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{CarlosassistWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end

  scope "/dashboard", CarlosassistWeb do
    pipe_through [:browser, :require_authenticated_user]

    # Volunteer Dashboard
    live_session :volunteer_dashboard,
      on_mount: [{CarlosassistWeb.UserAuth, :require_volunteer}] do
      live "/volunteer", VolunteerDashboardLive, :show
    end

    # Rider Dashboard
    live_session :rider_dashboard,
      on_mount: [{CarlosassistWeb.UserAuth, :require_rider}] do
      live "/rider", RiderDashboardLive, :show
    end

    # Chat Routes (available to both riders and volunteers)
    live_session :chat,
      on_mount: [{CarlosassistWeb.UserAuth, :require_authenticated}] do
      live "/inbox", InboxLive, :show
      live "/chat/:id", ChatLive, :show
    end
  end
end
