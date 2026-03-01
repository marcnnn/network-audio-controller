defmodule NetaudioWeb.DirectorLive.DomainDetail do
  use NetaudioWeb, :live_view

  import NetaudioWeb.CoreComponents

  alias Netaudio.Director

  @impl true
  def mount(%{"id" => domain_id}, _session, socket) do
    socket =
      socket
      |> assign(:domain_id, domain_id)
      |> assign(:domain, nil)
      |> assign(:loading, true)
      |> assign(:error, nil)
      |> assign(:current_path, "/director/domains/#{domain_id}")
      |> assign(:selected_device, nil)
      |> assign(:enrol_modal_open, false)

    if connected?(socket), do: send(self(), :load_data)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, :current_path, URI.parse(uri).path)}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    send(self(), :load_data)
    {:noreply, assign(socket, :loading, true)}
  end

  @impl true
  def handle_event("select_device", %{"device-id" => device_id}, socket) do
    device =
      (socket.assigns.domain["devices"] || [])
      |> Enum.find(&(&1["id"] == device_id))

    {:noreply, assign(socket, :selected_device, device)}
  end

  @impl true
  def handle_event("clear_selection", _params, socket) do
    {:noreply, assign(socket, :selected_device, nil)}
  end

  @impl true
  def handle_event("unenrol_device", %{"device-id" => device_id}, socket) do
    case Director.unenrol_devices([device_id]) do
      :ok ->
        send(self(), :load_data)
        {:noreply, put_flash(socket, :info, "Device unenrolled successfully")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to unenrol: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("set_unicast_clocking", %{"device-id" => device_id, "enabled" => enabled}, socket) do
    enabled_bool = enabled == "true"

    case Director.set_unicast_clocking(device_id, enabled_bool) do
      :ok ->
        send(self(), :load_data)
        {:noreply, put_flash(socket, :info, "Unicast clocking #{if enabled_bool, do: "enabled", else: "disabled"}")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_info(:load_data, socket) do
    case Director.get_domain_with_channels(id: socket.assigns.domain_id) do
      {:ok, domain} ->
        socket =
          socket
          |> assign(:domain, domain)
          |> assign(:loading, false)
          |> assign(:error, nil)

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> assign(:loading, false)
          |> assign(:error, reason)

        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= if @loading do %>
      <div class="flex justify-center py-12">
        <span class="loading loading-spinner loading-lg text-primary"></span>
      </div>
    <% else %>
      <%= if @error do %>
        <.header>Domain</.header>
        <div class="alert alert-error"><span>Error: <%= inspect(@error) %></span></div>
      <% else %>
        <.header>
          <%= @domain["name"] %>
          <:actions>
            <button class="btn btn-ghost btn-sm" phx-click="refresh">Refresh</button>
            <a href="/director/domains" class="btn btn-ghost btn-sm">Back</a>
          </:actions>
        </.header>

        <% devices = @domain["devices"] || [] %>
        <% connected = Enum.count(devices, &(get_in(&1, ["connection", "state"]) == "READY")) %>

        <%!-- Domain stats --%>
        <div class="stats stats-vertical sm:stats-horizontal shadow bg-base-200 w-full mb-6 border border-base-300">
          <.stat_card label="Devices" value={length(devices)} />
          <.stat_card label="Connected" value={connected} />
          <.stat_card label="TX Channels" value={devices |> Enum.map(&(length(&1["txChannels"] || []))) |> Enum.sum()} />
          <.stat_card label="RX Channels" value={devices |> Enum.map(&(length(&1["rxChannels"] || []))) |> Enum.sum()} />
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <%!-- Device list --%>
          <div class="lg:col-span-1">
            <div class="card bg-base-200 border border-base-300 shadow">
              <div class="card-body p-0">
                <h3 class="card-title text-sm px-5 pt-4 pb-2 border-b border-base-300">Devices</h3>
                <ul class="divide-y divide-base-300 max-h-[60vh] overflow-y-auto">
                  <%= for device <- Enum.sort_by(devices, & &1["name"]) do %>
                    <li>
                      <button
                        phx-click="select_device"
                        phx-value-device-id={device["id"]}
                        class={"w-full text-left px-4 py-3 hover:bg-base-300/50 transition-colors #{if @selected_device && @selected_device["id"] == device["id"], do: "bg-primary/10 border-l-2 border-primary", else: ""}"}
                      >
                        <div class="flex items-center justify-between">
                          <div class="flex items-center gap-2">
                            <div class={"w-2 h-2 rounded-full #{connection_dot(device)}"} />
                            <span class="font-medium text-sm"><%= device["name"] %></span>
                          </div>
                          <span class={"badge badge-xs #{enrolment_badge(device["enrolmentState"])}"}><%= device["enrolmentState"] %></span>
                        </div>
                        <div class="flex gap-2 mt-1 ml-4">
                          <span class="text-xs text-base-content/40">
                            <%= get_in(device, ["manufacturer", "name"]) || "" %>
                          </span>
                        </div>
                      </button>
                    </li>
                  <% end %>
                </ul>
              </div>
            </div>
          </div>

          <%!-- Device detail panel --%>
          <div class="lg:col-span-2">
            <%= if @selected_device do %>
              <% dev = @selected_device %>
              <div class="card bg-base-200 border border-base-300 shadow">
                <div class="card-body">
                  <div class="flex items-center justify-between mb-4">
                    <h3 class="card-title"><%= dev["name"] %></h3>
                    <div class="flex gap-2">
                      <button class="btn btn-ghost btn-xs" phx-click="clear_selection">Close</button>
                    </div>
                  </div>

                  <%!-- Device info --%>
                  <div class="grid grid-cols-2 gap-x-8 gap-y-2 text-sm mb-6">
                    <.detail_row label="ID" value={dev["id"]} mono />
                    <.detail_row label="Default Name" value={get_in(dev, ["identity", "defaultName"])} />
                    <.detail_row label="Manufacturer" value={get_in(dev, ["manufacturer", "name"])} />
                    <.detail_row label="Product" value={get_in(dev, ["product", "name"])} />
                    <.detail_row label="Platform" value={get_in(dev, ["platform", "name"])} />
                    <.detail_row label="Dante Version" value={get_in(dev, ["identity", "danteVersion"])} />
                    <.detail_row label="Software Version" value={get_in(dev, ["identity", "productSoftwareVersion"])} />
                    <.detail_row label="Connection" value={get_in(dev, ["connection", "state"])} />
                    <.detail_row label="Clock Locked" value={to_string(get_in(dev, ["clockingState", "locked"]) || "-")} />
                    <.detail_row label="Grand Leader" value={to_string(get_in(dev, ["clockingState", "grandLeader"]) || false)} />
                  </div>

                  <%!-- Interfaces --%>
                  <%= if dev["interfaces"] && dev["interfaces"] != [] do %>
                    <h4 class="font-semibold text-sm mb-2">Network Interfaces</h4>
                    <div class="overflow-x-auto mb-4">
                      <table class="table table-xs">
                        <thead><tr><th>MAC</th><th>IP</th><th>Subnet</th></tr></thead>
                        <tbody>
                          <%= for iface <- dev["interfaces"] do %>
                            <tr>
                              <td class="font-mono text-xs"><%= iface["macAddress"] || "-" %></td>
                              <td class="font-mono text-xs"><%= iface["address"] || "-" %></td>
                              <td class="font-mono text-xs"><%= iface["subnet"] || "-" %>/<%= iface["netmask"] || "" %></td>
                            </tr>
                          <% end %>
                        </tbody>
                      </table>
                    </div>
                  <% end %>

                  <%!-- TX Channels --%>
                  <% tx = dev["txChannels"] || [] %>
                  <% rx = dev["rxChannels"] || [] %>

                  <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
                    <div>
                      <h4 class="font-semibold text-sm mb-2 flex items-center gap-2">
                        <span class="badge badge-accent badge-xs">TX</span>
                        Transmit (<%= length(tx) %>)
                      </h4>
                      <%= if tx == [] do %>
                        <p class="text-xs text-base-content/40">No TX channels</p>
                      <% else %>
                        <div class="overflow-y-auto max-h-48">
                          <table class="table table-xs">
                            <thead><tr><th>#</th><th>Name</th><th>Type</th></tr></thead>
                            <tbody>
                              <%= for ch <- Enum.sort_by(tx, & &1["index"]) do %>
                                <tr>
                                  <td class="font-mono"><%= ch["index"] %></td>
                                  <td><%= ch["name"] %></td>
                                  <td class="text-xs text-base-content/50"><%= ch["mediaType"] %></td>
                                </tr>
                              <% end %>
                            </tbody>
                          </table>
                        </div>
                      <% end %>
                    </div>

                    <div>
                      <h4 class="font-semibold text-sm mb-2 flex items-center gap-2">
                        <span class="badge badge-info badge-xs">RX</span>
                        Receive (<%= length(rx) %>)
                      </h4>
                      <%= if rx == [] do %>
                        <p class="text-xs text-base-content/40">No RX channels</p>
                      <% else %>
                        <div class="overflow-y-auto max-h-48">
                          <table class="table table-xs">
                            <thead><tr><th>#</th><th>Name</th><th>Subscribed</th><th>Status</th></tr></thead>
                            <tbody>
                              <%= for ch <- Enum.sort_by(rx, & &1["index"]) do %>
                                <tr>
                                  <td class="font-mono"><%= ch["index"] %></td>
                                  <td><%= ch["name"] %></td>
                                  <td class="text-xs">
                                    <%= if ch["subscribedChannel"] && ch["subscribedChannel"] != "" do %>
                                      <span class="text-accent"><%= ch["subscribedChannel"] %></span>
                                      <span class="text-base-content/30">@</span>
                                      <span><%= ch["subscribedDevice"] %></span>
                                    <% else %>
                                      <span class="text-base-content/30">-</span>
                                    <% end %>
                                  </td>
                                  <td><.rx_status_badge summary={ch["summary"]} status={ch["status"]} /></td>
                                </tr>
                              <% end %>
                            </tbody>
                          </table>
                        </div>
                      <% end %>
                    </div>
                  </div>

                  <%!-- Actions --%>
                  <div class="divider"></div>
                  <div class="flex gap-2">
                    <button
                      class="btn btn-warning btn-sm"
                      phx-click="unenrol_device"
                      phx-value-device-id={dev["id"]}
                      data-confirm="Unenrol this device from the domain?"
                    >
                      Unenrol
                    </button>
                    <%= if get_in(dev, ["capabilities", "CAN_UNICAST_CLOCKING"]) do %>
                      <button
                        class="btn btn-ghost btn-sm"
                        phx-click="set_unicast_clocking"
                        phx-value-device-id={dev["id"]}
                        phx-value-enabled={to_string(!get_in(dev, ["clockPreferences", "unicastClocking"]))}
                      >
                        <%= if get_in(dev, ["clockPreferences", "unicastClocking"]) do %>
                          Disable Unicast Clocking
                        <% else %>
                          Enable Unicast Clocking
                        <% end %>
                      </button>
                    <% end %>
                  </div>
                </div>
              </div>
            <% else %>
              <div class="card bg-base-200 border border-base-300 shadow">
                <div class="card-body items-center text-center py-16">
                  <p class="text-base-content/40">Select a device to view details</p>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    <% end %>
    """
  end

  defp detail_row(assigns) do
    assigns = assign_new(assigns, :mono, fn -> false end)

    ~H"""
    <div class="flex justify-between">
      <span class="text-base-content/50"><%= @label %></span>
      <span class={"#{if @mono, do: "font-mono text-xs"} truncate max-w-[200px]"}><%= @value || "-" %></span>
    </div>
    """
  end

  defp rx_status_badge(assigns) do
    {badge_class, label} =
      case assigns.summary do
        "CONNECTED" -> {"badge-success", "OK"}
        "IN_PROGRESS" -> {"badge-warning", "..."}
        "WARNING" -> {"badge-warning", "!"}
        "ERROR" -> {"badge-error", "ERR"}
        _ -> {"badge-ghost", "-"}
      end

    assigns = assign(assigns, badge_class: badge_class, label: label)

    ~H"""
    <span class={"badge badge-xs #{@badge_class}"} title={@status}><%= @label %></span>
    """
  end

  defp connection_dot(device) do
    case get_in(device, ["connection", "state"]) do
      "READY" -> "bg-success"
      "ESTABLISHED" -> "bg-warning"
      _ -> "bg-error"
    end
  end

  defp enrolment_badge("ENROLLED"), do: "badge-success"
  defp enrolment_badge("ENROLLING"), do: "badge-warning"
  defp enrolment_badge("UNENROLLING"), do: "badge-warning"
  defp enrolment_badge(_), do: "badge-ghost"
end
