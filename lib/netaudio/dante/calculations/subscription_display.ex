defmodule Netaudio.Dante.Calculations.SubscriptionDisplay do
  @moduledoc """
  Ash calculation that builds the display string for a subscription.
  """

  use Ash.Resource.Calculation

  alias Netaudio.Dante.Constants

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def load(_query, _opts, _context) do
    []
  end

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record ->
      base =
        if record.tx_channel_name && record.tx_device_name do
          "#{record.rx_channel_name}@#{record.rx_device_name} <- #{record.tx_channel_name}@#{record.tx_device_name}"
        else
          "#{record.rx_channel_name}@#{record.rx_device_name}"
        end

      status_labels = Constants.subscription_status_label(record.status_code)

      all_labels =
        if record.rx_channel_status_code &&
             Map.has_key?(Constants.subscription_status_labels(), record.rx_channel_status_code) do
          status_labels ++ Constants.subscription_status_label(record.rx_channel_status_code)
        else
          status_labels
        end

      "#{base} [#{Enum.join(all_labels, ", ")}]"
    end)
  end
end
