defmodule NetaudioWeb.CoreComponents do
  @moduledoc """
  Core UI components using DaisyUI classes.
  """

  use Phoenix.Component

  # Page header

  attr :class, :string, default: nil
  slot :inner_block, required: true
  slot :actions

  def header(assigns) do
    ~H"""
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
      <h2 class={"text-2xl font-bold text-base-content #{@class}"}>
        <%= render_slot(@inner_block) %>
      </h2>
      <div :if={@actions != []} class="flex flex-wrap gap-2">
        <%= render_slot(@actions) %>
      </div>
    </div>
    """
  end

  # Stat card for dashboard

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :desc, :string, default: nil
  attr :class, :string, default: nil

  def stat_card(assigns) do
    ~H"""
    <div class={"stat bg-base-200 rounded-box shadow #{@class}"}>
      <div class="stat-title text-base-content/60"><%= @label %></div>
      <div class="stat-value text-primary"><%= @value %></div>
      <div :if={@desc} class="stat-desc"><%= @desc %></div>
    </div>
    """
  end

  # Status badge using DaisyUI badge

  attr :status, :atom, required: true

  def status_badge(assigns) do
    badge_class =
      case assigns.status do
        :connected -> "badge-success"
        :error -> "badge-error"
        :warning -> "badge-warning"
        :idle -> "badge-ghost"
        _ -> "badge-ghost"
      end

    assigns = assign(assigns, :badge_class, badge_class)

    ~H"""
    <span class={"badge badge-sm #{@badge_class}"}>
      <%= status_label(@status) %>
    </span>
    """
  end

  defp status_label(:connected), do: "Connected"
  defp status_label(:error), do: "Error"
  defp status_label(:warning), do: "Warning"
  defp status_label(:idle), do: "Idle"
  defp status_label(_), do: "Unknown"

  # Subscription status badge

  attr :code, :integer, required: true

  def sub_status_badge(assigns) do
    {badge_class, icon} =
      cond do
        assigns.code in [9, 10, 14, 4] -> {"badge-success", "✓"}
        assigns.code in [1, 3, 7, 8] -> {"badge-warning", "!"}
        assigns.code in [0] -> {"badge-ghost", "-"}
        true -> {"badge-error", "✕"}
      end

    labels = Netaudio.Dante.Constants.subscription_status_label(assigns.code)
    label = if labels != [], do: hd(labels), else: "Unknown"

    assigns = assign(assigns, badge_class: badge_class, icon: icon, label: label)

    ~H"""
    <span class={"badge badge-sm gap-1 #{@badge_class}"}>
      <span><%= @icon %></span>
      <%= @label %>
    </span>
    """
  end

  # Data table using DaisyUI table

  attr :id, :string, required: true
  attr :rows, :list, required: true

  slot :col, required: true do
    attr :label, :string, required: true
  end

  def table(assigns) do
    ~H"""
    <div class="overflow-x-auto rounded-box border border-base-300 bg-base-200">
      <table class="table table-sm">
        <thead>
          <tr class="border-b border-base-300">
            <th :for={col <- @col} class="text-base-content/60 font-medium text-xs uppercase tracking-wider">
              <%= col.label %>
            </th>
          </tr>
        </thead>
        <tbody id={@id}>
          <tr :for={row <- @rows} class="hover">
            <td :for={col <- @col} class="text-sm">
              <%= render_slot(col, row) %>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  # Empty state placeholder

  attr :icon, :string, default: nil
  slot :inner_block, required: true
  slot :action

  def empty_state(assigns) do
    ~H"""
    <div class="card bg-base-200 border border-base-300">
      <div class="card-body items-center text-center py-12">
        <p class="text-base-content/50"><%= render_slot(@inner_block) %></p>
        <div :if={@action != []} class="card-actions mt-4">
          <%= render_slot(@action) %>
        </div>
      </div>
    </div>
    """
  end
end
