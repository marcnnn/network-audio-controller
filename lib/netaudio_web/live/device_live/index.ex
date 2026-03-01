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
        <button class="btn btn-ghost btn-sm" phx-click="refresh">Refresh</button>
        <button class="btn btn-primary btn-sm" phx-click="discover">Discover</button>
      </:actions>
    </.header>

    <%= if map_size(@devices) == 0 do %>
      <.empty_state>
        No Dante devices found on the network.
        <:action>
          <button class="btn btn-primary btn-sm" phx-click="discover">Scan Network</button>
        </:action>
      </.empty_state>
    <% else %>
      <div class="overflow-x-auto rounded-box border border-base-300 bg-base-200">
        <table class="table table-sm">
          <thead>
            <tr class="border-b border-base-300">
              <th class="text-xs uppercase tracking-wider text-base-content/60">Name</th>
              <th class="text-xs uppercase tracking-wider text-base-content/60">IP Address</th>
              <th class="text-xs uppercase tracking-wider text-base-content/60">Model</th>
              <th class="text-xs uppercase tracking-wider text-base-content/60">Sample Rate</th>
              <th class="text-xs uppercase tracking-wider text-base-content/60">Channels</th>
              <th class="text-xs uppercase tracking-wider text-base-content/60">Subscriptions</th>
            </tr>
          </thead>
          <tbody>
            <%= for {_k, device} <- Enum.sort_by(@devices, fn {_k, d} -> d.name end) do %>
              <tr class="hover">
                <td>
                  <a href={"/devices/#{device.server_name}"} class="link link-primary font-medium">
                    <%= device.name || device.server_name %>
                  </a>
                </td>
                <td class="font-mono text-xs"><%= device.ipv4 %></td>
                <td><%= device.model || "-" %></td>
                <td>
                  <%= if device.sample_rate, do: "#{div(device.sample_rate, 1000)} kHz", else: "-" %>
                </td>
                <td>
                  <div class="flex gap-1">
                    <span class="badge badge-sm badge-accent badge-outline">TX: <%= map_size(device.tx_channels) %></span>
                    <span class="badge badge-sm badge-info badge-outline">RX: <%= map_size(device.rx_channels) %></span>
                  </div>
                </td>
                <td>
                  <span class="badge badge-sm badge-ghost"><%= length(device.subscriptions) %></span>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    <% end %>
    """
  end
end
