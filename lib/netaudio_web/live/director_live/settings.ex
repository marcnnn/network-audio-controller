defmodule NetaudioWeb.DirectorLive.Settings do
  use NetaudioWeb, :live_view

  import NetaudioWeb.CoreComponents

  alias Netaudio.Director

  @impl true
  def mount(_params, _session, socket) do
    config = Application.get_env(:netaudio, Netaudio.Director.Client, [])

    socket =
      socket
      |> assign(:endpoint, Keyword.get(config, :endpoint, "") || "")
      |> assign(:api_key, Keyword.get(config, :api_key, "") || "")
      |> assign(:testing, false)
      |> assign(:connection_status, nil)
      |> assign(:current_path, "/director/settings")

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, :current_path, URI.parse(uri).path)}
  end

  @impl true
  def handle_event("save", %{"endpoint" => endpoint, "api_key" => api_key}, socket) do
    Application.put_env(:netaudio, Netaudio.Director.Client,
      endpoint: if(endpoint == "", do: nil, else: endpoint),
      api_key: if(api_key == "", do: nil, else: api_key)
    )

    socket =
      socket
      |> assign(:endpoint, endpoint)
      |> assign(:api_key, api_key)
      |> assign(:connection_status, nil)
      |> put_flash(:info, "Director API settings saved.")

    {:noreply, socket}
  end

  @impl true
  def handle_event("test", _params, socket) do
    socket = assign(socket, :testing, true)
    send(self(), :do_test)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:do_test, socket) do
    endpoint = socket.assigns.endpoint
    api_key = socket.assigns.api_key

    result =
      if endpoint != "" && api_key != "" do
        Director.test_connection(endpoint, api_key)
      else
        {:error, :not_configured}
      end

    status =
      case result do
        :ok -> :connected
        {:ok, _} -> :connected
        {:error, :unauthorized} -> :unauthorized
        {:error, :forbidden} -> :forbidden
        {:error, :not_configured} -> :not_configured
        {:error, {:http_error, reason}} -> {:http_error, reason}
        {:error, _} -> :error
      end

    socket =
      socket
      |> assign(:testing, false)
      |> assign(:connection_status, status)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Director API Settings
    </.header>

    <div class="max-w-2xl">
      <div class="card bg-base-200 border border-base-300 shadow">
        <div class="card-body">
          <p class="text-sm text-base-content/60 mb-4">
            Connect to Dante Director or Dante Domain Manager to manage devices,
            domains, and subscriptions via the Managed API.
            API keys are generated in Director under
            <span class="font-mono text-xs">Settings &gt; API Keys</span>.
          </p>

          <form phx-submit="save" class="space-y-4">
            <div class="form-control">
              <label class="label">
                <span class="label-text">GraphQL Endpoint URL</span>
              </label>
              <input
                type="url"
                name="endpoint"
                value={@endpoint}
                placeholder="https://your-director-server.example.com/graphql"
                class="input input-bordered w-full font-mono text-sm"
              />
              <label class="label">
                <span class="label-text-alt text-base-content/40">
                  The full URL to the Dante Managed API GraphQL endpoint
                </span>
              </label>
            </div>

            <div class="form-control">
              <label class="label">
                <span class="label-text">API Key</span>
              </label>
              <input
                type="password"
                name="api_key"
                value={@api_key}
                placeholder="Enter your API key..."
                class="input input-bordered w-full font-mono text-sm"
              />
              <label class="label">
                <span class="label-text-alt text-base-content/40">
                  Generated in Director: Settings &gt; API Keys &gt; Add Service Key
                </span>
              </label>
            </div>

            <div class="flex items-center gap-3 pt-2">
              <button type="submit" class="btn btn-primary btn-sm">Save</button>
              <button type="button" class="btn btn-ghost btn-sm" phx-click="test">
                <%= if @testing do %>
                  <span class="loading loading-spinner loading-xs"></span>
                  Testing...
                <% else %>
                  Test Connection
                <% end %>
              </button>
            </div>
          </form>

          <%!-- Connection status --%>
          <%= if @connection_status do %>
            <div class="mt-4">
              <%= case @connection_status do %>
                <% :connected -> %>
                  <div class="alert alert-success">
                    <svg xmlns="http://www.w3.org/2000/svg" class="stroke-current shrink-0 h-5 w-5" fill="none" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    <span>Connected to Dante Director API.</span>
                  </div>
                <% :unauthorized -> %>
                  <div class="alert alert-error">
                    <span>Unauthorized (401). Check your API key.</span>
                  </div>
                <% :forbidden -> %>
                  <div class="alert alert-error">
                    <span>Forbidden (403). The API key may not have sufficient permissions.</span>
                  </div>
                <% :not_configured -> %>
                  <div class="alert alert-warning">
                    <span>Both endpoint URL and API key are required.</span>
                  </div>
                <% {:http_error, reason} -> %>
                  <div class="alert alert-error">
                    <span>Connection failed: <%= inspect(reason) %></span>
                  </div>
                <% _ -> %>
                  <div class="alert alert-error">
                    <span>Connection failed. Check the endpoint URL and API key.</span>
                  </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
