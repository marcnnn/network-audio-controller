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
        <button
          phx-click="discover"
          class={"btn btn-primary btn-sm gap-2 #{if @discovering, do: "loading animate-pulse-ring"}"}>
          <%= if @discovering do %>
            <span class="loading loading-spinner loading-xs"></span>
            Scanning...
          <% else %>
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M4 2a1 1 0 011 1v2.101a7.002 7.002 0 0111.601 2.566 1 1 0 11-1.885.666A5.002 5.002 0 005.999 7H9a1 1 0 010 2H4a1 1 0 01-1-1V3a1 1 0 011-1zm.008 9.057a1 1 0 011.276.61A5.002 5.002 0 0014.001 13H11a1 1 0 110-2h5a1 1 0 011 1v5a1 1 0 11-2 0v-2.101a7.002 7.002 0 01-11.601-2.566 1 1 0 01.61-1.276z" clip-rule="evenodd" />
            </svg>
            Discover Devices
          <% end %>
        </button>
      </:actions>
    </.header>

    <%!-- Stats row --%>
    <div class="stats stats-vertical sm:stats-horizontal shadow bg-base-200 w-full mb-6 border border-base-300">
      <.stat_card label="Devices" value={@device_count} />
      <.stat_card label="TX Channels" value={@tx_channel_count} />
      <.stat_card label="RX Channels" value={@rx_channel_count} />
      <.stat_card label="Subscriptions" value={@subscription_count} />
      <.stat_card label="Active" value={@active_subscription_count} />
    </div>

    <%!-- Two-column layout --%>
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <%!-- Devices card --%>
      <div class="card bg-base-200 border border-base-300 shadow">
        <div class="card-body p-0">
          <h3 class="card-title text-sm px-5 pt-4 pb-2 border-b border-base-300">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-primary" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M2 5a2 2 0 012-2h12a2 2 0 012 2v2a2 2 0 01-2 2H4a2 2 0 01-2-2V5zm14 1a1 1 0 11-2 0 1 1 0 012 0zM2 13a2 2 0 012-2h12a2 2 0 012 2v2a2 2 0 01-2 2H4a2 2 0 01-2-2v-2zm14 1a1 1 0 11-2 0 1 1 0 012 0z" clip-rule="evenodd" />
            </svg>
            Devices
          </h3>

          <%= if map_size(@devices) == 0 do %>
            <div class="p-8 text-center text-base-content/40 text-sm">
              No devices discovered. Click "Discover Devices" to scan the network.
            </div>
          <% else %>
            <ul class="divide-y divide-base-300">
              <%= for {_key, device} <- @devices do %>
                <li>
                  <a href={"/devices/#{device.server_name}"} class="flex items-center justify-between p-4 hover:bg-base-300/50 transition-colors">
                    <div class="flex items-center gap-3">
                      <div class="w-2 h-2 rounded-full bg-success"></div>
                      <div>
                        <p class="font-medium text-sm"><%= device.name || device.server_name %></p>
                        <p class="text-xs text-base-content/50"><%= device.ipv4 %></p>
                      </div>
                    </div>
                    <div class="text-right">
                      <div class="flex gap-2">
                        <span class="badge badge-sm badge-ghost">TX: <%= map_size(device.tx_channels) %></span>
                        <span class="badge badge-sm badge-ghost">RX: <%= map_size(device.rx_channels) %></span>
                      </div>
                      <%= if device.sample_rate do %>
                        <p class="text-xs text-base-content/40 mt-1"><%= div(device.sample_rate, 1000) %> kHz</p>
                      <% end %>
                    </div>
                  </a>
                </li>
              <% end %>
            </ul>
          <% end %>
        </div>
      </div>

      <%!-- Active subscriptions card --%>
      <div class="card bg-base-200 border border-base-300 shadow">
        <div class="card-body p-0">
          <h3 class="card-title text-sm px-5 pt-4 pb-2 border-b border-base-300">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-success" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M12.586 4.586a2 2 0 112.828 2.828l-3 3a2 2 0 01-2.828 0 1 1 0 00-1.414 1.414 4 4 0 005.656 0l3-3a4 4 0 00-5.656-5.656l-1.5 1.5a1 1 0 101.414 1.414l1.5-1.5zm-5 5a2 2 0 012.828 0 1 1 0 101.414-1.414 4 4 0 00-5.656 0l-3 3a4 4 0 105.656 5.656l1.5-1.5a1 1 0 10-1.414-1.414l-1.5 1.5a2 2 0 11-2.828-2.828l3-3z" clip-rule="evenodd" />
            </svg>
            Active Subscriptions
          </h3>

          <% active_subs = Enum.flat_map(@devices, fn {_k, d} ->
            Enum.filter(d.subscriptions, fn s -> s.status_code in [9, 10, 14, 4] end)
          end) %>

          <%= if Enum.empty?(active_subs) do %>
            <div class="p-8 text-center text-base-content/40 text-sm">
              No active subscriptions.
            </div>
          <% else %>
            <ul class="divide-y divide-base-300">
              <%= for sub <- Enum.take(active_subs, 10) do %>
                <li class="flex items-center gap-2 px-4 py-3 text-sm">
                  <span class="text-accent font-mono text-xs"><%= sub.tx_channel_name %></span>
                  <span class="text-base-content/30">@</span>
                  <span class="text-base-content/70"><%= sub.tx_device_name %></span>
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3 text-success mx-1 shrink-0" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M12.293 5.293a1 1 0 011.414 0l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414-1.414L14.586 11H3a1 1 0 110-2h11.586l-2.293-2.293a1 1 0 010-1.414z" clip-rule="evenodd" />
                  </svg>
                  <span class="text-info font-mono text-xs"><%= sub.rx_channel_name %></span>
                  <span class="text-base-content/30">@</span>
                  <span class="text-base-content/70"><%= sub.rx_device_name %></span>
                </li>
              <% end %>
              <%= if length(active_subs) > 10 do %>
                <li class="px-4 py-2 text-center">
                  <a href="/subscriptions" class="link link-primary text-xs">
                    View all <%= length(active_subs) %> subscriptions
                  </a>
                </li>
              <% end %>
            </ul>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
