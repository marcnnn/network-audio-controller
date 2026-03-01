defmodule NetaudioWeb.Router do
  use NetaudioWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {NetaudioWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", NetaudioWeb do
    pipe_through :browser

    live "/", DashboardLive, :index
    live "/routing", RoutingMatrixLive, :index
    live "/devices", DeviceLive.Index, :index
    live "/devices/:id", DeviceLive.Show, :show
    live "/channels", ChannelLive.Index, :index
    live "/subscriptions", SubscriptionLive.Index, :index
    live "/subscriptions/new", SubscriptionLive.New, :new

    # Director (DDM Managed API)
    live "/director/settings", DirectorLive.Settings, :index
    live "/director/domains", DirectorLive.Domains, :index
    live "/director/domains/:id", DirectorLive.DomainDetail, :show
  end

  scope "/api", NetaudioWeb.Api do
    pipe_through :api

    get "/devices", DeviceController, :index
    get "/devices/:id", DeviceController, :show
    post "/devices/discover", DeviceController, :discover
    post "/devices/:id/identify", DeviceController, :identify

    get "/channels", ChannelController, :index

    get "/subscriptions", SubscriptionController, :index
    post "/subscriptions", SubscriptionController, :create
    delete "/subscriptions/:id", SubscriptionController, :delete

    # Director (DDM Managed API)
    get "/director/status", DirectorController, :status
    get "/director/domains", DirectorController, :list_domains
    get "/director/domains/:id", DirectorController, :get_domain
    get "/director/domains/:id/routing", DirectorController, :get_routing
    get "/director/domains/:id/clocking", DirectorController, :get_clocking
    get "/director/domains/:domain_id/devices/:device_id", DirectorController, :get_device
    get "/director/unenrolled", DirectorController, :list_unenrolled
    post "/director/subscriptions", DirectorController, :set_subscriptions
    delete "/director/subscriptions", DirectorController, :clear_subscription
    post "/director/enrol", DirectorController, :enrol_devices
    post "/director/unenrol", DirectorController, :unenrol_devices
    post "/director/graphql", DirectorController, :graphql
  end

  if Application.compile_env(:netaudio, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: NetaudioWeb.Telemetry
    end
  end
end
