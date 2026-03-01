defmodule Netaudio.Director do
  @moduledoc """
  High-level interface to the Dante Director / DDM Managed API.

  Provides functions to query domains, devices, channels, and manage
  subscriptions via the Dante Managed API (GraphQL).

  ## Configuration

      config :netaudio, Netaudio.Director.Client,
        endpoint: "https://my-ddm-server.example.com/graphql",
        api_key: "my-api-key"
  """

  alias Netaudio.Director.{Client, Queries}

  # ── Connection ──

  @doc "Check if the Director API is configured."
  defdelegate configured?, to: Client

  @doc "Test the connection to the Director API."
  defdelegate test_connection, to: Client

  @doc "Test with specific endpoint and API key."
  def test_connection(endpoint, api_key) do
    Client.test_connection(endpoint: endpoint, api_key: api_key)
  end

  # ── Domains ──

  @doc """
  List all domains.
  Returns `{:ok, [domain]}` or `{:error, reason}`.
  """
  def list_domains do
    case Client.query(Queries.list_domains()) do
      {:ok, %{"domains" => domains}} -> {:ok, domains}
      error -> error
    end
  end

  @doc """
  Get a domain by ID or name, including its devices.
  """
  def get_domain(opts) when is_list(opts) do
    vars =
      %{}
      |> maybe_put("id", opts[:id])
      |> maybe_put("name", opts[:name])

    case Client.query(Queries.get_domain(), vars) do
      {:ok, %{"domain" => domain}} -> {:ok, domain}
      error -> error
    end
  end

  def get_domain(id) when is_binary(id) do
    get_domain(id: id)
  end

  @doc """
  Get a domain with full channel details for all devices.
  """
  def get_domain_with_channels(opts) when is_list(opts) do
    vars =
      %{}
      |> maybe_put("id", opts[:id])
      |> maybe_put("name", opts[:name])

    case Client.query(Queries.get_domain_with_channels(), vars) do
      {:ok, %{"domain" => domain}} -> {:ok, domain}
      error -> error
    end
  end

  # ── Devices ──

  @doc """
  Get a specific device within a domain.
  """
  def get_device(domain_id, device_id) do
    vars = %{"domainId" => domain_id, "deviceId" => device_id}

    case Client.query(Queries.get_device(), vars) do
      {:ok, %{"domain" => %{"device" => device}}} -> {:ok, device}
      {:ok, %{"domain" => %{"device" => nil}}} -> {:error, :not_found}
      error -> error
    end
  end

  @doc """
  List all unenrolled devices on the network.
  """
  def list_unenrolled_devices do
    case Client.query(Queries.list_unenrolled_devices()) do
      {:ok, %{"unenrolledDevices" => devices}} -> {:ok, devices}
      error -> error
    end
  end

  @doc """
  Get the routing state (devices + channels + subscriptions) for a domain.
  Used for the routing matrix view.
  """
  def get_routing_state(opts) when is_list(opts) do
    vars =
      %{}
      |> maybe_put("domainId", opts[:id])
      |> maybe_put("domainName", opts[:name])

    case Client.query(Queries.get_routing_state(), vars) do
      {:ok, %{"domain" => domain}} -> {:ok, domain}
      error -> error
    end
  end

  @doc """
  Get clocking state for all devices in a domain.
  """
  def get_clocking_state(opts) when is_list(opts) do
    vars =
      %{}
      |> maybe_put("domainId", opts[:id])
      |> maybe_put("domainName", opts[:name])

    case Client.query(Queries.get_clocking_state(), vars) do
      {:ok, %{"domain" => domain}} -> {:ok, domain}
      error -> error
    end
  end

  # ── Subscriptions ──

  @doc """
  Set one or more RX channel subscriptions on a device.

  ## Examples

      # Subscribe RX channel 1 to TX channel "Main L" on device "Mixer"
      Director.set_subscriptions("device-id-123", [
        %{rx_channel_index: 1, subscribed_device: "Mixer", subscribed_channel: "Main L"}
      ])

      # Clear a subscription (unsubscribe)
      Director.set_subscriptions("device-id-123", [
        %{rx_channel_index: 1, subscribed_device: "", subscribed_channel: ""}
      ])
  """
  def set_subscriptions(device_id, subscriptions, opts \\ []) do
    subs =
      Enum.map(subscriptions, fn sub ->
        %{
          "rxChannelIndex" => sub[:rx_channel_index] || sub["rxChannelIndex"],
          "subscribedDevice" => sub[:subscribed_device] || sub["subscribedDevice"],
          "subscribedChannel" => sub[:subscribed_channel] || sub["subscribedChannel"]
        }
      end)

    input = %{
      "deviceId" => device_id,
      "subscriptions" => subs,
      "allowSubscriptionToNonExistentDevice" =>
        Keyword.get(opts, :allow_nonexistent_device, false),
      "allowSubscriptionToNonExistentChannel" =>
        Keyword.get(opts, :allow_nonexistent_channel, false)
    }

    case Client.mutate(Queries.set_subscriptions(), %{"input" => input}) do
      {:ok, %{"DeviceRxChannelsSubscriptionSet" => %{"ok" => true}}} -> :ok
      {:ok, %{"DeviceRxChannelsSubscriptionSet" => %{"ok" => false}}} -> {:error, :failed}
      error -> error
    end
  end

  @doc """
  Clear (unsubscribe) an RX channel.
  """
  def clear_subscription(device_id, rx_channel_index) do
    set_subscriptions(device_id, [
      %{rx_channel_index: rx_channel_index, subscribed_device: "", subscribed_channel: ""}
    ])
  end

  # ── Enrolment ──

  @doc """
  Enrol devices into a domain.
  """
  def enrol_devices(domain_id, device_ids, opts \\ []) do
    input = %{
      "domainId" => domain_id,
      "deviceIds" => device_ids,
      "clearConfig" => Keyword.get(opts, :clear_config, false)
    }

    case Client.mutate(Queries.enrol_devices(), %{"input" => input}) do
      {:ok, %{"DevicesEnroll" => %{"ok" => true}}} -> :ok
      {:ok, %{"DevicesEnroll" => %{"ok" => false}}} -> {:error, :failed}
      error -> error
    end
  end

  @doc """
  Unenrol devices from their domain.
  """
  def unenrol_devices(device_ids, opts \\ []) do
    input = %{
      "deviceIds" => device_ids,
      "clearConfig" => Keyword.get(opts, :clear_config, false)
    }

    case Client.mutate(Queries.unenrol_devices(), %{"input" => input}) do
      {:ok, %{"DevicesUnenroll" => %{"ok" => true}}} -> :ok
      {:ok, %{"DevicesUnenroll" => %{"ok" => false}}} -> {:error, :failed}
      error -> error
    end
  end

  # ── Clocking ──

  @doc """
  Enable or disable unicast clocking on a device.
  """
  def set_unicast_clocking(device_id, enabled) do
    input = %{
      "deviceId" => device_id,
      "enabled" => enabled
    }

    case Client.mutate(Queries.set_unicast_clocking(), %{"input" => input}) do
      {:ok, %{"DeviceClockingUnicastSet" => %{"ok" => true}}} -> :ok
      {:ok, %{"DeviceClockingUnicastSet" => %{"ok" => false}}} -> {:error, :failed}
      error -> error
    end
  end

  # ── Helpers ──

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
