defmodule NetaudioWeb.Api.ChannelController do
  use NetaudioWeb, :controller

  alias Netaudio.Dante.Browser

  def index(conn, params) do
    {:ok, devices} = Browser.get_devices()
    device_name = Map.get(params, "device_name")

    channels =
      devices
      |> Enum.filter(fn {_key, dev} ->
        is_nil(device_name) || dev.name == device_name
      end)
      |> Enum.flat_map(fn {_key, device} ->
        tx =
          device.tx_channels
          |> Enum.map(fn {_num, ch} -> channel_to_json(ch, device.name) end)

        rx =
          device.rx_channels
          |> Enum.map(fn {_num, ch} -> channel_to_json(ch, device.name) end)

        tx ++ rx
      end)

    json(conn, %{data: channels})
  end

  defp channel_to_json(channel, device_name) do
    %{
      number: channel.number,
      name: channel.name,
      friendly_name: channel.friendly_name,
      channel_type: channel.channel_type,
      device_name: device_name,
      status_code: channel.status_code,
      volume: channel.volume
    }
  end
end
