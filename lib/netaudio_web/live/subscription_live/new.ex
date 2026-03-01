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
        <a href="/subscriptions" class="btn btn-ghost btn-sm">Cancel</a>
      </:actions>
    </.header>

    <div class="card bg-base-200 border border-base-300 shadow">
      <div class="card-body">
        <form phx-submit="add_subscription">
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
            <%!-- TX Source --%>
            <div>
              <h3 class="text-lg font-semibold mb-4 flex items-center gap-2">
                <span class="badge badge-accent">TX</span>
                Source (Transmitter)
              </h3>

              <div class="form-control mb-4">
                <label class="label">
                  <span class="label-text">Device</span>
                </label>
                <select
                  name="tx_device_select"
                  phx-change="select_tx_device"
                  class="select select-bordered w-full"
                >
                  <option value="">Select a device...</option>
                  <%= for device <- @device_list do %>
                    <option value={device.name} selected={@tx_device && @tx_device.name == device.name}>
                      <%= device.name %>
                    </option>
                  <% end %>
                </select>
              </div>

              <div class="form-control">
                <label class="label">
                  <span class="label-text">Channel</span>
                </label>
                <select
                  name="tx_channel"
                  class="select select-bordered w-full"
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

            <%!-- Divider with arrow --%>
            <div class="lg:hidden divider">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-base-content/30" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M16.707 10.293a1 1 0 010 1.414l-6 6a1 1 0 01-1.414 0l-6-6a1 1 0 111.414-1.414L9 14.586V3a1 1 0 012 0v11.586l4.293-4.293a1 1 0 011.414 0z" clip-rule="evenodd" />
              </svg>
            </div>

            <%!-- RX Destination --%>
            <div>
              <h3 class="text-lg font-semibold mb-4 flex items-center gap-2">
                <span class="badge badge-info">RX</span>
                Destination (Receiver)
              </h3>

              <div class="form-control mb-4">
                <label class="label">
                  <span class="label-text">Device</span>
                </label>
                <select
                  name="rx_device_select"
                  phx-change="select_rx_device"
                  class="select select-bordered w-full"
                >
                  <option value="">Select a device...</option>
                  <%= for device <- @device_list do %>
                    <option value={device.name} selected={@rx_device && @rx_device.name == device.name}>
                      <%= device.name %>
                    </option>
                  <% end %>
                </select>
              </div>

              <div class="form-control">
                <label class="label">
                  <span class="label-text">Channel</span>
                </label>
                <select
                  name="rx_channel"
                  class="select select-bordered w-full"
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

          <div class="divider"></div>

          <div class="flex justify-end">
            <button type="submit" class="btn btn-primary gap-2">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" clip-rule="evenodd" />
              </svg>
              Add Subscription
            </button>
          </div>
        </form>
      </div>
    </div>
    """
  end
end
