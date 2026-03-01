defmodule NetaudioWeb.Api.DeviceController do
  use NetaudioWeb, :controller

  alias Netaudio.Dante.Browser
  alias Netaudio.Dante.{Device, Command}

  def index(conn, _params) do
    {:ok, devices} = Browser.get_devices()

    json(conn, %{
      data: Enum.map(devices, fn {_key, device} -> device_to_json(device) end)
    })
  end

  def show(conn, %{"id" => id}) do
    {:ok, devices} = Browser.get_devices()

    case Enum.find(devices, fn {key, _dev} -> key == id end) do
      {_key, device} ->
        json(conn, %{data: device_to_json(device)})

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Device not found"})
    end
  end

  def discover(conn, params) do
    timeout = Map.get(params, "timeout")
    timeout = if timeout, do: String.to_float(timeout), else: nil

    {:ok, devices} = Browser.discover(timeout)

    json(conn, %{
      data: Enum.map(devices, fn {_key, device} -> device_to_json(device) end),
      count: map_size(devices)
    })
  end

  def identify(conn, %{"id" => id}) do
    {:ok, devices} = Browser.get_devices()

    case Enum.find(devices, fn {key, _dev} -> key == id end) do
      {_key, device} ->
        {cmd, _service, port} = Command.identify()

        case Device.send_command(device.ipv4, port, cmd) do
          {:ok, _} ->
            json(conn, %{status: "ok", message: "Identify command sent to #{device.name}"})

          {:error, reason} ->
            conn
            |> put_status(:service_unavailable)
            |> json(%{error: "Failed to identify device: #{inspect(reason)}"})
        end

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Device not found"})
    end
  end

  defp device_to_json(device) do
    %{
      name: device.name,
      server_name: device.server_name,
      ipv4: device.ipv4,
      mac_address: device.mac_address,
      model: device.model,
      model_id: device.model_id,
      manufacturer: device.manufacturer,
      sample_rate: device.sample_rate,
      latency: device.latency,
      tx_count: device.tx_count,
      rx_count: device.rx_count
    }
  end
end
