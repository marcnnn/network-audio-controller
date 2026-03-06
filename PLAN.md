# Prometheus Exporter for Clock and Latency Information

## Overview

Adds a Prometheus metrics exporter to the Elixir/Phoenix application that exposes Dante device clock and latency information via a `/metrics` HTTP endpoint scrapeable by Prometheus.

## Architecture

```
┌──────────────────────┐     ┌───────────────────────┐     ┌────────────┐
│  DanteBrowser        │────>│  PrometheusExporter    │────>│ Prometheus │
│  (GenServer, mDNS    │     │  (GenServer, periodic  │     │  scrapes   │
│   device discovery)  │     │   telemetry emitter)   │     │  /metrics  │
└──────────────────────┘     └───────────────────────┘     └────────────┘
                                       │
                                       v
                             ┌───────────────────────┐
                             │  TelemetryMetrics      │
                             │  Prometheus.Core       │
                             │  (aggregates events,   │
                             │   renders text format)  │
                             └───────────────────────┘
                                       │
                                       v
                             ┌───────────────────────┐
                             │  MetricsController     │
                             │  GET /metrics          │
                             └───────────────────────┘
```

## New Dependency

- `telemetry_metrics_prometheus` ~> 1.1 — Prometheus reporter for Telemetry.Metrics (added to `mix.exs`)

## Changes

### New Files

#### `lib/netaudio/dante/prometheus_exporter.ex`

`Netaudio.Dante.PrometheusExporter` — GenServer that periodically polls `Browser.get_devices()` and emits `:telemetry` events for each device's clock/latency data.

- Configurable poll interval via `config :netaudio, Netaudio.Dante.PrometheusExporter, poll_interval: 30_000`
- Emits events: `[:dante, :device, :info]`, `[:dante, :device, :latency_ns]`, `[:dante, :device, :sample_rate_hz]`, `[:dante, :device, :tx_channel_count]`, `[:dante, :device, :rx_channel_count]`
- Emits exporter health events: `[:dante, :exporter, :devices_discovered]`, `[:dante, :exporter, :poll_duration]`, `[:dante, :exporter, :poll_error]`

#### `lib/netaudio_web/controllers/metrics_controller.ex`

`NetaudioWeb.MetricsController` — calls `TelemetryMetricsPrometheus.Core.scrape()` and returns the Prometheus text exposition format.

### Modified Files

#### `mix.exs`

Added `{:telemetry_metrics_prometheus, "~> 1.1"}` dependency.

#### `lib/netaudio/application.ex`

Added `Netaudio.Dante.PrometheusExporter` to the supervision tree (after Browser, before Endpoint).

#### `lib/netaudio_web/telemetry.ex`

- Added `TelemetryMetricsPrometheus.Core` as a child supervisor with Dante-specific metric definitions
- Defined `prometheus_metrics/0` with `last_value` and `sum` metrics for all Dante telemetry events

#### `lib/netaudio_web/router.ex`

Added `GET /metrics` route pointing to `MetricsController.index`.

## Metrics Exposed

All metrics use the prefix `dante_`. Labels identify devices.

### Device-level metrics

| Metric | Type | Labels | Source |
|--------|------|--------|--------|
| `dante_device_info_value` | last_value | `device`, `ipv4`, `manufacturer`, `model`, `dante_model`, `mac_address`, `software` | mDNS properties |
| `dante_device_latency_ns_value` | last_value | `device` | `latency_ns` mDNS property |
| `dante_device_sample_rate_hz_value` | last_value | `device` | `rate` mDNS property / protocol query |
| `dante_device_tx_channel_count_value` | last_value | `device` | Protocol query |
| `dante_device_rx_channel_count_value` | last_value | `device` | Protocol query |

### Exporter health metrics

| Metric | Type | Description |
|--------|------|-------------|
| `dante_exporter_devices_discovered_count` | last_value | Devices found in last poll |
| `dante_exporter_poll_duration_duration_ms` | last_value | Last poll cycle duration (ms) |
| `dante_exporter_poll_error_count` | sum | Total poll errors |

## Usage

The exporter starts automatically with the Phoenix application. Metrics are available at:

```
GET http://localhost:4000/metrics
```

### Prometheus scrape config

```yaml
scrape_configs:
  - job_name: 'dante'
    scrape_interval: 30s
    static_configs:
      - targets: ['localhost:4000']
    metrics_path: '/metrics'
```

### Configuration

```elixir
# config/runtime.exs
config :netaudio, Netaudio.Dante.PrometheusExporter,
  poll_interval: String.to_integer(System.get_env("PROMETHEUS_POLL_INTERVAL") || "30000")
```

## Design Decisions

1. **Telemetry-based** — Uses the standard Elixir Telemetry ecosystem rather than a custom metrics format. This integrates naturally with Phoenix LiveDashboard and any future telemetry consumers.

2. **Reads cached state** — Calls `Browser.get_devices()` (cached) rather than triggering new mDNS discoveries on each poll, avoiding network overhead.

3. **`last_value` gauges** — Device metrics use `last_value` since they represent point-in-time state (current latency, current sample rate). Poll errors use `sum` as a monotonic counter.

4. **No clock master/PTP metrics yet** — The codebase has `MESSAGE_TYPE_CLOCKING_STATUS` and `MESSAGE_TYPE_MASTER_STATUS` constants but parsing is not yet implemented. These can be added as new telemetry events when the protocol parsing is complete.

5. **Single `/metrics` endpoint on main port** — Serves metrics on the same Phoenix port (4000) rather than a separate port, keeping configuration simple.
