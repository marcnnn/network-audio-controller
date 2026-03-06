defmodule NetaudioWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000},
      {TelemetryMetricsPrometheus.Core, metrics: prometheus_metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.live_view.mount.stop.duration",
        tags: [:view],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.live_view.handle_event.stop.duration",
        tags: [:view, :event],
        unit: {:native, :millisecond}
      )
    ]
  end

  defp prometheus_metrics do
    [
      # Device-level metrics
      last_value("dante.device.info.value",
        tags: [:device, :ipv4, :manufacturer, :model, :dante_model, :mac_address, :software],
        description: "Dante device information (always 1)"
      ),
      last_value("dante.device.latency_ns.value",
        tags: [:device],
        description: "Configured receive latency in nanoseconds"
      ),
      last_value("dante.device.sample_rate_hz.value",
        tags: [:device],
        description: "Current sample rate in Hz"
      ),
      last_value("dante.device.tx_channel_count.value",
        tags: [:device],
        description: "Number of transmit channels"
      ),
      last_value("dante.device.rx_channel_count.value",
        tags: [:device],
        description: "Number of receive channels"
      ),

      # Exporter health metrics
      last_value("dante.exporter.devices_discovered.count",
        description: "Number of devices found in last poll"
      ),
      last_value("dante.exporter.poll_duration.duration_ms",
        description: "Duration of last poll cycle in milliseconds"
      ),
      sum("dante.exporter.poll_error.count",
        description: "Number of poll errors encountered"
      )
    ]
  end

  defp periodic_measurements do
    []
  end
end
