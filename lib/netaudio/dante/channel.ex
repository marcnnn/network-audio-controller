defmodule Netaudio.Dante.Channel do
  @moduledoc """
  Ash resource representing a Dante audio channel (transmitter or receiver).
  """

  use Ash.Resource,
    domain: Netaudio.Dante,
    data_layer: Ash.DataLayer.Ets

  ets do
    table(:dante_channels)
    private?(true)
  end

  attributes do
    uuid_primary_key :id

    attribute :number, :integer, allow_nil?: false
    attribute :name, :string
    attribute :friendly_name, :string
    attribute :channel_type, :atom, constraints: [one_of: [:tx, :rx]], allow_nil?: false
    attribute :device_name, :string
    attribute :status_code, :integer
    attribute :volume, :integer
  end

  relationships do
    belongs_to :device, Netaudio.Dante.Device do
      attribute_type :uuid
      allow_nil? true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:number, :name, :friendly_name, :channel_type, :device_name, :status_code, :volume]

      change relate_actor(:device)
    end

    update :update do
      primary? true
      accept [:name, :friendly_name, :status_code, :volume]
    end
  end

  calculations do
    calculate :display_name, :string, expr(
      if is_nil(friendly_name), do: name, else: friendly_name
    )
  end

  code_interface do
    define :list, action: :read
    define :create, action: :create
    define :get_by_id, action: :read, get_by: [:id]
  end
end
