import Config

config :netaudio, NetaudioWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "dev_only_secret_key_base_that_is_at_least_64_bytes_long_for_phoenix_to_accept_it",
  watchers: []

config :netaudio, dev_routes: true

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20

config :phoenix, :plug_init_mode, :runtime

config :netaudio, Netaudio.Dante.Browser,
  mdns_timeout: 3.0
