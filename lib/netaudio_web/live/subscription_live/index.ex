defmodule NetaudioWeb.SubscriptionLive.Index do
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
      |> assign(:filter, "all")
      |> assign(:current_path, "/subscriptions")
      |> compute_subscriptions()

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, :current_path, URI.parse(uri).path)}
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    socket =
      socket
      |> assign(:filter, status)
      |> compute_subscriptions()

    {:noreply, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:ok, devices} = Browser.get_devices()

    socket =
      socket
      |> assign(:devices, devices)
      |> compute_subscriptions()

    {:noreply, socket}
  end

  defp compute_subscriptions(socket) do
    devices = socket.assigns.devices
    filter = socket.assigns.filter

    subscriptions =
      devices
      |> Enum.flat_map(fn {_key, device} -> device.subscriptions end)
      |> Enum.filter(fn sub ->
        case filter do
          "all" -> true
          "active" -> sub.status_code in [9, 10, 14, 4]
          "inactive" -> sub.status_code not in [9, 10, 14, 4]
          _ -> true
        end
      end)
      |> Enum.sort_by(fn sub -> {sub.rx_device_name, sub.rx_channel_name} end)

    assign(socket, :subscriptions, subscriptions)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Subscriptions
      <:actions>
        <a href="/subscriptions/new" class="btn btn-primary btn-sm gap-1">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" clip-rule="evenodd" />
          </svg>
          Add
        </a>
      </:actions>
    </.header>

    <%!-- Filters --%>
    <div class="flex items-center gap-3 mb-5">
      <form phx-change="filter">
        <div class="join">
          <input class="join-item btn btn-sm" type="radio" name="status" value="all" aria-label="All" checked={@filter == "all"} />
          <input class="join-item btn btn-sm" type="radio" name="status" value="active" aria-label="Active" checked={@filter == "active"} />
          <input class="join-item btn btn-sm" type="radio" name="status" value="inactive" aria-label="Inactive" checked={@filter == "inactive"} />
        </div>
      </form>
      <div class="badge badge-ghost badge-lg">
        <%= length(@subscriptions) %> subscription(s)
      </div>
    </div>

    <%= if Enum.empty?(@subscriptions) do %>
      <.empty_state>
        No subscriptions found.
        <:action>
          <a href="/subscriptions/new" class="btn btn-primary btn-sm">Add Subscription</a>
        </:action>
      </.empty_state>
    <% else %>
      <div class="overflow-x-auto rounded-box border border-base-300 bg-base-200">
        <table class="table table-sm">
          <thead>
            <tr class="border-b border-base-300">
              <th class="text-xs uppercase tracking-wider text-base-content/60">RX Channel</th>
              <th class="text-xs uppercase tracking-wider text-base-content/60">RX Device</th>
              <th class="text-xs uppercase tracking-wider text-base-content/60"></th>
              <th class="text-xs uppercase tracking-wider text-base-content/60">TX Channel</th>
              <th class="text-xs uppercase tracking-wider text-base-content/60">TX Device</th>
              <th class="text-xs uppercase tracking-wider text-base-content/60">Status</th>
            </tr>
          </thead>
          <tbody>
            <%= for sub <- @subscriptions do %>
              <tr class="hover">
                <td class="font-mono text-xs text-info"><%= sub.rx_channel_name %></td>
                <td class="text-sm"><%= sub.rx_device_name %></td>
                <td class="text-center text-base-content/30">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3 inline" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M7.707 14.707a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 1.414L5.414 9H17a1 1 0 110 2H5.414l2.293 2.293a1 1 0 010 1.414z" clip-rule="evenodd" />
                  </svg>
                </td>
                <td class="font-mono text-xs text-accent"><%= sub.tx_channel_name %></td>
                <td class="text-sm"><%= sub.tx_device_name %></td>
                <td><.sub_status_badge code={sub.status_code} /></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    <% end %>
    """
  end
end
