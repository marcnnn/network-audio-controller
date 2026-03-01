defmodule Netaudio.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      NetaudioWeb.Telemetry,
      {Phoenix.PubSub, name: Netaudio.PubSub},
      Netaudio.Dante.Browser,
      NetaudioWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Netaudio.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    NetaudioWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
