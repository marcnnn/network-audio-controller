defmodule NetaudioWeb.RoutingMatrixLive do
  @moduledoc """
  Dante Controller-style routing matrix with crosspoint grid.

  TX (transmit) devices/channels run along the top columns.
  RX (receive) devices/channels run along the left rows.
  Crosspoints show subscription status and allow toggling routes.
  """

  use NetaudioWeb, :live_view

  import NetaudioWeb.CoreComponents

  alias Netaudio.Dante.{Browser, Command, Device, Constants}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(5000, self(), :refresh)

    {:ok, devices} = Browser.get_devices()

    socket =
      socket
      |> assign(:devices, devices)
      |> assign(:current_path, "/routing")
      |> assign(:filter_tx, "")
      |> assign(:filter_rx, "")
      |> assign(:expanded_tx, MapSet.new())
      |> assign(:expanded_rx, MapSet.new())
      |> compute_matrix()

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
      |> compute_matrix()
      |> put_flash(:info, "Discovered #{map_size(devices)} device(s)")

    {:noreply, socket}
  end

  @impl true
  def handle_event("expand_all", _params, socket) do
    all_tx = socket.assigns.tx_devices |> Enum.map(& &1.name) |> MapSet.new()
    all_rx = socket.assigns.rx_devices |> Enum.map(& &1.name) |> MapSet.new()

    socket =
      socket
      |> assign(:expanded_tx, all_tx)
      |> assign(:expanded_rx, all_rx)
      |> compute_matrix()

    {:noreply, socket}
  end

  @impl true
  def handle_event("collapse_all", _params, socket) do
    socket =
      socket
      |> assign(:expanded_tx, MapSet.new())
      |> assign(:expanded_rx, MapSet.new())
      |> compute_matrix()

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_tx", %{"device" => device_name}, socket) do
    expanded =
      if MapSet.member?(socket.assigns.expanded_tx, device_name) do
        MapSet.delete(socket.assigns.expanded_tx, device_name)
      else
        MapSet.put(socket.assigns.expanded_tx, device_name)
      end

    socket =
      socket
      |> assign(:expanded_tx, expanded)
      |> compute_matrix()

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_rx", %{"device" => device_name}, socket) do
    expanded =
      if MapSet.member?(socket.assigns.expanded_rx, device_name) do
        MapSet.delete(socket.assigns.expanded_rx, device_name)
      else
        MapSet.put(socket.assigns.expanded_rx, device_name)
      end

    socket =
      socket
      |> assign(:expanded_rx, expanded)
      |> compute_matrix()

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_subscription", %{"tx" => tx_key, "rx" => rx_key}, socket) do
    # Parse "device_name:channel_name" keys
    [tx_device_name, tx_channel_name] = String.split(tx_key, ":", parts: 2)
    [rx_device_name, rx_channel_name] = String.split(rx_key, ":", parts: 2)

    devices = socket.assigns.devices
    rx_device = Enum.find_value(devices, fn {_k, d} -> if d.name == rx_device_name, do: d end)

    if rx_device do
      # Find the RX channel
      rx_channel =
        Enum.find_value(rx_device.rx_channels, fn {_num, ch} ->
          if ch.name == rx_channel_name, do: ch
        end)

      if rx_channel do
        # Check if subscription already exists
        existing =
          Enum.find(rx_device.subscriptions, fn sub ->
            sub.rx_channel_name == rx_channel_name &&
              sub.tx_channel_name == tx_channel_name &&
              sub.tx_device_name == tx_device_name &&
              sub.status_code in [9, 10, 14, 4]
          end)

        if existing do
          # Remove subscription
          {cmd, service_type} = Command.remove_subscription(rx_channel.number)
          port = Device.resolve_service_port(rx_device.services, service_type)

          if port do
            Device.send_command(rx_device.ipv4, port, cmd)
          end
        else
          # Add subscription
          {cmd, service_type} =
            Command.add_subscription(rx_channel.number, tx_channel_name, tx_device_name)

          port = Device.resolve_service_port(rx_device.services, service_type)

          if port do
            Device.send_command(rx_device.ipv4, port, cmd)
          end
        end
      end
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter", params, socket) do
    socket =
      socket
      |> assign(:filter_tx, Map.get(params, "filter_tx", ""))
      |> assign(:filter_rx, Map.get(params, "filter_rx", ""))
      |> compute_matrix()

    {:noreply, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:ok, devices} = Browser.get_devices()

    socket =
      socket
      |> assign(:devices, devices)
      |> compute_matrix()

    {:noreply, socket}
  end

  defp compute_matrix(socket) do
    devices = socket.assigns.devices
    filter_tx = String.downcase(socket.assigns.filter_tx)
    filter_rx = String.downcase(socket.assigns.filter_rx)
    expanded_tx = socket.assigns.expanded_tx
    expanded_rx = socket.assigns.expanded_rx

    # Build TX column headers (devices and optionally channels)
    tx_devices =
      devices
      |> Enum.map(fn {_key, device} -> device end)
      |> Enum.filter(&(map_size(&1.tx_channels) > 0))
      |> Enum.filter(fn d ->
        filter_tx == "" || String.contains?(String.downcase(d.name || ""), filter_tx)
      end)
      |> Enum.sort_by(& &1.name)

    tx_columns =
      Enum.flat_map(tx_devices, fn device ->
        if MapSet.member?(expanded_tx, device.name) do
          device.tx_channels
          |> Enum.sort_by(fn {num, _ch} -> num end)
          |> Enum.map(fn {_num, ch} ->
            %{type: :channel, device_name: device.name, channel_name: ch.friendly_name || ch.name, key: "#{device.name}:#{ch.name}"}
          end)
        else
          [%{type: :device, device_name: device.name, channel_name: nil, key: "#{device.name}:*"}]
        end
      end)

    # Build RX row headers
    rx_devices =
      devices
      |> Enum.map(fn {_key, device} -> device end)
      |> Enum.filter(&(map_size(&1.rx_channels) > 0))
      |> Enum.filter(fn d ->
        filter_rx == "" || String.contains?(String.downcase(d.name || ""), filter_rx)
      end)
      |> Enum.sort_by(& &1.name)

    rx_rows =
      Enum.flat_map(rx_devices, fn device ->
        if MapSet.member?(expanded_rx, device.name) do
          device.rx_channels
          |> Enum.sort_by(fn {num, _ch} -> num end)
          |> Enum.map(fn {_num, ch} ->
            %{type: :channel, device_name: device.name, channel_name: ch.name, key: "#{device.name}:#{ch.name}"}
          end)
        else
          [%{type: :device, device_name: device.name, channel_name: nil, key: "#{device.name}:*"}]
        end
      end)

    # Build subscription lookup for crosspoints
    sub_lookup =
      devices
      |> Enum.flat_map(fn {_key, device} ->
        Enum.map(device.subscriptions, fn sub ->
          key = {"#{sub.tx_device_name}:#{sub.tx_channel_name}", "#{sub.rx_device_name}:#{sub.rx_channel_name}"}
          {key, sub.status_code}
        end)
      end)
      |> Enum.into(%{})

    socket
    |> assign(:tx_devices, tx_devices)
    |> assign(:rx_devices, rx_devices)
    |> assign(:tx_columns, tx_columns)
    |> assign(:rx_rows, rx_rows)
    |> assign(:sub_lookup, sub_lookup)
  end

  defp crosspoint_class(status) do
    cond do
      status in [9, 10, 14, 4] -> "crosspoint crosspoint-active"
      status in [1, 3, 7, 8] -> "crosspoint crosspoint-error"
      status == :available -> "crosspoint crosspoint-available"
      status == :disabled -> "crosspoint crosspoint-disabled"
      true -> "crosspoint crosspoint-available"
    end
  end

  defp crosspoint_icon(status) do
    cond do
      status in [9, 10, 14, 4] -> "✓"
      status in [1, 3, 7, 8] -> "!"
      status == :disabled -> ""
      true -> ""
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Routing
      <:actions>
        <button class="btn btn-ghost btn-sm" phx-click="expand_all">Expand All</button>
        <button class="btn btn-ghost btn-sm" phx-click="collapse_all">Collapse All</button>
        <button class="btn btn-primary btn-sm" phx-click="discover">Discover</button>
      </:actions>
    </.header>

    <%!-- Filter bar --%>
    <div class="flex gap-3 mb-4">
      <form phx-change="filter" class="flex gap-3 flex-1">
        <div class="form-control flex-1 max-w-xs">
          <label class="label py-0">
            <span class="label-text text-xs">Filter Transmitters</span>
          </label>
          <input
            type="text"
            name="filter_tx"
            value={@filter_tx}
            placeholder="TX device name..."
            class="input input-bordered input-sm w-full"
          />
        </div>
        <div class="form-control flex-1 max-w-xs">
          <label class="label py-0">
            <span class="label-text text-xs">Filter Receivers</span>
          </label>
          <input
            type="text"
            name="filter_rx"
            value={@filter_rx}
            placeholder="RX device name..."
            class="input input-bordered input-sm w-full"
          />
        </div>
      </form>
    </div>

    <%!-- Legend --%>
    <div class="flex gap-4 mb-4 text-xs text-base-content/60">
      <div class="flex items-center gap-1.5">
        <div class="crosspoint crosspoint-active w-4 h-4 text-[0.6rem]">✓</div>
        <span>Active</span>
      </div>
      <div class="flex items-center gap-1.5">
        <div class="crosspoint crosspoint-available w-4 h-4"></div>
        <span>Available</span>
      </div>
      <div class="flex items-center gap-1.5">
        <div class="crosspoint crosspoint-error w-4 h-4 text-[0.6rem]">!</div>
        <span>Error</span>
      </div>
      <div class="flex items-center gap-1.5">
        <div class="crosspoint crosspoint-disabled w-4 h-4"></div>
        <span>Unavailable</span>
      </div>
    </div>

    <%= if Enum.empty?(@tx_columns) || Enum.empty?(@rx_rows) do %>
      <.empty_state>
        No devices with channels found. Discover devices first.
        <:action>
          <button class="btn btn-primary btn-sm" phx-click="discover">Discover Devices</button>
        </:action>
      </.empty_state>
    <% else %>
      <%!-- Routing matrix grid --%>
      <div class="card bg-base-200 border border-base-300 shadow overflow-hidden">
        <div class="routing-matrix overflow-auto p-2">
          <table class="border-collapse">
            <%!-- TX column headers --%>
            <thead>
              <tr>
                <%!-- Top-left corner: label --%>
                <th class="sticky left-0 z-20 bg-base-200 min-w-[140px] p-1">
                  <div class="text-[0.6rem] text-base-content/40 text-right pr-1">
                    <span class="text-accent">TX</span> &rarr;<br/>
                    <span class="text-info">&darr; RX</span>
                  </div>
                </th>
                <%= for col <- @tx_columns do %>
                  <th class="p-0 align-bottom">
                    <%= if col.type == :device do %>
                      <button
                        phx-click="toggle_tx"
                        phx-value-device={col.device_name}
                        class="flex flex-col items-center cursor-pointer hover:text-primary transition-colors"
                        data-tx-header={col.key}
                      >
                        <span class="tx-label font-medium text-accent text-[0.65rem]">
                          <span class="opacity-60 mr-0.5"><%= if MapSet.member?(@expanded_tx, col.device_name), do: "−", else: "+" %></span>
                          <%= col.device_name %>
                        </span>
                      </button>
                    <% else %>
                      <div class="flex flex-col items-center" data-tx-header={col.key}>
                        <span class="tx-label text-base-content/70 text-[0.6rem]"><%= col.channel_name %></span>
                      </div>
                    <% end %>
                  </th>
                <% end %>
              </tr>
            </thead>

            <%!-- RX rows with crosspoints --%>
            <tbody>
              <%= for row <- @rx_rows do %>
                <tr>
                  <%!-- RX row header --%>
                  <td class="sticky left-0 z-10 bg-base-200 pr-2 py-0">
                    <%= if row.type == :device do %>
                      <button
                        phx-click="toggle_rx"
                        phx-value-device={row.device_name}
                        class="flex items-center gap-1 cursor-pointer hover:text-primary transition-colors text-xs whitespace-nowrap"
                        data-rx-header={row.key}
                      >
                        <span class="opacity-60"><%= if MapSet.member?(@expanded_rx, row.device_name), do: "−", else: "+" %></span>
                        <span class="font-medium text-info"><%= row.device_name %></span>
                      </button>
                    <% else %>
                      <div class="flex items-center pl-4 text-[0.65rem] text-base-content/70 whitespace-nowrap" data-rx-header={row.key}>
                        <%= row.channel_name %>
                      </div>
                    <% end %>
                  </td>

                  <%!-- Crosspoint cells --%>
                  <%= for col <- @tx_columns do %>
                    <td class="p-0">
                      <% status = get_crosspoint_status(col, row, @sub_lookup)
                         is_same_device = get_device_name(col) == get_device_name(row) && col.type == :channel && row.type == :channel
                         effective_status = if is_same_device, do: :disabled, else: status
                         can_click = col.type == :channel && row.type == :channel && !is_same_device
                      %>
                      <%= if can_click do %>
                        <div
                          class={crosspoint_class(effective_status)}
                          phx-click="toggle_subscription"
                          phx-value-tx={col.key}
                          phx-value-rx={row.key}
                          phx-hook="Crosspoint"
                          id={"cp-#{col.key}-#{row.key}"}
                          data-tx-channel={col.key}
                          data-rx-channel={row.key}
                          title={"#{col.device_name}:#{col.channel_name} -> #{row.device_name}:#{row.channel_name}"}
                        >
                          <%= crosspoint_icon(effective_status) %>
                        </div>
                      <% else %>
                        <div class={crosspoint_class(effective_status)}>
                          <%= crosspoint_icon(effective_status) %>
                        </div>
                      <% end %>
                    </td>
                  <% end %>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>
    """
  end

  defp get_device_name(%{device_name: name}), do: name

  defp get_crosspoint_status(tx_col, rx_row, sub_lookup) do
    # For device-level rows/cols, check if any channel subscriptions exist
    cond do
      tx_col.type == :device || rx_row.type == :device ->
        :available

      true ->
        case Map.get(sub_lookup, {tx_col.key, rx_row.key}) do
          nil -> :available
          status -> status
        end
    end
  end
end
