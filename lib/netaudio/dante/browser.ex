defmodule Netaudio.Dante.Browser do
  @moduledoc """
  Discovers Dante devices on the network using mDNS (multicast DNS).
  Uses a GenServer to maintain state during discovery.
  """

  use GenServer
  require Logger

  alias Netaudio.Dante.{Constants, Device}

  defstruct devices: %{},
            services: [],
            mdns_timeout: 3.0

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Discover Dante devices on the network.
  Returns a map of server_name => Device structs.
  """
  def discover(timeout \\ nil) do
    GenServer.call(__MODULE__, {:discover, timeout}, 30_000)
  end

  @doc """
  Get currently known devices without re-scanning.
  """
  def get_devices do
    GenServer.call(__MODULE__, :get_devices)
  end

  @doc """
  Refresh device details (channels, subscriptions) for all known devices.
  """
  def refresh_devices do
    GenServer.call(__MODULE__, :refresh_devices, 30_000)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    mdns_timeout =
      Keyword.get(opts, :mdns_timeout) ||
        Application.get_env(:netaudio, __MODULE__, [])
        |> Keyword.get(:mdns_timeout, 3.0)

    {:ok, %__MODULE__{mdns_timeout: mdns_timeout}}
  end

  @impl true
  def handle_call({:discover, timeout}, _from, state) do
    timeout = timeout || state.mdns_timeout
    devices = do_discover(timeout)
    state = %{state | devices: devices}
    {:reply, {:ok, devices}, state}
  end

  @impl true
  def handle_call(:get_devices, _from, state) do
    {:reply, {:ok, state.devices}, state}
  end

  @impl true
  def handle_call(:refresh_devices, _from, state) do
    devices =
      state.devices
      |> Enum.map(fn {key, device} ->
        case Device.get_controls(device) do
          {:ok, updated} -> {key, updated}
          {:error, updated} -> {key, updated}
        end
      end)
      |> Enum.into(%{})

    state = %{state | devices: devices}
    {:reply, {:ok, devices}, state}
  end

  # Private implementation

  defp do_discover(timeout) do
    # Use mDNS to discover Dante services
    # This performs UDP multicast queries for the Dante service types
    devices = %{}

    services =
      Constants.services()
      |> Enum.reject(&(&1 == Constants.service_chan()))
      |> Enum.flat_map(fn service_type ->
        query_mdns_service(service_type, timeout)
      end)

    # Group services by server name to build devices
    services
    |> Enum.group_by(& &1.server_name)
    |> Enum.reduce(devices, fn {server_name, device_services}, acc ->
      device = %Device{server_name: server_name}

      device =
        Enum.reduce(device_services, device, fn service, dev ->
          dev = %{dev | services: Map.put(dev.services, service.name, service_to_map(service))}
          dev = if is_nil(dev.ipv4), do: %{dev | ipv4: service.ipv4}, else: dev

          dev =
            if service.type == Constants.service_cmc() && service.mac_address do
              %{dev | mac_address: service.mac_address}
            else
              dev
            end

          dev = if service.model_id, do: %{dev | model_id: service.model_id}, else: dev

          dev =
            if service.sample_rate do
              %{dev | sample_rate: service.sample_rate}
            else
              dev
            end

          dev =
            if service.latency_ns do
              %{dev | latency: service.latency_ns}
            else
              dev
            end

          dev =
            if service.software do
              %{dev | software: service.software}
            else
              dev
            end

          dev
        end)

      Map.put(acc, server_name, device)
    end)
  end

  defp query_mdns_service(service_type, timeout) do
    # Build an mDNS query for the given service type
    # This uses raw UDP multicast to query for services
    mdns_addr = {224, 0, 0, 251}
    mdns_port = 5353

    query = build_mdns_query(service_type)

    case :gen_udp.open(0, [
           :binary,
           active: false,
           multicast_ttl: 255,
           multicast_loop: true,
           reuseaddr: true
         ]) do
      {:ok, socket} ->
        :gen_udp.send(socket, mdns_addr, mdns_port, query)
        services = collect_mdns_responses(socket, service_type, timeout)
        :gen_udp.close(socket)
        services

      {:error, reason} ->
        Logger.warning("Failed to open mDNS socket: #{inspect(reason)}")
        []
    end
  end

  defp collect_mdns_responses(socket, service_type, timeout) do
    deadline = System.monotonic_time(:millisecond) + round(timeout * 1000)
    collect_mdns_responses_loop(socket, service_type, deadline, [])
  end

  defp collect_mdns_responses_loop(socket, service_type, deadline, acc) do
    remaining = deadline - System.monotonic_time(:millisecond)

    if remaining <= 0 do
      acc
    else
      case :gen_udp.recv(socket, 0, remaining) do
        {:ok, {addr, _port, data}} ->
          case parse_mdns_response(data, service_type, addr) do
            {:ok, service} ->
              collect_mdns_responses_loop(socket, service_type, deadline, [service | acc])

            :skip ->
              collect_mdns_responses_loop(socket, service_type, deadline, acc)
          end

        {:error, :timeout} ->
          acc

        {:error, _} ->
          acc
      end
    end
  end

  defp build_mdns_query(service_type) do
    # Build a minimal DNS query packet for PTR record
    # Transaction ID (0), Flags (standard query), Questions (1), Answer/Auth/Additional (0)
    service_name = String.trim_trailing(service_type, ".")

    labels =
      service_name
      |> String.split(".")
      |> Enum.map(fn label ->
        <<byte_size(label)::8, label::binary>>
      end)
      |> Enum.join()

    # DNS header + question section
    <<
      0::16,
      0::16,
      1::16,
      0::16,
      0::16,
      0::16,
      labels::binary,
      0::8,
      12::16,
      1::16
    >>
  end

  defp parse_mdns_response(data, service_type, source_addr) do
    # Parse mDNS response to extract service information
    # This is a simplified parser - in production, use a proper DNS library
    try do
      {ip_a, ip_b, ip_c, ip_d} = source_addr
      ipv4 = "#{ip_a}.#{ip_b}.#{ip_c}.#{ip_d}"

      # Check if the response contains our service type
      service_name_part =
        service_type
        |> String.trim_trailing(".")
        |> String.split(".")
        |> hd()
        |> String.trim_leading("_")

      if String.contains?(data, service_name_part) do
        # Extract the server name from the response (simplified)
        server_name = extract_server_name(data) || "unknown-#{ipv4}"

        {:ok,
         %{
           name: "#{server_name}.#{service_type}",
           server_name: server_name,
           ipv4: ipv4,
           port: extract_port(data, service_type),
           type: service_type,
           mac_address: nil,
           model_id: nil,
           sample_rate: nil,
           latency_ns: nil,
           software: nil
         }}
      else
        :skip
      end
    rescue
      _ -> :skip
    end
  end

  defp extract_server_name(data) do
    # Try to extract a hostname from the DNS response
    # Look for printable ASCII sequences that look like hostnames
    data
    |> :binary.bin_to_list()
    |> Enum.chunk_while(
      [],
      fn byte, acc ->
        if byte >= 0x20 && byte <= 0x7E do
          {:cont, [byte | acc]}
        else
          if length(acc) > 2 do
            {:cont, acc, []}
          else
            {:cont, []}
          end
        end
      end,
      fn
        acc when length(acc) > 2 -> {:cont, acc, []}
        _acc -> {:cont, []}
      end
    )
    |> Enum.filter(&(length(&1) > 3))
    |> List.first()
    |> case do
      nil -> nil
      chars -> chars |> Enum.reverse() |> List.to_string()
    end
  end

  defp extract_port(_data, service_type) do
    # Return the default port for the service type
    cond do
      service_type == Constants.service_arc() -> Constants.device_control_port()
      service_type == Constants.service_cmc() -> Constants.device_control_port()
      service_type == Constants.service_dbc() -> Constants.device_info_port()
      true -> Constants.device_control_port()
    end
  end

  defp service_to_map(service) do
    %{
      "ipv4" => service.ipv4,
      "name" => service.name,
      "port" => service.port,
      "type" => service.type,
      "properties" => %{}
    }
  end
end
