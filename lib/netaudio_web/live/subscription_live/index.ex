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
        <a href="/subscriptions/new" class="inline-flex items-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white hover:bg-indigo-500">
          Add Subscription
        </a>
      </:actions>
    </.header>

    <div class="mb-6">
      <form phx-change="filter">
        <select name="status" class="bg-gray-800 border border-gray-600 text-gray-300 rounded-md px-3 py-2 text-sm">
          <option value="all" selected={@filter == "all"}>All</option>
          <option value="active" selected={@filter == "active"}>Active Only</option>
          <option value="inactive" selected={@filter == "inactive"}>Inactive Only</option>
        </select>
      </form>
    </div>

    <%= if Enum.empty?(@subscriptions) do %>
      <.card>
        <div class="p-12 text-center">
          <p class="text-gray-400">No subscriptions found.</p>
        </div>
      </.card>
    <% else %>
      <.table id="subscriptions" rows={@subscriptions}>
        <:col :let={sub} label="RX Channel"><%= sub.rx_channel_name %></:col>
        <:col :let={sub} label="RX Device"><%= sub.rx_device_name %></:col>
        <:col :let={sub} label="TX Channel"><%= sub.tx_channel_name %></:col>
        <:col :let={sub} label="TX Device"><%= sub.tx_device_name %></:col>
        <:col :let={sub} label="Status">
          <% labels = Constants.subscription_status_label(sub.status_code) %>
          <span class={"text-xs font-medium #{status_color(sub.status_code)}"}><%= hd(labels) %></span>
        </:col>
      </.table>
    <% end %>
    """
  end

  defp status_color(code) when code in [9, 10, 14, 4], do: "text-green-400"
  defp status_color(code) when code in [1, 3, 7, 8], do: "text-yellow-400"
  defp status_color(code) when code in [0], do: "text-gray-400"
  defp status_color(_code), do: "text-red-400"
end
