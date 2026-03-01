defmodule Netaudio.Dante.DeviceTest do
  use ExUnit.Case, async: true

  alias Netaudio.Dante.Device

  describe "get_label/2" do
    test "extracts a null-terminated string from hex data at given offset" do
      # Build a hex string with "Hello" at offset 0x0A (10)
      # Offset 10 means byte 10, which is hex char position 20
      padding = String.duplicate("00", 10)
      hello_hex = Base.encode16("Hello", case: :lower)
      hex_str = padding <> hello_hex <> "00" <> "deadbeef"

      result = Device.get_label(hex_str, "000a")
      assert result == "Hello"
    end

    test "returns nil for invalid offset" do
      result = Device.get_label("0000", "ffff")
      assert is_nil(result)
    end

    test "handles offset 0000 for zero position" do
      hello_hex = Base.encode16("Test", case: :lower)
      hex_str = hello_hex <> "00" <> "ff"

      result = Device.get_label(hex_str, "0000")
      assert result == "Test"
    end
  end

  describe "resolve_service_port/2" do
    test "finds port for matching service type" do
      services = %{
        "svc1" => %{"type" => "_netaudio-arc._udp.local.", "port" => 8800},
        "svc2" => %{"type" => "_netaudio-cmc._udp.local.", "port" => 8800}
      }

      port = Device.resolve_service_port(services, "_netaudio-arc._udp.local.")
      assert port == 8800
    end

    test "returns nil when service type not found" do
      services = %{
        "svc1" => %{"type" => "_netaudio-arc._udp.local.", "port" => 8800}
      }

      port = Device.resolve_service_port(services, "_nonexistent._udp.local.")
      assert is_nil(port)
    end

    test "returns nil for empty services" do
      assert is_nil(Device.resolve_service_port(%{}, "_netaudio-arc._udp.local."))
    end
  end
end
