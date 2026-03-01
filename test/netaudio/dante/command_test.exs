defmodule Netaudio.Dante.CommandTest do
  use ExUnit.Case, async: true

  alias Netaudio.Dante.Command

  describe "channel_count/0" do
    test "returns a hex command and service type" do
      {cmd, service} = Command.channel_count()
      assert is_binary(cmd)
      assert String.starts_with?(cmd, "27")
      assert String.contains?(cmd, "1000")
      assert service == Netaudio.Dante.Constants.service_arc()
    end
  end

  describe "device_name/0" do
    test "returns a hex command and service type" do
      {cmd, service} = Command.device_name()
      assert is_binary(cmd)
      assert String.starts_with?(cmd, "27")
      assert String.contains?(cmd, "1002")
      assert service == Netaudio.Dante.Constants.service_arc()
    end
  end

  describe "receivers/1" do
    test "returns a hex command for page 0" do
      {cmd, service} = Command.receivers(0)
      assert is_binary(cmd)
      assert String.contains?(cmd, "3000")
      assert service == Netaudio.Dante.Constants.service_arc()
    end
  end

  describe "transmitters/2" do
    test "returns channel query command" do
      {cmd, _service} = Command.transmitters(0, false)
      assert String.contains?(cmd, "2000")
    end

    test "returns friendly names query command" do
      {cmd, _service} = Command.transmitters(0, true)
      assert String.contains?(cmd, "2010")
    end
  end

  describe "set_name/1" do
    test "encodes device name in hex" do
      {cmd, service} = Command.set_name("test-device")
      assert is_binary(cmd)
      # "test-device" hex encoded
      assert String.contains?(cmd, "746573742d646576696365")
      assert service == Netaudio.Dante.Constants.service_arc()
    end
  end

  describe "reset_name/0" do
    test "returns reset name command" do
      {cmd, service} = Command.reset_name()
      assert String.contains?(cmd, "1001")
      assert service == Netaudio.Dante.Constants.service_arc()
    end
  end

  describe "add_subscription/3" do
    test "builds subscription command with correct channel and device names" do
      {cmd, service} = Command.add_subscription(1, "Channel 1", "my-device")
      assert is_binary(cmd)
      assert String.contains?(cmd, "3010")
      # Verify the tx channel name is hex encoded
      assert String.contains?(cmd, Base.encode16("Channel 1", case: :lower))
      assert service == Netaudio.Dante.Constants.service_arc()
    end
  end

  describe "remove_subscription/1" do
    test "builds remove command with channel number" do
      {cmd, service} = Command.remove_subscription(1)
      assert String.contains?(cmd, "3014")
      assert service == Netaudio.Dante.Constants.service_arc()
    end
  end

  describe "identify/0" do
    test "returns identify command with settings port" do
      {cmd, service, port} = Command.identify()
      assert is_binary(cmd)
      assert is_nil(service)
      assert port == Netaudio.Dante.Constants.device_settings_port()
    end
  end

  describe "set_sample_rate/1" do
    test "encodes sample rate as 6-digit hex" do
      {cmd, _service, port} = Command.set_sample_rate(48000)
      # 48000 = 0x00BB80
      assert String.contains?(cmd, "00bb80")
      assert port == Netaudio.Dante.Constants.device_settings_port()
    end
  end

  describe "set_encoding/1" do
    test "encodes bit depth" do
      {cmd, _service, port} = Command.set_encoding(24)
      # 24 = 0x18
      assert String.contains?(cmd, "18")
      assert port == Netaudio.Dante.Constants.device_settings_port()
    end
  end

  describe "set_channel_name/3" do
    test "builds set channel name for rx" do
      {cmd, service} = Command.set_channel_name(:rx, 1, "NewName")
      assert String.contains?(cmd, "3001")
      assert String.contains?(cmd, Base.encode16("NewName", case: :lower))
      assert service == Netaudio.Dante.Constants.service_arc()
    end

    test "builds set channel name for tx" do
      {cmd, service} = Command.set_channel_name(:tx, 2, "TxName")
      assert String.contains?(cmd, "2013")
      assert String.contains?(cmd, Base.encode16("TxName", case: :lower))
      assert service == Netaudio.Dante.Constants.service_arc()
    end
  end
end
