import Config

config :netaudio,
  generators: [timestamp_type: :utc_datetime]

config :netaudio, NetaudioWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [html: NetaudioWeb.ErrorHTML, json: NetaudioWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Netaudio.PubSub,
  live_view: [signing_salt: "dante_netaudio"]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

# Dante Director / DDM Managed API configuration
# Set these to connect to your Dante Director instance.
# API keys are generated in Director: Settings > API Keys
config :netaudio, Netaudio.Director.Client,
  endpoint: System.get_env("DANTE_DIRECTOR_ENDPOINT"),
  api_key: System.get_env("DANTE_DIRECTOR_API_KEY")

import_config "#{config_env()}.exs"
