defmodule NetaudioWeb.DashboardLive do
  use NetaudioWeb, :live_view

  import NetaudioWeb.CoreComponents

  alias Netaudio.Dante.{Browser, Constants}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(5000, self(), :refresh)

    {:ok, devices} = Browser.get_devices()

    socket =
      socket
      |> assign(:devices, devices)
      |> assign(:discovering, false)
      |> assign(:current_path, "/")
      |> compute_stats()

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, :current_path, URI.parse(uri).path)}
  end

  @impl true
  def handle_event("discover", _params, socket) do
    socket = assign(socket, :discovering, true)
    send(self(), :do_discover)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:do_discover, socket) do
    {:ok, devices} = Browser.discover()

    socket =
      socket
      |> assign(:devices, devices)
      |> assign(:discovering, false)
      |> compute_stats()
      |> put_flash(:info, "Discovery complete. Found #{map_size(devices)} device(s).")

    {:noreply, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:ok, devices} = Browser.get_devices()

    socket =
      socket
      |> assign(:devices, devices)
      |> compute_stats()

    {:noreply, socket}
  end

  defp compute_stats(socket) do
    devices = socket.assigns.devices
    device_count = map_size(devices)

    {tx_count, rx_count, sub_count, active_sub_count} =
      Enum.reduce(devices, {0, 0, 0, 0}, fn {_key, device}, {tx, rx, subs, active} ->
        active_subs =
          device.subscriptions
          |> Enum.count(fn sub ->
            sub.status_code in [
              Constants.subscription_status(:dynamic),
              Constants.subscription_status(:static),
              Constants.subscription_status(:manual),
              Constants.subscription_status(:subscribe_self)
            ]
          end)

        {
          tx + map_size(device.tx_channels),
          rx + map_size(device.rx_channels),
          subs + length(device.subscriptions),
          active + active_subs
        }
      end)

    socket
    |> assign(:device_count, device_count)
    |> assign(:tx_channel_count, tx_count)
    |> assign(:rx_channel_count, rx_count)
    |> assign(:subscription_count, sub_count)
    |> assign(:active_subscription_count, active_sub_count)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Dashboard
      <:actions>
        <.button phx-click="discover" variant={:primary}>
          <%= if @discovering, do: "Discovering...", else: "Discover Devices" %>
        </.button>
      </:actions>
    </.header>

    <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-5 mb-8">
      <.stat_card label="Devices" value={@device_count} />
      <.stat_card label="TX Channels" value={@tx_channel_count} />
      <.stat_card label="RX Channels" value={@rx_channel_count} />
      <.stat_card label="Subscriptions" value={@subscription_count} />
      <.stat_card label="Active" value={@active_subscription_count} />
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <.card>
        <div class="px-6 py-4 border-b border-gray-700">
          <h3 class="text-lg font-medium text-white">Devices</h3>
        </div>
        <div class="p-6">
          <%= if map_size(@devices) == 0 do %>
            <p class="text-gray-400 text-sm">No devices discovered. Click "Discover Devices" to scan the network.</p>
          <% else %>
            <ul class="space-y-3">
              <%= for {_key, device} <- @devices do %>
                <li class="flex items-center justify-between p-3 bg-gray-700/50 rounded-lg">
                  <div>
                    <p class="font-medium text-white"><%= device.name || device.server_name %></p>
                    <p class="text-xs text-gray-400"><%= device.ipv4 %></p>
                  </div>
                  <div class="text-right text-xs text-gray-400">
                    <p>TX: <%= map_size(device.tx_channels) %> | RX: <%= map_size(device.rx_channels) %></p>
                    <%= if device.sample_rate do %>
                      <p><%= div(device.sample_rate, 1000) %> kHz</p>
                    <% end %>
                  </div>
                </li>
              <% end %>
            </ul>
          <% end %>
        </div>
      </.card>

      <.card>
        <div class="px-6 py-4 border-b border-gray-700">
          <h3 class="text-lg font-medium text-white">Active Subscriptions</h3>
        </div>
        <div class="p-6">
          <% active_subs = Enum.flat_map(@devices, fn {_k, d} ->
            Enum.filter(d.subscriptions, fn s ->
              s.status_code in [9, 10, 14, 4]
            end)
          end) %>
          <%= if Enum.empty?(active_subs) do %>
            <p class="text-gray-400 text-sm">No active subscriptions.</p>
          <% else %>
            <ul class="space-y-2">
              <%= for sub <- Enum.take(active_subs, 10) do %>
                <li class="p-2 bg-gray-700/50 rounded text-sm">
                  <span class="text-green-400"><%= sub.tx_channel_name %></span>
                  <span class="text-gray-500">@</span>
                  <span class="text-gray-300"><%= sub.tx_device_name %></span>
                  <span class="text-gray-500 mx-1">&rarr;</span>
                  <span class="text-blue-400"><%= sub.rx_channel_name %></span>
                  <span class="text-gray-500">@</span>
                  <span class="text-gray-300"><%= sub.rx_device_name %></span>
                </li>
              <% end %>
              <%= if length(active_subs) > 10 do %>
                <li class="text-gray-400 text-xs text-center">
                  ... and <%= length(active_subs) - 10 %> more
                </li>
              <% end %>
            </ul>
          <% end %>
        </div>
      </.card>
    </div>
    """
  end
end
