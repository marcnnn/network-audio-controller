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

    <div class="mb-6 flex space-x-4">
      <form phx-change="filter" class="flex space-x-4">
        <select name="type" class="bg-gray-800 border border-gray-600 text-gray-300 rounded-md px-3 py-2 text-sm">
          <option value="all" selected={@filter_type == "all"}>All Types</option>
          <option value="tx" selected={@filter_type == "tx"}>Transmitters (TX)</option>
          <option value="rx" selected={@filter_type == "rx"}>Receivers (RX)</option>
        </select>
        <select name="device" class="bg-gray-800 border border-gray-600 text-gray-300 rounded-md px-3 py-2 text-sm">
          <option value="all" selected={@filter_device == "all"}>All Devices</option>
          <%= for name <- @device_names do %>
            <option value={name} selected={@filter_device == name}><%= name %></option>
          <% end %>
        </select>
      </form>
    </div>

    <%= if Enum.empty?(@channels) do %>
      <.card>
        <div class="p-12 text-center">
          <p class="text-gray-400">No channels found. Discover devices first.</p>
        </div>
      </.card>
    <% else %>
      <.table id="channels" rows={@channels}>
        <:col :let={ch} label="Device">
          <a href={"/devices/#{ch.device_server_name}"} class="text-indigo-400 hover:text-indigo-300">
            <%= ch.device_name %>
          </a>
        </:col>
        <:col :let={ch} label="Type">
          <span class={"px-2 py-0.5 rounded text-xs font-medium #{if ch.channel_type == :tx, do: "bg-emerald-900/50 text-emerald-300 border border-emerald-700", else: "bg-blue-900/50 text-blue-300 border border-blue-700"}"}>
            <%= if ch.channel_type == :tx, do: "TX", else: "RX" %>
          </span>
        </:col>
        <:col :let={ch} label="#"><%= ch.number %></:col>
        <:col :let={ch} label="Name"><%= ch.name %></:col>
        <:col :let={ch} label="Friendly Name"><%= ch.friendly_name || "-" %></:col>
        <:col :let={ch} label="Volume">
          <%= if ch.volume && ch.volume != 254, do: ch.volume, else: "-" %>
        </:col>
      </.table>
    <% end %>
    """
  end
end
