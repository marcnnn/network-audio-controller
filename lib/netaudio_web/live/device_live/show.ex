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
          <button class="btn btn-ghost btn-sm" phx-click="identify">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
              <path d="M11 3a1 1 0 10-2 0v1a1 1 0 102 0V3zM15.657 5.757a1 1 0 00-1.414-1.414l-.707.707a1 1 0 001.414 1.414l.707-.707zM18 10a1 1 0 01-1 1h-1a1 1 0 110-2h1a1 1 0 011 1zM5.05 6.464A1 1 0 106.464 5.05l-.707-.707a1 1 0 00-1.414 1.414l.707.707zM5 10a1 1 0 01-1 1H3a1 1 0 110-2h1a1 1 0 011 1zM8 16v-1h4v1a2 2 0 11-4 0zM12 14c.015-.34.208-.646.477-.859a4 4 0 10-4.954 0c.27.213.462.519.476.859h4.002z" />
            </svg>
            Identify
          </button>
          <a href="/devices" class="btn btn-ghost btn-sm">Back</a>
        </:actions>
      </.header>

      <%!-- Device info cards --%>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
        <div class="card bg-base-200 border border-base-300 shadow">
          <div class="card-body p-4">
            <h3 class="card-title text-sm text-base-content/60">Device Info</h3>
            <div class="space-y-2 mt-2">
              <.info_row label="Server Name" value={@device.server_name} />
              <.info_row label="IP Address" value={@device.ipv4} />
              <.info_row label="MAC Address" value={@device.mac_address || "-"} />
              <.info_row label="Model" value={@device.model || "-"} />
              <.info_row label="Manufacturer" value={@device.manufacturer || "-"} />
            </div>
          </div>
        </div>

        <div class="card bg-base-200 border border-base-300 shadow">
          <div class="card-body p-4">
            <h3 class="card-title text-sm text-base-content/60">Audio Config</h3>
            <div class="space-y-2 mt-2">
              <.info_row label="Sample Rate" value={if @device.sample_rate, do: "#{@device.sample_rate} Hz", else: "-"} />
              <.info_row label="Latency" value={if @device.latency, do: "#{@device.latency} ns", else: "-"} />
              <.info_row label="Software" value={@device.software || "-"} />
            </div>
          </div>
        </div>

        <div class="card bg-base-200 border border-base-300 shadow">
          <div class="card-body p-4">
            <h3 class="card-title text-sm text-base-content/60">Channel Counts</h3>
            <div class="stats stats-vertical bg-transparent shadow-none p-0">
              <div class="stat p-2">
                <div class="stat-title text-xs">TX Channels</div>
                <div class="stat-value text-xl text-accent"><%= map_size(@device.tx_channels) %></div>
              </div>
              <div class="stat p-2">
                <div class="stat-title text-xs">RX Channels</div>
                <div class="stat-value text-xl text-info"><%= map_size(@device.rx_channels) %></div>
              </div>
              <div class="stat p-2">
                <div class="stat-title text-xs">Subscriptions</div>
                <div class="stat-value text-xl text-primary"><%= length(@device.subscriptions) %></div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Channels --%>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        <div class="card bg-base-200 border border-base-300 shadow">
          <div class="card-body p-0">
            <h3 class="card-title text-sm px-5 pt-4 pb-2 border-b border-base-300">
              <span class="badge badge-accent badge-sm">TX</span>
              Transmit Channels
            </h3>
            <%= if map_size(@device.tx_channels) == 0 do %>
              <div class="p-6 text-center text-base-content/40 text-sm">No TX channels.</div>
            <% else %>
              <div class="overflow-x-auto">
                <table class="table table-xs">
                  <thead>
                    <tr><th>#</th><th>Name</th><th>Friendly Name</th></tr>
                  </thead>
                  <tbody>
                    <%= for {num, ch} <- Enum.sort(@device.tx_channels) do %>
                      <tr class="hover">
                        <td class="font-mono text-base-content/50"><%= num %></td>
                        <td><%= ch.name %></td>
                        <td class="text-base-content/60"><%= ch.friendly_name || "-" %></td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            <% end %>
          </div>
        </div>

        <div class="card bg-base-200 border border-base-300 shadow">
          <div class="card-body p-0">
            <h3 class="card-title text-sm px-5 pt-4 pb-2 border-b border-base-300">
              <span class="badge badge-info badge-sm">RX</span>
              Receive Channels
            </h3>
            <%= if map_size(@device.rx_channels) == 0 do %>
              <div class="p-6 text-center text-base-content/40 text-sm">No RX channels.</div>
            <% else %>
              <div class="overflow-x-auto">
                <table class="table table-xs">
                  <thead>
                    <tr><th>#</th><th>Name</th></tr>
                  </thead>
                  <tbody>
                    <%= for {num, ch} <- Enum.sort(@device.rx_channels) do %>
                      <tr class="hover">
                        <td class="font-mono text-base-content/50"><%= num %></td>
                        <td><%= ch.name %></td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <%!-- Subscriptions --%>
      <div class="card bg-base-200 border border-base-300 shadow">
        <div class="card-body p-0">
          <h3 class="card-title text-sm px-5 pt-4 pb-2 border-b border-base-300">Subscriptions</h3>
          <%= if Enum.empty?(@device.subscriptions) do %>
            <div class="p-6 text-center text-base-content/40 text-sm">No subscriptions.</div>
          <% else %>
            <div class="overflow-x-auto">
              <table class="table table-sm">
                <thead>
                  <tr>
                    <th class="text-xs">RX Channel</th>
                    <th class="text-xs">TX Channel</th>
                    <th class="text-xs">TX Device</th>
                    <th class="text-xs">Status</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for sub <- @device.subscriptions do %>
                    <tr class="hover">
                      <td class="font-mono text-xs"><%= sub.rx_channel_name %></td>
                      <td class="font-mono text-xs"><%= sub.tx_channel_name %></td>
                      <td><%= sub.tx_device_name %></td>
                      <td><.sub_status_badge code={sub.status_code} /></td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        </div>
      </div>
    <% else %>
      <.header>Device Not Found</.header>
      <div class="alert alert-warning">
        <span>The device "<%= @server_name %>" was not found on the network.</span>
      </div>
      <a href="/devices" class="btn btn-ghost btn-sm mt-4">Back to Devices</a>
    <% end %>
    """
  end

  defp info_row(assigns) do
    ~H"""
    <div class="flex justify-between text-sm">
      <span class="text-base-content/50"><%= @label %></span>
      <span class="font-mono text-xs"><%= @value %></span>
    </div>
    """
  end
end
