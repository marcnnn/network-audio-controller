defmodule Netaudio.Dante.Subscription do
  @moduledoc """
  Ash resource representing a Dante audio subscription
  (connection between a TX channel and an RX channel).
  """

  use Ash.Resource,
    domain: Netaudio.Dante,
    data_layer: Ash.DataLayer.Ets

  alias Netaudio.Dante.Constants

  ets do
    table(:dante_subscriptions)
    private?(true)
  end

  attributes do
    uuid_primary_key :id

    attribute :rx_channel_name, :string
    attribute :rx_device_name, :string
    attribute :rx_channel_status_code, :integer
    attribute :tx_channel_name, :string
    attribute :tx_device_name, :string
    attribute :status_code, :integer
  end

  relationships do
    belongs_to :rx_device, Netaudio.Dante.Device do
      attribute_type :uuid
      allow_nil? true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [
        :rx_channel_name,
        :rx_device_name,
        :rx_channel_status_code,
        :tx_channel_name,
        :tx_device_name,
        :status_code
      ]
    end

    update :update do
      primary? true
      accept [:status_code, :rx_channel_status_code]
    end

    read :by_rx_device do
      argument :rx_device_name, :string, allow_nil?: false
      filter expr(rx_device_name == ^arg(:rx_device_name))
    end

    read :active do
      filter expr(status_code in [9, 10, 14])
    end
  end

  calculations do
    calculate :status_text, {:array, :string}, {Netaudio.Dante.Calculations.StatusText, field: :status_code}
    calculate :rx_channel_status_text, {:array, :string}, {Netaudio.Dante.Calculations.StatusText, field: :rx_channel_status_code}

    calculate :display_string, :string, {Netaudio.Dante.Calculations.SubscriptionDisplay, []}
  end

  code_interface do
    define :list, action: :read
    define :create, action: :create
    define :list_active, action: :active
    define :list_by_rx_device, action: :by_rx_device, args: [:rx_device_name]
  end
end
