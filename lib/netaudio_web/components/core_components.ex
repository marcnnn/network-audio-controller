defmodule NetaudioWeb.CoreComponents do
  @moduledoc """
  Provides core UI components for the Netaudio web interface.
  """

  use Phoenix.Component

  @doc """
  Renders a page header.
  """
  attr :class, :string, default: nil

  slot :inner_block, required: true
  slot :actions

  def header(assigns) do
    ~H"""
    <div class="md:flex md:items-center md:justify-between mb-8">
      <div class="min-w-0 flex-1">
        <h2 class={"text-2xl font-bold leading-7 text-white sm:truncate sm:text-3xl sm:tracking-tight #{@class}"}>
          <%= render_slot(@inner_block) %>
        </h2>
      </div>
      <div :if={@actions != []} class="mt-4 flex md:ml-4 md:mt-0 space-x-3">
        <%= render_slot(@actions) %>
      </div>
    </div>
    """
  end

  @doc """
  Renders a card container.
  """
  attr :class, :string, default: nil

  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <div class={"bg-gray-800 rounded-lg border border-gray-700 shadow-lg #{@class}"}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  @doc """
  Renders a status badge.
  """
  attr :status, :atom, required: true

  def status_badge(assigns) do
    {bg, text} =
      case assigns.status do
        :connected -> {"bg-green-900/50 border-green-700", "text-green-300"}
        :error -> {"bg-red-900/50 border-red-700", "text-red-300"}
        :warning -> {"bg-yellow-900/50 border-yellow-700", "text-yellow-300"}
        :idle -> {"bg-gray-700 border-gray-600", "text-gray-300"}
        _ -> {"bg-gray-700 border-gray-600", "text-gray-300"}
      end

    assigns = assign(assigns, bg: bg, text: text)

    ~H"""
    <span class={"inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-medium #{@bg} #{@text}"}>
      <%= status_label(@status) %>
    </span>
    """
  end

  defp status_label(:connected), do: "Connected"
  defp status_label(:error), do: "Error"
  defp status_label(:warning), do: "Warning"
  defp status_label(:idle), do: "Idle"
  defp status_label(_), do: "Unknown"

  @doc """
  Renders a button.
  """
  attr :type, :string, default: "button"
  attr :class, :string, default: nil
  attr :variant, :atom, default: :primary
  attr :rest, :global

  slot :inner_block, required: true

  def button(assigns) do
    base = "inline-flex items-center rounded-md px-3 py-2 text-sm font-semibold shadow-sm focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2"

    variant_classes =
      case assigns.variant do
        :primary -> "bg-indigo-600 text-white hover:bg-indigo-500 focus-visible:outline-indigo-600"
        :secondary -> "bg-gray-700 text-gray-300 hover:bg-gray-600"
        :danger -> "bg-red-600 text-white hover:bg-red-500 focus-visible:outline-red-600"
      end

    assigns = assign(assigns, :classes, "#{base} #{variant_classes} #{assigns.class}")

    ~H"""
    <button type={@type} class={@classes} {@rest}>
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  @doc """
  Renders a data table.
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true

  slot :col, required: true do
    attr :label, :string, required: true
  end

  def table(assigns) do
    ~H"""
    <div class="overflow-hidden rounded-lg border border-gray-700">
      <table class="min-w-full divide-y divide-gray-700">
        <thead class="bg-gray-800">
          <tr>
            <th :for={col <- @col} class="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-400">
              <%= col.label %>
            </th>
          </tr>
        </thead>
        <tbody id={@id} class="divide-y divide-gray-700 bg-gray-800/50">
          <tr :for={row <- @rows} class="hover:bg-gray-700/50 transition-colors">
            <td :for={col <- @col} class="whitespace-nowrap px-6 py-4 text-sm text-gray-300">
              <%= render_slot(col, row) %>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a stat card for the dashboard.
  """
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :icon, :string, default: nil

  def stat_card(assigns) do
    ~H"""
    <div class="bg-gray-800 rounded-lg border border-gray-700 p-6">
      <dt class="text-sm font-medium text-gray-400"><%= @label %></dt>
      <dd class="mt-2 text-3xl font-semibold tracking-tight text-white"><%= @value %></dd>
    </div>
    """
  end
end
