defmodule NetaudioWeb.DeviceLive.Index do
  use NetaudioWeb, :live_view

  import NetaudioWeb.CoreComponents

  alias Netaudio.Dante.Browser

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(5000, self(), :refresh)

    {:ok, devices} = Browser.get_devices()

    socket =
      socket
      |> assign(:devices, devices)
      |> assign(:current_path, "/devices")

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, :current_path, URI.parse(uri).path)}
  end

  @impl true
  def handle_event("discover", _params, socket) do
    {:ok, devices} = Browser.discover()

    socket =
      socket
      |> assign(:devices, devices)
      |> put_flash(:info, "Discovered #{map_size(devices)} device(s)")

    {:noreply, socket}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:ok, devices} = Browser.refresh_devices()
    {:noreply, assign(socket, :devices, devices)}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:ok, devices} = Browser.get_devices()
    {:noreply, assign(socket, :devices, devices)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Devices
      <:actions>
        <.button phx-click="refresh" variant={:secondary}>Refresh</.button>
        <.button phx-click="discover" variant={:primary}>Discover</.button>
      </:actions>
    </.header>

    <%= if map_size(@devices) == 0 do %>
      <.card>
        <div class="p-12 text-center">
          <p class="text-gray-400 mb-4">No Dante devices found on the network.</p>
          <.button phx-click="discover" variant={:primary}>Scan Network</.button>
        </div>
      </.card>
    <% else %>
      <.table id="devices" rows={Enum.map(@devices, fn {_k, v} -> v end)}>
        <:col :let={device} label="Name">
          <a href={"/devices/#{device.server_name}"} class="text-indigo-400 hover:text-indigo-300">
            <%= device.name || device.server_name %>
          </a>
        </:col>
        <:col :let={device} label="IP Address">
          <%= device.ipv4 %>
        </:col>
        <:col :let={device} label="Model">
          <%= device.model || "-" %>
        </:col>
        <:col :let={device} label="Manufacturer">
          <%= device.manufacturer || "-" %>
        </:col>
        <:col :let={device} label="Sample Rate">
          <%= if device.sample_rate, do: "#{div(device.sample_rate, 1000)} kHz", else: "-" %>
        </:col>
        <:col :let={device} label="TX / RX">
          <%= map_size(device.tx_channels) %> / <%= map_size(device.rx_channels) %>
        </:col>
        <:col :let={device} label="Subscriptions">
          <%= length(device.subscriptions) %>
        </:col>
      </.table>
    <% end %>
    """
  end
end
