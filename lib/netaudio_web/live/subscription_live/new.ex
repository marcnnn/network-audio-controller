defmodule NetaudioWeb.SubscriptionLive.New do
  use NetaudioWeb, :live_view

  import NetaudioWeb.CoreComponents

  alias Netaudio.Dante.{Browser, Command, Device}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, devices} = Browser.get_devices()

    device_list =
      devices
      |> Enum.map(fn {_key, device} -> device end)
      |> Enum.sort_by(& &1.name)

    socket =
      socket
      |> assign(:devices, devices)
      |> assign(:device_list, device_list)
      |> assign(:tx_device, nil)
      |> assign(:rx_device, nil)
      |> assign(:tx_channels, [])
      |> assign(:rx_channels, [])
      |> assign(:current_path, "/subscriptions/new")

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, :current_path, URI.parse(uri).path)}
  end

  @impl true
  def handle_event("select_tx_device", %{"tx_device" => name}, socket) do
    device = Enum.find(socket.assigns.device_list, &(&1.name == name))

    tx_channels =
      if device do
        device.tx_channels
        |> Enum.sort_by(fn {num, _ch} -> num end)
        |> Enum.map(fn {_num, ch} -> ch end)
      else
        []
      end

    socket =
      socket
      |> assign(:tx_device, device)
      |> assign(:tx_channels, tx_channels)

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_rx_device", %{"rx_device" => name}, socket) do
    device = Enum.find(socket.assigns.device_list, &(&1.name == name))

    rx_channels =
      if device do
        device.rx_channels
        |> Enum.sort_by(fn {num, _ch} -> num end)
        |> Enum.map(fn {_num, ch} -> ch end)
      else
        []
      end

    socket =
      socket
      |> assign(:rx_device, device)
      |> assign(:rx_channels, rx_channels)

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "add_subscription",
        %{"tx_channel" => tx_channel_name, "rx_channel" => rx_channel_name},
        socket
      ) do
    tx_device = socket.assigns.tx_device
    rx_device = socket.assigns.rx_device

    if tx_device && rx_device && tx_channel_name != "" && rx_channel_name != "" do
      rx_channel =
        Enum.find(socket.assigns.rx_channels, fn ch -> ch.name == rx_channel_name end)

      if rx_channel do
        {cmd, service_type} =
          Command.add_subscription(rx_channel.number, tx_channel_name, tx_device.name)

        port = Device.resolve_service_port(rx_device.services, service_type)

        if port do
          case Device.send_command(rx_device.ipv4, port, cmd) do
            {:ok, _} ->
              socket =
                socket
                |> put_flash(:info, "Subscription added: #{tx_channel_name}@#{tx_device.name} -> #{rx_channel_name}@#{rx_device.name}")
                |> push_navigate(to: "/subscriptions")

              {:noreply, socket}

            {:error, reason} ->
              {:noreply, put_flash(socket, :error, "Failed: #{inspect(reason)}")}
          end
        else
          {:noreply, put_flash(socket, :error, "No service port available")}
        end
      else
        {:noreply, put_flash(socket, :error, "RX channel not found")}
      end
    else
      {:noreply, put_flash(socket, :error, "Please select all fields")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Add Subscription
      <:actions>
        <a href="/subscriptions" class="inline-flex items-center rounded-md bg-gray-700 px-3 py-2 text-sm font-semibold text-gray-300 hover:bg-gray-600">
          Cancel
        </a>
      </:actions>
    </.header>

    <.card>
      <div class="p-6">
        <form phx-submit="add_subscription" class="space-y-6">
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <%!-- TX Side --%>
            <div class="space-y-4">
              <h3 class="text-lg font-medium text-emerald-400">Source (TX)</h3>

              <div>
                <label class="block text-sm font-medium text-gray-400 mb-1">TX Device</label>
                <select
                  name="tx_device_select"
                  phx-change="select_tx_device"
                  class="w-full bg-gray-800 border border-gray-600 text-gray-300 rounded-md px-3 py-2 text-sm"
                >
                  <option value="">Select a device...</option>
                  <%= for device <- @device_list do %>
                    <option value={device.name} selected={@tx_device && @tx_device.name == device.name}>
                      <%= device.name %>
                    </option>
                  <% end %>
                </select>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-400 mb-1">TX Channel</label>
                <select
                  name="tx_channel"
                  class="w-full bg-gray-800 border border-gray-600 text-gray-300 rounded-md px-3 py-2 text-sm"
                  disabled={Enum.empty?(@tx_channels)}
                >
                  <option value="">Select a channel...</option>
                  <%= for ch <- @tx_channels do %>
                    <option value={ch.name}>
                      <%= ch.number %>: <%= ch.friendly_name || ch.name %>
                    </option>
                  <% end %>
                </select>
              </div>
            </div>

            <%!-- RX Side --%>
            <div class="space-y-4">
              <h3 class="text-lg font-medium text-blue-400">Destination (RX)</h3>

              <div>
                <label class="block text-sm font-medium text-gray-400 mb-1">RX Device</label>
                <select
                  name="rx_device_select"
                  phx-change="select_rx_device"
                  class="w-full bg-gray-800 border border-gray-600 text-gray-300 rounded-md px-3 py-2 text-sm"
                >
                  <option value="">Select a device...</option>
                  <%= for device <- @device_list do %>
                    <option value={device.name} selected={@rx_device && @rx_device.name == device.name}>
                      <%= device.name %>
                    </option>
                  <% end %>
                </select>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-400 mb-1">RX Channel</label>
                <select
                  name="rx_channel"
                  class="w-full bg-gray-800 border border-gray-600 text-gray-300 rounded-md px-3 py-2 text-sm"
                  disabled={Enum.empty?(@rx_channels)}
                >
                  <option value="">Select a channel...</option>
                  <%= for ch <- @rx_channels do %>
                    <option value={ch.name}>
                      <%= ch.number %>: <%= ch.name %>
                    </option>
                  <% end %>
                </select>
              </div>
            </div>
          </div>

          <div class="flex justify-end pt-4 border-t border-gray-700">
            <.button type="submit" variant={:primary}>
              Add Subscription
            </.button>
          </div>
        </form>
      </div>
    </.card>
    """
  end
end
