defmodule NetaudioWeb.ChannelLive.Index do
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
      |> assign(:filter_type, "all")
      |> assign(:filter_device, "all")
      |> assign(:current_path, "/channels")
      |> compute_channels()

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, :current_path, URI.parse(uri).path)}
  end

  @impl true
  def handle_event("filter", %{"type" => type, "device" => device}, socket) do
    socket =
      socket
      |> assign(:filter_type, type)
      |> assign(:filter_device, device)
      |> compute_channels()

    {:noreply, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:ok, devices} = Browser.get_devices()

    socket =
      socket
      |> assign(:devices, devices)
      |> compute_channels()

    {:noreply, socket}
  end

  defp compute_channels(socket) do
    devices = socket.assigns.devices
    filter_type = socket.assigns.filter_type
    filter_device = socket.assigns.filter_device

    channels =
      devices
      |> Enum.flat_map(fn {_key, device} ->
        tx =
          device.tx_channels
          |> Enum.map(fn {_num, ch} ->
            Map.merge(ch, %{device_name: device.name, device_server_name: device.server_name})
          end)

        rx =
          device.rx_channels
          |> Enum.map(fn {_num, ch} ->
            Map.merge(ch, %{device_name: device.name, device_server_name: device.server_name})
          end)

        tx ++ rx
      end)
      |> Enum.filter(fn ch ->
        type_match =
          case filter_type do
            "all" -> true
            "tx" -> ch.channel_type == :tx
            "rx" -> ch.channel_type == :rx
            _ -> true
          end

        device_match =
          case filter_device do
            "all" -> true
            name -> ch.device_name == name
          end

        type_match && device_match
      end)
      |> Enum.sort_by(fn ch -> {ch.device_name, ch.channel_type, ch.number} end)

    device_names =
      devices
      |> Enum.map(fn {_key, device} -> device.name end)
      |> Enum.sort()

    socket
    |> assign(:channels, channels)
    |> assign(:device_names, device_names)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Channels
    </.header>

    <%!-- Filters --%>
    <div class="flex flex-wrap gap-3 mb-5">
      <form phx-change="filter" class="flex flex-wrap gap-3">
        <select name="type" class="select select-bordered select-sm">
          <option value="all" selected={@filter_type == "all"}>All Types</option>
          <option value="tx" selected={@filter_type == "tx"}>Transmitters (TX)</option>
          <option value="rx" selected={@filter_type == "rx"}>Receivers (RX)</option>
        </select>
        <select name="device" class="select select-bordered select-sm">
          <option value="all" selected={@filter_device == "all"}>All Devices</option>
          <%= for name <- @device_names do %>
            <option value={name} selected={@filter_device == name}><%= name %></option>
          <% end %>
        </select>
      </form>
      <div class="badge badge-ghost badge-lg self-center">
        <%= length(@channels) %> channel(s)
      </div>
    </div>

    <%= if Enum.empty?(@channels) do %>
      <.empty_state>
        No channels found. Discover devices first.
      </.empty_state>
    <% else %>
      <div class="overflow-x-auto rounded-box border border-base-300 bg-base-200">
        <table class="table table-sm">
          <thead>
            <tr class="border-b border-base-300">
              <th class="text-xs uppercase tracking-wider text-base-content/60">Device</th>
              <th class="text-xs uppercase tracking-wider text-base-content/60">Type</th>
              <th class="text-xs uppercase tracking-wider text-base-content/60">#</th>
              <th class="text-xs uppercase tracking-wider text-base-content/60">Name</th>
              <th class="text-xs uppercase tracking-wider text-base-content/60">Friendly Name</th>
            </tr>
          </thead>
          <tbody>
            <%= for ch <- @channels do %>
              <tr class="hover">
                <td>
                  <a href={"/devices/#{ch.device_server_name}"} class="link link-primary text-sm">
                    <%= ch.device_name %>
                  </a>
                </td>
                <td>
                  <%= if ch.channel_type == :tx do %>
                    <span class="badge badge-sm badge-accent">TX</span>
                  <% else %>
                    <span class="badge badge-sm badge-info">RX</span>
                  <% end %>
                </td>
                <td class="font-mono text-xs"><%= ch.number %></td>
                <td class="text-sm"><%= ch.name %></td>
                <td class="text-sm text-base-content/60"><%= ch.friendly_name || "-" %></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    <% end %>
    """
  end
end
