defmodule Netaudio.Dante.Command do
  @moduledoc """
  Builds Dante protocol command byte sequences for device control.
  Ported from Python DanteDevice command methods.
  """

  alias Netaudio.Dante.Constants

  @doc """
  Build a generic Dante command string.
  Returns a hex-encoded binary command.
  """
  def command_string(command, opts \\ []) do
    command_str = Keyword.get(opts, :command_str, "0000")
    command_args = Keyword.get(opts, :command_args, "0000")
    command_length = Keyword.get(opts, :command_length, "00")
    sequence1 = Keyword.get(opts, :sequence1, "ff")

    {command_str, command_args, command_length} =
      case command do
        :channel_count ->
          {"1000", "0000", "0a"}

        :device_info ->
          {"1003", "0000", "0a"}

        :device_name ->
          {"1002", "0000", "0a"}

        :rx_channels ->
          {"3000", command_args, "10"}

        :reset_name ->
          {"1001", "0000", "0a"}

        :set_name ->
          {"1001", command_args, command_length}

        _ ->
          {command_str, command_args, command_length}
      end

    sequence2 = :rand.uniform(65535)
    sequence_id = Integer.to_string(sequence2, 16) |> String.pad_leading(4, "0") |> String.downcase()

    command_hex = "27#{sequence1}00#{command_length}#{sequence_id}#{command_str}#{command_args}"

    if command == :add_subscription do
      new_length =
        div(String.length(command_hex), 2)
        |> Integer.to_string(16)
        |> String.pad_leading(2, "0")
        |> String.downcase()

      "27#{sequence1}00#{new_length}#{sequence_id}#{command_str}#{command_args}"
    else
      command_hex
    end
  end

  def channel_count do
    {command_string(:channel_count), Constants.service_arc()}
  end

  def device_name do
    {command_string(:device_name), Constants.service_arc()}
  end

  def device_info do
    {command_string(:device_info), Constants.service_arc()}
  end

  def receivers(page \\ 0) do
    args = channel_pagination(page)
    {command_string(:rx_channels, command_args: args), Constants.service_arc()}
  end

  def transmitters(page \\ 0, friendly_names \\ false) do
    cmd_str = if friendly_names, do: "2010", else: "2000"
    args = channel_pagination(page)

    {command_string(:tx_channels,
       command_str: cmd_str,
       command_length: "10",
       command_args: args
     ), Constants.service_arc()}
  end

  def set_name(name) do
    name_hex = Base.encode16(name, case: :lower)
    name_args = "0000#{name_hex}00"

    name_byte_len = byte_size(name) + 11
    args_length = Integer.to_string(name_byte_len, 16) |> String.pad_leading(2, "0") |> String.downcase()

    {command_string(:set_name, command_length: args_length, command_args: name_args),
     Constants.service_arc()}
  end

  def reset_name do
    {command_string(:reset_name), Constants.service_arc()}
  end

  def add_subscription(rx_channel_number, tx_channel_name, tx_device_name) do
    rx_hex = Integer.to_string(rx_channel_number, 16) |> String.pad_leading(2, "0") |> String.downcase()
    tx_chan_hex = Base.encode16(tx_channel_name, case: :lower)
    tx_dev_hex = Base.encode16(tx_device_name, case: :lower)

    tx_chan_offset = Integer.to_string(52, 16) |> String.pad_leading(2, "0") |> String.downcase()
    tx_dev_offset_val = 52 + byte_size(tx_channel_name) + 1
    tx_dev_offset = Integer.to_string(tx_dev_offset_val, 16) |> String.pad_leading(2, "0") |> String.downcase()

    padding = String.duplicate("00", 34)
    args = "0000020100#{rx_hex}00#{tx_chan_offset}00#{tx_dev_offset}#{padding}#{tx_chan_hex}00#{tx_dev_hex}00"

    {command_string(:add_subscription, command_str: "3010", command_args: args),
     Constants.service_arc()}
  end

  def remove_subscription(rx_channel_number) do
    rx_hex = Integer.to_string(rx_channel_number, 16) |> String.pad_leading(2, "0") |> String.downcase()
    args = "00000001000000#{rx_hex}"

    {command_string(:remove_subscription,
       command_str: "3014",
       command_length: "10",
       command_args: args
     ), Constants.service_arc()}
  end

  def identify do
    mac = "000000000000"
    data_len = Integer.to_string(32, 16) |> String.pad_leading(2, "0") |> String.downcase()
    cmd = "ffff00#{data_len}0bc80000#{mac}0000417564696e6174650731006300000064"
    {cmd, nil, Constants.device_settings_port()}
  end

  def set_sample_rate(sample_rate) do
    rate_hex = Integer.to_string(sample_rate, 16) |> String.pad_leading(6, "0") |> String.downcase()
    cmd = "ffff002803d400005254000000000000417564696e61746507270081000000640000000100#{rate_hex}"
    {cmd, nil, Constants.device_settings_port()}
  end

  def set_encoding(encoding) do
    enc_hex = Integer.to_string(encoding, 16) |> String.pad_leading(2, "0") |> String.downcase()
    cmd = "ffff002803d700005254000000000000417564696e617465072700830000006400000001000000#{enc_hex}"
    {cmd, nil, Constants.device_settings_port()}
  end

  def set_latency(latency_ms) do
    latency_us = round(latency_ms * 1_000_000)
    lat_hex = Integer.to_string(latency_us, 16) |> String.pad_leading(6, "0") |> String.downcase()
    args = "00000503820500200211001083010024821983018302830600#{lat_hex}00#{lat_hex}"

    {command_string(:set_latency,
       command_str: "1101",
       command_length: "28",
       command_args: args
     ), Constants.service_arc()}
  end

  def set_channel_name(channel_type, channel_number, new_name) do
    name_hex = Base.encode16(new_name, case: :lower)
    ch_hex = Integer.to_string(channel_number, 16) |> String.pad_leading(2, "0") |> String.downcase()

    {cmd_str, args, args_len} =
      case channel_type do
        :rx ->
          args = "0000020100#{ch_hex}001400000000#{name_hex}00"
          len = byte_size(new_name) + 21
          {"3001", args, len}

        :tx ->
          args = "00000201000000#{ch_hex}0018000000000000#{name_hex}00"
          len = byte_size(new_name) + 25
          {"2013", args, len}
      end

    len_hex = Integer.to_string(args_len, 16) |> String.pad_leading(2, "0") |> String.downcase()

    {command_string(:set_channel_name,
       command_str: cmd_str,
       command_args: args,
       command_length: len_hex
     ), Constants.service_arc()}
  end

  def reset_channel_name(channel_type, channel_number) do
    ch_hex = Integer.to_string(channel_number, 16) |> String.pad_leading(2, "0") |> String.downcase()

    {cmd_str, args, args_len} =
      case channel_type do
        :rx ->
          {"3001", "0000020100#{ch_hex}00140000000000", "15"}

        :tx ->
          {"2013", "00000201000000#{ch_hex}001800000000000000", "19"}
      end

    {command_string(:reset_channel_name,
       command_str: cmd_str,
       command_args: args,
       command_length: args_len
     ), Constants.service_arc()}
  end

  def set_gain_level(channel_number, gain_level, device_type) do
    target =
      case device_type do
        :input ->
          "ffff003403440000525400000000000041756469 6e6174650727100a0000000000010001000c001001020000000000"

        :output ->
          "ffff003403260000525400000000000041756469 6e6174650727100a0000000000010001000c001002010000000000"
      end
      |> String.replace(" ", "")

    ch_hex = Integer.to_string(channel_number, 16) |> String.pad_leading(2, "0") |> String.downcase()
    gl_hex = Integer.to_string(gain_level, 16) |> String.pad_leading(2, "0") |> String.downcase()

    {target <> "#{ch_hex}000000#{gl_hex}", nil, Constants.device_settings_port()}
  end

  defp channel_pagination(page) do
    page_hex = Integer.to_string(page, 16)
    "0000000100#{page_hex}10000"
  end
end
