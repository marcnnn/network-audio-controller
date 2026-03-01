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

import_config "#{config_env()}.exs"
