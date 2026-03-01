defmodule NetaudioWeb.DirectorLive.Domains do
  use NetaudioWeb, :live_view

  import NetaudioWeb.CoreComponents

  alias Netaudio.Director

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:domains, [])
      |> assign(:unenrolled_devices, [])
      |> assign(:loading, true)
      |> assign(:error, nil)
      |> assign(:current_path, "/director/domains")

    if connected?(socket) do
      send(self(), :load_data)
    end

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
  def handle_info(:load_data, socket) do
    unless Director.configured?() do
      socket =
        socket
        |> assign(:loading, false)
        |> assign(:error, :not_configured)

      {:noreply, socket}
    else
      domains_result = Director.list_domains()
      unenrolled_result = Director.list_unenrolled_devices()

      socket =
        case domains_result do
          {:ok, domains} ->
            unenrolled =
              case unenrolled_result do
                {:ok, devices} -> devices
                _ -> []
              end

            socket
            |> assign(:domains, domains)
            |> assign(:unenrolled_devices, unenrolled)
            |> assign(:loading, false)
            |> assign(:error, nil)

          {:error, reason} ->
            socket
            |> assign(:loading, false)
            |> assign(:error, reason)
        end

      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Director - Domains
      <:actions>
        <button class="btn btn-ghost btn-sm" phx-click="refresh">
          Refresh
        </button>
      </:actions>
    </.header>

    <%= if @loading do %>
      <div class="flex justify-center py-12">
        <span class="loading loading-spinner loading-lg text-primary"></span>
      </div>
    <% else %>
      <%= cond do %>
        <% @error == :not_configured -> %>
          <div class="alert alert-warning mb-6">
            <svg xmlns="http://www.w3.org/2000/svg" class="stroke-current shrink-0 h-6 w-6" fill="none" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z" />
            </svg>
            <div>
              <h3 class="font-bold">Director API not configured</h3>
              <p class="text-sm">Set your Director endpoint and API key to get started.</p>
            </div>
            <a href="/director/settings" class="btn btn-sm btn-primary">Configure</a>
          </div>

        <% @error -> %>
          <div class="alert alert-error mb-6">
            <span>Failed to load domains: <%= inspect(@error) %></span>
          </div>

        <% true -> %>
          <%!-- Domains --%>
          <%= if Enum.empty?(@domains) do %>
            <.empty_state>
              No domains found in Director.
            </.empty_state>
          <% else %>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mb-8">
              <%= for domain <- @domains do %>
                <a href={"/director/domains/#{domain["id"]}"} class="card bg-base-200 border border-base-300 shadow hover:border-primary transition-colors">
                  <div class="card-body p-5">
                    <h3 class="card-title text-base">
                      <span class="text-primary"><%= domain_icon(domain["icon"]) %></span>
                      <%= domain["name"] %>
                    </h3>
                    <div class="flex gap-2 mt-2">
                      <%= if domain["legacyInterop"] do %>
                        <span class="badge badge-sm badge-warning">Legacy Interop</span>
                      <% end %>
                    </div>
                  </div>
                </a>
              <% end %>
            </div>
          <% end %>

          <%!-- Unenrolled devices --%>
          <%= unless Enum.empty?(@unenrolled_devices) do %>
            <h3 class="text-lg font-semibold mb-3 flex items-center gap-2">
              <span class="badge badge-warning badge-sm"><%= length(@unenrolled_devices) %></span>
              Unenrolled Devices
            </h3>
            <div class="overflow-x-auto rounded-box border border-base-300 bg-base-200">
              <table class="table table-sm">
                <thead>
                  <tr class="border-b border-base-300">
                    <th class="text-xs uppercase">Name</th>
                    <th class="text-xs uppercase">Manufacturer</th>
                    <th class="text-xs uppercase">Product</th>
                    <th class="text-xs uppercase">Status</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for device <- @unenrolled_devices do %>
                    <tr class="hover">
                      <td class="font-medium"><%= device["name"] %></td>
                      <td class="text-sm text-base-content/60"><%= get_in(device, ["manufacturer", "name"]) || "-" %></td>
                      <td class="text-sm text-base-content/60"><%= get_in(device, ["product", "name"]) || "-" %></td>
                      <td>
                        <span class="badge badge-sm badge-warning">
                          <%= device["enrolmentState"] || "UNENROLLED" %>
                        </span>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
      <% end %>
    <% end %>
    """
  end

  defp domain_icon("BROADCAST"), do: "📡"
  defp domain_icon("RECORDING_STUDIO"), do: "🎙"
  defp domain_icon("HOUSE_OF_WORSHIP_1"), do: "⛪"
  defp domain_icon("HOUSE_OF_WORSHIP_2"), do: "🕌"
  defp domain_icon("HIGHER_EDUCATION"), do: "🎓"
  defp domain_icon("PRIMARY_EDUCATION"), do: "🏫"
  defp domain_icon("ARTS_VENUE"), do: "🎭"
  defp domain_icon("THEATRE_CINEMA"), do: "🎬"
  defp domain_icon("SPORTS_VENUE_1"), do: "🏟"
  defp domain_icon("SPORTS_VENUE_2"), do: "⚽"
  defp domain_icon("HOTEL_CASINO"), do: "🏨"
  defp domain_icon("HEALTH_CARE"), do: "🏥"
  defp domain_icon("OFFICE"), do: "🏢"
  defp domain_icon("COMMERCIAL"), do: "🏪"
  defp domain_icon(_), do: "🔊"
end
