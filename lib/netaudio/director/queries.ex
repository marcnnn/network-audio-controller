defmodule Netaudio.Director.Queries do
  @moduledoc """
  GraphQL query and mutation strings for the Dante Managed API.

  These match the official Dante Managed API schema (v1.8) as documented at:
  https://dev.audinate.com/GA/managed-api/userguide/pdf/latest/AUD-MAN_Managed_API_v1.8.pdf
  """

  # ── Queries ──

  @doc "List all domains with basic info."
  def list_domains do
    """
    query ListDomains {
      domains {
        id
        name
        icon
        legacyInterop
      }
    }
    """
  end

  @doc "Get a single domain with its devices."
  def get_domain do
    """
    query GetDomain($id: ID, $name: String) {
      domain(id: $id, name: $name) {
        id
        name
        icon
        legacyInterop
        devices {
          #{device_fields()}
        }
      }
    }
    """
  end

  @doc "Get a single device within a domain."
  def get_device do
    """
    query GetDevice($domainId: ID, $domainName: String, $deviceId: ID!) {
      domain(id: $domainId, name: $domainName) {
        id
        name
        device(id: $deviceId) {
          #{device_fields()}
          rxChannels {
            #{rx_channel_fields()}
          }
          txChannels {
            #{tx_channel_fields()}
          }
        }
      }
    }
    """
  end

  @doc "Get all devices in a domain with full channel details."
  def get_domain_with_channels do
    """
    query GetDomainWithChannels($id: ID, $name: String) {
      domain(id: $id, name: $name) {
        id
        name
        devices {
          #{device_fields()}
          rxChannels {
            #{rx_channel_fields()}
          }
          txChannels {
            #{tx_channel_fields()}
          }
        }
      }
    }
    """
  end

  @doc "List all unenrolled devices."
  def list_unenrolled_devices do
    """
    query ListUnenrolledDevices {
      unenrolledDevices {
        #{device_fields()}
      }
    }
    """
  end

  @doc "Get devices with their subscription status for routing view."
  def get_routing_state do
    """
    query GetRoutingState($domainId: ID, $domainName: String) {
      domain(id: $domainId, name: $domainName) {
        id
        name
        devices {
          id
          name
          enrolmentState
          connection {
            id
            state
          }
          rxChannels {
            id
            index
            name
            subscribedDevice
            subscribedChannel
            status
            summary
            mediaType
          }
          txChannels {
            id
            index
            name
            mediaType
          }
        }
      }
    }
    """
  end

  @doc "Get clock state for all devices in a domain."
  def get_clocking_state do
    """
    query GetClockingState($domainId: ID, $domainName: String) {
      domain(id: $domainId, name: $domainName) {
        id
        name
        devices {
          id
          name
          clockingState {
            id
            locked
            grandLeader
            followerWithoutLeader
            multicastLeader
            unicastLeader
            unicastFollower
            muteStatus
            frequencyOffset
          }
          clockPreferences {
            id
            externalWordClock
            leader
            unicastClocking
            v1UnicastDelayRequests
          }
        }
      }
    }
    """
  end

  # ── Mutations ──

  @doc "Enrol devices into a domain."
  def enrol_devices do
    """
    mutation EnrolDevices($input: DevicesEnrollInput!) {
      DevicesEnroll(input: $input) {
        ok
      }
    }
    """
  end

  @doc "Unenrol devices from their domain."
  def unenrol_devices do
    """
    mutation UnenrolDevices($input: DevicesUnenrollInput!) {
      DevicesUnenroll(input: $input) {
        ok
      }
    }
    """
  end

  @doc "Set RX channel subscriptions on a device."
  def set_subscriptions do
    """
    mutation SetSubscriptions($input: DeviceRxChannelsSubscriptionSetInput!) {
      DeviceRxChannelsSubscriptionSet(input: $input) {
        ok
      }
    }
    """
  end

  @doc "Clear a subscription (set to empty string to unsubscribe)."
  def clear_subscription do
    set_subscriptions()
  end

  @doc "Set unicast clocking on a device."
  def set_unicast_clocking do
    """
    mutation SetUnicastClocking($input: DeviceClockingUnicastSetInput!) {
      DeviceClockingUnicastSet(input: $input) {
        ok
      }
    }
    """
  end

  # ── Field fragments ──

  defp device_fields do
    """
    id
    name
    domainId
    enrolmentState
    picture
    location
    description
    comments
    identity {
      id
      instanceId
      defaultName
      actualName
      productModelId
      productModelName
      productVersion
      productSoftwareVersion
      danteVersion
      danteHardwareVersion
    }
    manufacturer {
      id
      name
    }
    interfaces {
      id
      macAddress
      address
      netmask
      subnet
    }
    connection {
      id
      state
      lastChanged
    }
    clockingState {
      id
      locked
      grandLeader
      multicastLeader
    }
    capabilities {
      id
      CAN_WRITE_PREFERRED_MASTER
      CAN_WRITE_EXT_WORD_CLOCK
      CAN_WRITE_SLAVE_ONLY
      CAN_WRITE_UNICAST_DELAY_REQUESTS
      CAN_UNICAST_CLOCKING
      mediaTypes
    }
    platform {
      id
      name
    }
    product {
      id
      name
    }
    """
  end

  defp rx_channel_fields do
    """
    id
    index
    enabled
    name
    subscribedDevice
    subscribedChannel
    status
    statusMessage
    summary
    mediaType
    """
  end

  defp tx_channel_fields do
    """
    id
    index
    name
    mediaType
    """
  end
end
