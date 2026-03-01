defmodule NetaudioWeb.Api.SubscriptionController do
  use NetaudioWeb, :controller

  alias Netaudio.Dante.{Browser, Command, Device, Constants}

  def index(conn, _params) do
    {:ok, devices} = Browser.get_devices()

    subscriptions =
      devices
      |> Enum.flat_map(fn {_key, device} ->
        Enum.map(device.subscriptions, fn sub ->
          %{
            rx_channel: sub.rx_channel_name,
            rx_device: sub.rx_device_name,
            tx_channel: sub.tx_channel_name,
            tx_device: sub.tx_device_name,
            status_code: sub.status_code,
            status_text: Constants.subscription_status_label(sub.status_code)
          }
        end)
      end)

    json(conn, %{data: subscriptions})
  end

  def create(conn, %{
        "tx_device_name" => tx_device_name,
        "tx_channel_name" => tx_channel_name,
        "rx_device_name" => rx_device_name,
        "rx_channel_name" => rx_channel_name
      }) do
    {:ok, devices} = Browser.get_devices()

    rx_device = Enum.find_value(devices, fn {_k, d} -> if d.name == rx_device_name, do: d end)

    if rx_device do
      rx_channel =
        Enum.find_value(rx_device.rx_channels, fn {_num, ch} ->
          if ch.name == rx_channel_name, do: ch
        end)

      if rx_channel do
        {cmd, service_type} = Command.add_subscription(rx_channel.number, tx_channel_name, tx_device_name)
        port = Device.resolve_service_port(rx_device.services, service_type)

        if port do
          case Device.send_command(rx_device.ipv4, port, cmd) do
            {:ok, _} ->
              json(conn, %{status: "ok", message: "Subscription added"})

            {:error, reason} ->
              conn
              |> put_status(:service_unavailable)
              |> json(%{error: "Failed to add subscription: #{inspect(reason)}"})
          end
        else
          conn
          |> put_status(:service_unavailable)
          |> json(%{error: "No ARC service port found for device"})
        end
      else
        conn |> put_status(:not_found) |> json(%{error: "RX channel not found"})
      end
    else
      conn |> put_status(:not_found) |> json(%{error: "RX device not found"})
    end
  end

  def delete(conn, %{"id" => _id} = params) do
    rx_device_name = Map.get(params, "rx_device_name")
    rx_channel_name = Map.get(params, "rx_channel_name")

    {:ok, devices} = Browser.get_devices()
    rx_device = Enum.find_value(devices, fn {_k, d} -> if d.name == rx_device_name, do: d end)

    if rx_device do
      rx_channel =
        Enum.find_value(rx_device.rx_channels, fn {_num, ch} ->
          if ch.name == rx_channel_name, do: ch
        end)

      if rx_channel do
        {cmd, service_type} = Command.remove_subscription(rx_channel.number)
        port = Device.resolve_service_port(rx_device.services, service_type)

        if port do
          case Device.send_command(rx_device.ipv4, port, cmd) do
            {:ok, _} ->
              json(conn, %{status: "ok", message: "Subscription removed"})

            {:error, reason} ->
              conn
              |> put_status(:service_unavailable)
              |> json(%{error: "Failed to remove subscription: #{inspect(reason)}"})
          end
        else
          conn
          |> put_status(:service_unavailable)
          |> json(%{error: "No ARC service port found"})
        end
      else
        conn |> put_status(:not_found) |> json(%{error: "RX channel not found"})
      end
    else
      conn |> put_status(:not_found) |> json(%{error: "RX device not found"})
    end
  end
end
