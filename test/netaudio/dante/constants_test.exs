defmodule Netaudio.Dante.ConstantsTest do
  use ExUnit.Case, async: true

  alias Netaudio.Dante.Constants

  describe "services" do
    test "returns all Dante mDNS service types" do
      services = Constants.services()
      assert length(services) == 4
      assert Constants.service_arc() in services
      assert Constants.service_chan() in services
      assert Constants.service_cmc() in services
      assert Constants.service_dbc() in services
    end

    test "service types are properly formatted mDNS names" do
      for service <- Constants.services() do
        assert String.starts_with?(service, "_netaudio-")
        assert String.ends_with?(service, "._udp.local.")
      end
    end
  end

  describe "ports" do
    test "returns expected device control port" do
      assert Constants.device_control_port() == 8800
    end

    test "returns expected device info port" do
      assert Constants.device_info_port() == 8702
    end

    test "returns expected device settings port" do
      assert Constants.device_settings_port() == 8700
    end

    test "ports list contains all operational ports" do
      ports = Constants.ports()
      assert Constants.device_control_port() in ports
      assert Constants.device_info_port() in ports
      assert Constants.device_settings_port() in ports
    end
  end

  describe "subscription_status/1" do
    test "returns correct status codes" do
      assert Constants.subscription_status(:none) == 0
      assert Constants.subscription_status(:unresolved) == 1
      assert Constants.subscription_status(:resolved) == 2
      assert Constants.subscription_status(:dynamic) == 9
      assert Constants.subscription_status(:static) == 10
      assert Constants.subscription_status(:manual) == 14
      assert Constants.subscription_status(:system_fail) == 255
    end
  end

  describe "subscription_status_label/1" do
    test "returns labels for known status codes" do
      labels = Constants.subscription_status_label(0)
      assert is_list(labels)
      assert hd(labels) =~ "No subscription"
    end

    test "returns unknown for unrecognized codes" do
      labels = Constants.subscription_status_label(999)
      assert labels == ["Unknown status"]
    end

    test "returns labels for connected statuses" do
      assert hd(Constants.subscription_status_label(9)) =~ "Connected"
      assert hd(Constants.subscription_status_label(10)) =~ "Connected"
    end
  end

  describe "valid_sample_rates/0" do
    test "returns standard audio sample rates" do
      rates = Constants.valid_sample_rates()
      assert 44100 in rates
      assert 48000 in rates
      assert 96000 in rates
      assert 192000 in rates
    end
  end

  describe "valid_encodings/0" do
    test "returns standard bit depths" do
      encodings = Constants.valid_encodings()
      assert 16 in encodings
      assert 24 in encodings
      assert 32 in encodings
    end
  end
end
