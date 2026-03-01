import Config

config :netaudio, NetaudioWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_only_secret_key_base_that_is_at_least_64_bytes_long_for_phoenix_to_accept_it",
  server: false

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime

config :netaudio, Netaudio.Dante.Browser,
  mdns_timeout: 0.5
