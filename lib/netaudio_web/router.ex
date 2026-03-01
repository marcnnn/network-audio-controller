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
    live "/devices", DeviceLive.Index, :index
    live "/devices/:id", DeviceLive.Show, :show
    live "/channels", ChannelLive.Index, :index
    live "/subscriptions", SubscriptionLive.Index, :index
    live "/subscriptions/new", SubscriptionLive.New, :new
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
  end

  if Application.compile_env(:netaudio, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: NetaudioWeb.Telemetry
    end
  end
end
