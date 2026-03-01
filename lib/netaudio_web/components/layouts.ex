defmodule NetaudioWeb.Layouts do
  use NetaudioWeb, :html

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en" class="h-full bg-gray-900">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={get_csrf_token()} />
        <title>Netaudio - Dante Network Audio Controller</title>
        <link rel="stylesheet" href="/assets/app.css" />
        <script defer src="/assets/app.js"></script>
      </head>
      <body class="h-full bg-gray-900 text-gray-100">
        <%= @inner_content %>
      </body>
    </html>
    """
  end

  def app(assigns) do
    ~H"""
    <div class="min-h-full">
      <nav class="bg-gray-800 border-b border-gray-700">
        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div class="flex h-16 items-center justify-between">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <span class="text-xl font-bold text-indigo-400">Netaudio</span>
              </div>
              <div class="ml-10 flex items-baseline space-x-4">
                <.nav_link href="/" current={@current_path == "/"}>Dashboard</.nav_link>
                <.nav_link href="/devices" current={String.starts_with?(@current_path || "", "/devices")}>Devices</.nav_link>
                <.nav_link href="/channels" current={@current_path == "/channels"}>Channels</.nav_link>
                <.nav_link href="/subscriptions" current={String.starts_with?(@current_path || "", "/subscriptions")}>Subscriptions</.nav_link>
              </div>
            </div>
          </div>
        </div>
      </nav>

      <main>
        <div class="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">
          <%= if Phoenix.Flash.get(@flash, :info) do %>
            <div class="mb-4 rounded-md bg-green-900/50 border border-green-700 p-4">
              <p class="text-sm text-green-300"><%= Phoenix.Flash.get(@flash, :info) %></p>
            </div>
          <% end %>
          <%= if Phoenix.Flash.get(@flash, :error) do %>
            <div class="mb-4 rounded-md bg-red-900/50 border border-red-700 p-4">
              <p class="text-sm text-red-300"><%= Phoenix.Flash.get(@flash, :error) %></p>
            </div>
          <% end %>
          <%= @inner_content %>
        </div>
      </main>
    </div>
    """
  end

  defp nav_link(assigns) do
    base_classes = "rounded-md px-3 py-2 text-sm font-medium"

    classes =
      if assigns[:current] do
        "#{base_classes} bg-gray-900 text-white"
      else
        "#{base_classes} text-gray-300 hover:bg-gray-700 hover:text-white"
      end

    assigns = assign(assigns, :classes, classes)

    ~H"""
    <a href={@href} class={@classes}><%= render_slot(@inner_block) %></a>
    """
  end

  # Provide current_path default
  def on_mount(:default, _params, _session, socket) do
    {:cont,
     Phoenix.LiveView.attach_hook(socket, :current_path, :handle_params, fn _params, url, socket ->
       uri = URI.parse(url)
       {:cont, Phoenix.Component.assign(socket, :current_path, uri.path)}
     end)}
  end
end
