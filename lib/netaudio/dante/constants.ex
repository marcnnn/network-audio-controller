defmodule Netaudio.Dante.Constants do
  @moduledoc """
  Protocol constants for Dante network audio devices.
  Ported from Python netaudio.dante.const module.
  """

  # mDNS service types
  @service_arc "_netaudio-arc._udp.local."
  @service_chan "_netaudio-chan._udp.local."
  @service_cmc "_netaudio-cmc._udp.local."
  @service_dbc "_netaudio-dbc._udp.local."

  def service_arc, do: @service_arc
  def service_chan, do: @service_chan
  def service_cmc, do: @service_cmc
  def service_dbc, do: @service_dbc
  def services, do: [@service_arc, @service_chan, @service_cmc, @service_dbc]

  # Multicast groups
  def multicast_group_heartbeat, do: "224.0.0.233"
  def multicast_group_control_monitoring, do: "224.0.0.231"

  # Models without volume support
  def feature_volume_unsupported do
    ["DAI1", "DAI2", "DAO1", "DAO2", "DIAES3", "DIOUSB", "DIUSBC", "_86012780000a0003"]
  end

  # Ports
  def default_multicast_metering_port, do: 8751
  def device_control_port, do: 8800
  def device_heartbeat_port, do: 8708
  def device_info_port, do: 8702
  def device_info_src_port1, do: 1029
  def device_info_src_port2, do: 1030
  def device_settings_port, do: 8700
  def ports, do: [device_control_port(), device_info_port(), device_settings_port()]

  # Subscription status codes
  def subscription_status(:none), do: 0
  def subscription_status(:unresolved), do: 1
  def subscription_status(:resolved), do: 2
  def subscription_status(:resolve_fail), do: 3
  def subscription_status(:subscribe_self), do: 4
  def subscription_status(:resolved_none), do: 5
  def subscription_status(:idle), do: 7
  def subscription_status(:in_progress), do: 8
  def subscription_status(:dynamic), do: 9
  def subscription_status(:static), do: 10
  def subscription_status(:manual), do: 14
  def subscription_status(:no_connection), do: 15
  def subscription_status(:channel_format), do: 16
  def subscription_status(:bundle_format), do: 17
  def subscription_status(:no_rx), do: 18
  def subscription_status(:rx_fail), do: 19
  def subscription_status(:no_tx), do: 20
  def subscription_status(:tx_fail), do: 21
  def subscription_status(:qos_fail_rx), do: 22
  def subscription_status(:qos_fail_tx), do: 23
  def subscription_status(:tx_rejected_addr), do: 24
  def subscription_status(:invalid_msg), do: 25
  def subscription_status(:channel_latency), do: 26
  def subscription_status(:clock_domain), do: 27
  def subscription_status(:unsupported), do: 28
  def subscription_status(:rx_link_down), do: 29
  def subscription_status(:tx_link_down), do: 30
  def subscription_status(:dynamic_protocol), do: 31
  def subscription_status(:invalid_channel), do: 32
  def subscription_status(:tx_scheduler_failure), do: 33
  def subscription_status(:subscribe_self_policy), do: 34
  def subscription_status(:tx_not_ready), do: 35
  def subscription_status(:rx_not_ready), do: 36
  def subscription_status(:tx_fanout_limit_reached), do: 37
  def subscription_status(:tx_channel_encrypted), do: 38
  def subscription_status(:tx_response_unexpected), do: 39
  def subscription_status(:template_mismatch_device), do: 64
  def subscription_status(:template_mismatch_format), do: 65
  def subscription_status(:template_missing_channel), do: 66
  def subscription_status(:template_mismatch_config), do: 67
  def subscription_status(:template_full), do: 68
  def subscription_status(:rx_unsupported_sub_mode), do: 69
  def subscription_status(:tx_unsupported_sub_mode), do: 70
  def subscription_status(:tx_access_control_denied), do: 96
  def subscription_status(:tx_access_control_pending), do: 97
  def subscription_status(:hdcp_negotiation_error), do: 112
  def subscription_status(:system_fail), do: 255
  def subscription_status(:flag_no_advert), do: 256
  def subscription_status(:flag_no_dbcp), do: 512
  def subscription_status(:no_data), do: 65536

  @subscription_status_labels %{
    0 => ["No subscription for this channel"],
    1 => ["Unresolved: channel not present", "Unresolved", "this channel is not present on the network"],
    2 => ["Subscription resolved", "Resolved", "channel found; preparing to create flow"],
    3 => ["Can't resolve subscription", "Resolve failed", "received an unexpected error when trying to resolve this channel"],
    4 => ["Subscribed to own signal", "Connected (self)"],
    7 => ["Subscription idle", "Flow creation idle", "Insufficient information to create flow"],
    8 => ["Subscription in progress", "Flow creation in progress", "communicating with transmitter to create flow"],
    9 => ["Connected (unicast)"],
    10 => ["Connected (multicast)"],
    14 => ["Manually Configured"],
    15 => ["No connection", "could not communicate with transmitter"],
    16 => ["Incorrect channel format", "source and destination channels do not match"],
    17 => ["Incorrect flow format", "Incorrect multicast flow format", "flow format incompatible with receiver"],
    18 => ["No Receive flows", "No more flows (RX)", "receiver cannot support any more flows"],
    19 => ["Receive failure", "Receiver setup failed", "unexpected error on receiver"],
    20 => ["No Transmit flows", "No more flows (TX)", "transmitter cannot support any more flows"],
    21 => ["Transmit failure", "Transmitter setup failed", "unexpected error on transmitter"],
    22 => ["Receive bandwidth exceeded", "receiver can't reliably support any more inbound flows"],
    23 => ["Transmit bandwidth exceeded", "transmitter can't reliably support any more outbound flows"],
    24 => ["Subscription address rejected by transmitter", "Transmitter rejected address"],
    25 => ["Subscription message rejected by transmitter", "Transmitter rejected message"],
    26 => ["No suitable channel latency", "Incorrect channel latencies"],
    27 => ["Mismatched clock domains", "The transmitter and receiver are not part of the same clock domain"],
    28 => ["Unsupported feature"],
    29 => ["RX link down"],
    30 => ["TX link down"],
    31 => ["Dynamic Protocol"],
    32 => ["Invalid Channel"],
    33 => ["TX Scheduler failure"],
    34 => ["Subscription to own signal disallowed by device", "Policy failure for subscription to self"],
    64 => ["Template mismatch (device)"],
    65 => ["Template mismatch (format)"],
    66 => ["Template missing channel"],
    67 => ["Template mismatch (config)"],
    68 => ["Template full"],
    96 => ["TX access control denied"],
    97 => ["TX access control pending"],
    112 => ["HDCP negotiation error"],
    255 => ["System failure"],
    256 => ["No audio data."],
    65536 => ["No data"]
  }

  def subscription_status_labels, do: @subscription_status_labels

  def subscription_status_label(code) do
    Map.get(@subscription_status_labels, code, ["Unknown status"])
  end

  # Message type constants
  def message_type(:channel_counts_query), do: 0x1000
  def message_type(:device_control), do: 0x1003
  def message_type(:identify_device_query), do: 0x10CE
  def message_type(:name_control), do: 0x1001
  def message_type(:name_query), do: 0x1002
  def message_type(:rx_channel_query), do: 0x3000
  def message_type(:tx_channel_query), do: 0x2000
  def message_type(:tx_channel_friendly_names_query), do: 0x2010

  # Sample rates
  def valid_sample_rates, do: [44100, 48000, 88200, 96000, 176400, 192000]

  # Encodings
  def valid_encodings, do: [16, 24, 32]

  # Gain levels (1-5)
  def gain_levels(:dai) do
    %{1 => "+24dBu", 2 => "+4dBu", 3 => "+0dBu", 4 => "0dBV", 5 => "-10dBV"}
  end

  def gain_levels(:dao) do
    %{1 => "+18dBu", 2 => "+4dBu", 3 => "+0dBu", 4 => "0dBV", 5 => "-10dBV"}
  end
end
