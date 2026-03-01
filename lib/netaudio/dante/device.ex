defmodule Netaudio.Dante.Device do
  @moduledoc """
  Ash resource representing a Dante network audio device.
  """

  use Ash.Resource,
    domain: Netaudio.Dante,
    data_layer: Ash.DataLayer.Ets

  alias Netaudio.Dante.{Command, Constants}

  ets do
    table(:dante_devices)
    private?(true)
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string, allow_nil?: false
    attribute :server_name, :string, allow_nil?: false
    attribute :ipv4, :string
    attribute :mac_address, :string
    attribute :model, :string
    attribute :model_id, :string
    attribute :dante_model, :string
    attribute :dante_model_id, :string
    attribute :manufacturer, :string
    attribute :sample_rate, :integer
    attribute :latency, :integer
    attribute :software, :string
    attribute :tx_count, :integer, default: 0
    attribute :rx_count, :integer, default: 0
    attribute :services, :map, default: %{}
    attribute :error, :string
  end

  relationships do
    has_many :channels, Netaudio.Dante.Channel
    has_many :subscriptions, Netaudio.Dante.Subscription, destination_attribute: :rx_device_id
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [
        :name, :server_name, :ipv4, :mac_address, :model, :model_id,
        :dante_model, :dante_model_id, :manufacturer, :sample_rate,
        :latency, :software, :tx_count, :rx_count, :services, :error
      ]
    end

    update :update do
      primary? true
      accept [
        :name, :ipv4, :mac_address, :model, :model_id,
        :dante_model, :dante_model_id, :manufacturer, :sample_rate,
        :latency, :software, :tx_count, :rx_count, :services, :error
      ]
    end

    read :by_name do
      argument :name, :string, allow_nil?: false
      filter expr(name == ^arg(:name))
    end

    read :by_server_name do
      argument :server_name, :string, allow_nil?: false
      filter expr(server_name == ^arg(:server_name))
    end
  end

  code_interface do
    define :list, action: :read
    define :create, action: :create
    define :update, action: :update
    define :get_by_id, action: :read, get_by: [:id]
    define :get_by_name, action: :by_name, args: [:name]
    define :get_by_server_name, action: :by_server_name, args: [:server_name]
  end

  # Protocol functions that operate on device data

  @doc """
  Parse a label from a hex response string at the given hex offset.
  """
  def get_label(hex_str, offset) when is_binary(offset) do
    try do
      offset_int = String.to_integer(offset, 16) * 2
      hex_substring = String.slice(hex_str, offset_int..-1//1)
      bytes = Base.decode16!(hex_substring, case: :mixed)

      bytes
      |> :binary.split(<<0>>)
      |> hd()
    rescue
      _ -> nil
    end
  end

  @doc """
  Send a UDP command to a device and return the response.
  """
  def send_command(ipv4, port, command_hex) when is_binary(ipv4) and is_integer(port) do
    binary = Base.decode16!(command_hex, case: :mixed)
    {:ok, ip} = :inet.parse_address(String.to_charlist(ipv4))

    case :gen_udp.open(0, [:binary, active: false]) do
      {:ok, socket} ->
        :gen_udp.send(socket, ip, port, binary)

        result =
          case :gen_udp.recv(socket, 0, 1000) do
            {:ok, {_addr, _port, data}} -> {:ok, data}
            {:error, :timeout} -> {:error, :timeout}
            {:error, reason} -> {:error, reason}
          end

        :gen_udp.close(socket)
        result

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Resolve the port for a service type from the device's services map.
  """
  def resolve_service_port(services, service_type) do
    services
    |> Enum.find_value(fn
      {_name, %{"type" => ^service_type, "port" => port}} -> port
      _ -> nil
    end)
  end

  @doc """
  Query the device for its name via the Dante protocol.
  """
  def query_device_name(ipv4, services) do
    {cmd, service_type} = Command.device_name()
    port = resolve_service_port(services, service_type)

    if port do
      case send_command(ipv4, port, cmd) do
        {:ok, response} ->
          name =
            binary_part(response, 10, byte_size(response) - 11)
            |> to_string()
            |> String.trim_trailing(<<0>>)

          {:ok, name}

        error ->
          error
      end
    else
      {:error, :no_service_port}
    end
  end

  @doc """
  Query channel counts from the device.
  """
  def query_channel_count(ipv4, services) do
    {cmd, service_type} = Command.channel_count()
    port = resolve_service_port(services, service_type)

    if port do
      case send_command(ipv4, port, cmd) do
        {:ok, response} ->
          <<_header::binary-size(13), tx_count::8, _::8, rx_count::8, _rest::binary>> = response
          {:ok, tx_count, rx_count}

        error ->
          error
      end
    else
      {:error, :no_service_port}
    end
  end

  @doc """
  Query TX channels from the device.
  Returns a list of channel attribute maps ready for Ash create.
  """
  def query_tx_channels(ipv4, services, device_name, tx_count) do
    friendly_names = query_tx_friendly_names(ipv4, services, tx_count)

    channels =
      0..max(0, div(tx_count, 16) - 1)//2
      |> Enum.flat_map(fn page ->
        {cmd, service_type} = Command.transmitters(page, false)
        port = resolve_service_port(services, service_type)

        if port do
          case send_command(ipv4, port, cmd) do
            {:ok, response} ->
              hex = Base.encode16(response, case: :lower)
              parse_tx_channel_page(hex, tx_count, device_name, friendly_names)

            _ ->
              []
          end
        else
          []
        end
      end)

    {:ok, channels}
  end

  @doc """
  Query RX channels and subscriptions from the device.
  Returns channel attrs and subscription attrs.
  """
  def query_rx_channels(ipv4, services, device_name, rx_count) do
    results =
      0..max(0, div(rx_count, 16))//1
      |> Enum.flat_map(fn page ->
        {cmd, service_type} = Command.receivers(page)
        port = resolve_service_port(services, service_type)

        if port do
          case send_command(ipv4, port, cmd) do
            {:ok, response} ->
              hex = Base.encode16(response, case: :lower)
              parse_rx_channel_page(hex, rx_count, device_name)

            _ ->
              []
          end
        else
          []
        end
      end)

    channels = Enum.map(results, fn {ch, _sub, _sr} -> ch end)
    subs = Enum.map(results, fn {_ch, sub, _sr} -> sub end)
    sample_rate = Enum.find_value(results, fn {_ch, _sub, sr} -> sr end)

    {:ok, channels, subs, sample_rate}
  end

  defp query_tx_friendly_names(ipv4, services, tx_count) do
    0..max(0, div(tx_count, 16) - 1)//2
    |> Enum.reduce(%{}, fn page, acc ->
      {cmd, service_type} = Command.transmitters(page, true)
      port = resolve_service_port(services, service_type)

      if port do
        case send_command(ipv4, port, cmd) do
          {:ok, response} ->
            hex = Base.encode16(response, case: :lower)

            Enum.reduce(0..min(tx_count - 1, 31), acc, fn index, acc2 ->
              start = 24 + index * 12
              str1 = String.slice(hex, start, 12)

              if String.length(str1) == 12 do
                parts = for i <- 0..2, do: String.slice(str1, i * 4, 4)
                channel_number = String.to_integer(Enum.at(parts, 1), 16)
                channel_offset = Enum.at(parts, 2)
                friendly_name = get_label(hex, channel_offset)

                if friendly_name, do: Map.put(acc2, channel_number, friendly_name), else: acc2
              else
                acc2
              end
            end)

          _ ->
            acc
        end
      else
        acc
      end
    end)
  end

  defp parse_tx_channel_page(hex, tx_count, device_name, friendly_names) do
    {channels, _} =
      Enum.reduce_while(0..min(tx_count - 1, 31), {[], nil}, fn index, {acc, first_group} ->
        start = 24 + index * 16
        str1 = String.slice(hex, start, 16)

        if String.length(str1) == 16 do
          parts = for i <- 0..3, do: String.slice(str1, i * 4, 4)
          channel_number = String.to_integer(Enum.at(parts, 0), 16)
          channel_group = Enum.at(parts, 2)
          channel_offset = Enum.at(parts, 3)
          first_group = first_group || channel_group

          if channel_group != first_group do
            {:halt, {acc, first_group}}
          else
            name = get_label(hex, channel_offset)

            channel_attrs = %{
              number: channel_number,
              name: name,
              friendly_name: Map.get(friendly_names, channel_number),
              channel_type: :tx,
              device_name: device_name
            }

            {:cont, {[channel_attrs | acc], first_group}}
          end
        else
          {:halt, {acc, first_group}}
        end
      end)

    Enum.reverse(channels)
  end

  defp parse_rx_channel_page(hex, rx_count, device_name) do
    Enum.reduce(0..min(rx_count - 1, 15), [], fn index, acc ->
      start = 24 + index * 40
      str1 = String.slice(hex, start, 32)

      if String.length(str1) == 32 do
        parts = for i <- 0..7, do: String.slice(str1, i * 4, 4)

        channel_number = String.to_integer(Enum.at(parts, 0), 16)
        channel_offset = Enum.at(parts, 3)
        device_offset = Enum.at(parts, 4)
        rx_channel_offset = Enum.at(parts, 5)
        rx_channel_status_code = String.to_integer(Enum.at(parts, 6), 16)
        subscription_status_code = String.to_integer(Enum.at(parts, 7), 16)

        rx_channel_name = get_label(hex, rx_channel_offset)
        tx_device_name = get_label(hex, device_offset)
        tx_channel_name = if channel_offset != "0000", do: get_label(hex, channel_offset), else: rx_channel_name

        sample_rate =
          if index == 0 && device_offset != "0000" do
            o1 = String.to_integer(Enum.at(parts, 2), 16) * 2 + 2
            sr_hex = String.slice(hex, o1, 6)

            case Integer.parse(sr_hex, 16) do
              {sr_val, _} when sr_val > 0 -> sr_val
              _ -> nil
            end
          end

        resolved_tx_device = if tx_device_name == ".", do: device_name, else: tx_device_name

        channel_attrs = %{
          number: channel_number,
          name: rx_channel_name,
          channel_type: :rx,
          device_name: device_name,
          status_code: rx_channel_status_code
        }

        sub_attrs = %{
          rx_channel_name: rx_channel_name,
          rx_device_name: device_name,
          tx_channel_name: tx_channel_name,
          tx_device_name: resolved_tx_device,
          status_code: subscription_status_code,
          rx_channel_status_code: rx_channel_status_code
        }

        [{channel_attrs, sub_attrs, sample_rate} | acc]
      else
        acc
      end
    end)
    |> Enum.reverse()
  end
end
