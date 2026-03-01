defmodule NetaudioWeb.DeviceLive.Show do
  use NetaudioWeb, :live_view

  import NetaudioWeb.CoreComponents

  alias Netaudio.Dante.{Browser, Command, Device, Constants}

  @impl true
  def mount(%{"id" => server_name}, _session, socket) do
    {:ok, devices} = Browser.get_devices()
    device = Map.get(devices, server_name)

    socket =
      socket
      |> assign(:server_name, server_name)
      |> assign(:device, device)
      |> assign(:current_path, "/devices/#{server_name}")

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, :current_path, URI.parse(uri).path)}
  end

  @impl true
  def handle_event("identify", _params, socket) do
    device = socket.assigns.device

    if device do
      {cmd, _service, port} = Command.identify()

      case Device.send_command(device.ipv4, port, cmd) do
        {:ok, _} ->
          {:noreply, put_flash(socket, :info, "Identify command sent to #{device.name}")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to send identify command")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= if @device do %>
      <.header>
        <%= @device.name || @device.server_name %>
        <:actions>
          <.button phx-click="identify" variant={:secondary}>Identify Device</.button>
          <a href="/devices" class="inline-flex items-center rounded-md bg-gray-700 px-3 py-2 text-sm font-semibold text-gray-300 hover:bg-gray-600">
            Back to Devices
          </a>
        </:actions>
      </.header>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
        <.card>
          <div class="p-6">
            <h3 class="text-sm font-medium text-gray-400 mb-4">Device Info</h3>
            <dl class="space-y-3">
              <div>
                <dt class="text-xs text-gray-500">Server Name</dt>
                <dd class="text-sm text-white"><%= @device.server_name %></dd>
              </div>
              <div>
                <dt class="text-xs text-gray-500">IP Address</dt>
                <dd class="text-sm text-white"><%= @device.ipv4 %></dd>
              </div>
              <div>
                <dt class="text-xs text-gray-500">MAC Address</dt>
                <dd class="text-sm text-white"><%= @device.mac_address || "-" %></dd>
              </div>
              <div>
                <dt class="text-xs text-gray-500">Model</dt>
                <dd class="text-sm text-white"><%= @device.model || "-" %></dd>
              </div>
              <div>
                <dt class="text-xs text-gray-500">Manufacturer</dt>
                <dd class="text-sm text-white"><%= @device.manufacturer || "-" %></dd>
              </div>
            </dl>
          </div>
        </.card>

        <.card>
          <div class="p-6">
            <h3 class="text-sm font-medium text-gray-400 mb-4">Audio Config</h3>
            <dl class="space-y-3">
              <div>
                <dt class="text-xs text-gray-500">Sample Rate</dt>
                <dd class="text-sm text-white">
                  <%= if @device.sample_rate, do: "#{@device.sample_rate} Hz", else: "-" %>
                </dd>
              </div>
              <div>
                <dt class="text-xs text-gray-500">Latency</dt>
                <dd class="text-sm text-white">
                  <%= if @device.latency, do: "#{@device.latency} ns", else: "-" %>
                </dd>
              </div>
              <div>
                <dt class="text-xs text-gray-500">Software</dt>
                <dd class="text-sm text-white"><%= @device.software || "-" %></dd>
              </div>
            </dl>
          </div>
        </.card>

        <.card>
          <div class="p-6">
            <h3 class="text-sm font-medium text-gray-400 mb-4">Channel Counts</h3>
            <dl class="space-y-3">
              <div>
                <dt class="text-xs text-gray-500">TX Channels</dt>
                <dd class="text-2xl font-bold text-white"><%= map_size(@device.tx_channels) %></dd>
              </div>
              <div>
                <dt class="text-xs text-gray-500">RX Channels</dt>
                <dd class="text-2xl font-bold text-white"><%= map_size(@device.rx_channels) %></dd>
              </div>
              <div>
                <dt class="text-xs text-gray-500">Subscriptions</dt>
                <dd class="text-2xl font-bold text-white"><%= length(@device.subscriptions) %></dd>
              </div>
            </dl>
          </div>
        </.card>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
        <.card>
          <div class="px-6 py-4 border-b border-gray-700">
            <h3 class="text-lg font-medium text-white">Transmit Channels</h3>
          </div>
          <div class="p-6">
            <%= if map_size(@device.tx_channels) == 0 do %>
              <p class="text-gray-400 text-sm">No TX channels.</p>
            <% else %>
              <ul class="space-y-2">
                <%= for {num, ch} <- Enum.sort(@device.tx_channels) do %>
                  <li class="flex items-center justify-between p-2 bg-gray-700/50 rounded text-sm">
                    <span class="text-gray-400 w-8"><%= num %></span>
                    <span class="flex-1 text-white"><%= ch.friendly_name || ch.name %></span>
                    <%= if ch.volume && ch.volume != 254 do %>
                      <span class="text-gray-400">[<%= ch.volume %>]</span>
                    <% end %>
                  </li>
                <% end %>
              </ul>
            <% end %>
          </div>
        </.card>

        <.card>
          <div class="px-6 py-4 border-b border-gray-700">
            <h3 class="text-lg font-medium text-white">Receive Channels</h3>
          </div>
          <div class="p-6">
            <%= if map_size(@device.rx_channels) == 0 do %>
              <p class="text-gray-400 text-sm">No RX channels.</p>
            <% else %>
              <ul class="space-y-2">
                <%= for {num, ch} <- Enum.sort(@device.rx_channels) do %>
                  <li class="flex items-center justify-between p-2 bg-gray-700/50 rounded text-sm">
                    <span class="text-gray-400 w-8"><%= num %></span>
                    <span class="flex-1 text-white"><%= ch.name %></span>
                    <%= if ch.volume && ch.volume != 254 do %>
                      <span class="text-gray-400">[<%= ch.volume %>]</span>
                    <% end %>
                  </li>
                <% end %>
              </ul>
            <% end %>
          </div>
        </.card>
      </div>

      <.card>
        <div class="px-6 py-4 border-b border-gray-700">
          <h3 class="text-lg font-medium text-white">Subscriptions</h3>
        </div>
        <div class="p-6">
          <%= if Enum.empty?(@device.subscriptions) do %>
            <p class="text-gray-400 text-sm">No subscriptions.</p>
          <% else %>
            <.table id="device-subscriptions" rows={@device.subscriptions}>
              <:col :let={sub} label="RX Channel"><%= sub.rx_channel_name %></:col>
              <:col :let={sub} label="TX Channel"><%= sub.tx_channel_name %></:col>
              <:col :let={sub} label="TX Device"><%= sub.tx_device_name %></:col>
              <:col :let={sub} label="Status">
                <% labels = Constants.subscription_status_label(sub.status_code) %>
                <span class={"text-xs #{status_color(sub.status_code)}"}><%= hd(labels) %></span>
              </:col>
            </.table>
          <% end %>
        </div>
      </.card>
    <% else %>
      <.header>Device Not Found</.header>
      <p class="text-gray-400">The device "<%= @server_name %>" was not found.</p>
      <a href="/devices" class="text-indigo-400 hover:text-indigo-300 mt-4 inline-block">Back to Devices</a>
    <% end %>
    """
  end

  defp status_color(code) when code in [9, 10, 14, 4], do: "text-green-400"
  defp status_color(code) when code in [1, 3, 7, 8], do: "text-yellow-400"
  defp status_color(code) when code in [0], do: "text-gray-400"
  defp status_color(_code), do: "text-red-400"
end
