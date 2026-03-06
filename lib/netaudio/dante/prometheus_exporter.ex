defmodule Netaudio.Dante.PrometheusExporter do
  @moduledoc """
  Periodically polls Dante device state from the Browser GenServer and
  emits Telemetry events that are scraped as Prometheus metrics via the
  /metrics HTTP endpoint.
  """

  use GenServer
  require Logger

  alias Netaudio.Dante.Browser

  @default_poll_interval 30_000

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    poll_interval =
      Keyword.get(opts, :poll_interval) ||
        Application.get_env(:netaudio, __MODULE__, [])
        |> Keyword.get(:poll_interval, @default_poll_interval)

    schedule_poll(poll_interval)

    {:ok, %{poll_interval: poll_interval, last_poll_duration_ms: nil, poll_errors: 0}}
  end

  @impl true
  def handle_info(:poll, state) do
    state = do_poll(state)
    schedule_poll(state.poll_interval)
    {:noreply, state}
  end

  # Private

  defp schedule_poll(interval) do
    Process.send_after(self(), :poll, interval)
  end

  defp do_poll(state) do
    start = System.monotonic_time(:millisecond)

    try do
      {:ok, devices} = Browser.get_devices()

      device_count = map_size(devices)

      :telemetry.execute(
        [:dante, :exporter, :devices_discovered],
        %{count: device_count},
        %{}
      )

      Enum.each(devices, fn {_key, device} ->
        name = device.name || device.server_name
        labels = %{device: name}

        # Device info event
        :telemetry.execute(
          [:dante, :device, :info],
          %{value: 1},
          %{
            device: name,
            ipv4: device.ipv4 || "",
            manufacturer: device.manufacturer || "",
            model: device.model || "",
            dante_model: device.dante_model || "",
            mac_address: device.mac_address || "",
            software: device.software || ""
          }
        )

        # Latency
        if device.latency do
          :telemetry.execute(
            [:dante, :device, :latency_ns],
            %{value: device.latency},
            labels
          )
        end

        # Sample rate
        if device.sample_rate do
          :telemetry.execute(
            [:dante, :device, :sample_rate_hz],
            %{value: device.sample_rate},
            labels
          )
        end

        # Channel counts
        :telemetry.execute(
          [:dante, :device, :tx_channel_count],
          %{value: device.tx_count || 0},
          labels
        )

        :telemetry.execute(
          [:dante, :device, :rx_channel_count],
          %{value: device.rx_count || 0},
          labels
        )
      end)

      duration = System.monotonic_time(:millisecond) - start

      :telemetry.execute(
        [:dante, :exporter, :poll_duration],
        %{duration_ms: duration},
        %{}
      )

      %{state | last_poll_duration_ms: duration}
    rescue
      e ->
        Logger.error("Prometheus exporter poll failed: #{inspect(e)}")

        :telemetry.execute(
          [:dante, :exporter, :poll_error],
          %{count: 1},
          %{}
        )

        %{state | poll_errors: state.poll_errors + 1}
    end
  end
end
