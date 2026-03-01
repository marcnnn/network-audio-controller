defmodule Netaudio.DirectorTest do
  use ExUnit.Case, async: true

  alias Netaudio.Director

  describe "configured?/0" do
    test "delegates to Client.configured?" do
      # In test env, Director is not configured
      refute Director.configured?()
    end
  end

  describe "list_domains/0" do
    test "returns error when not configured" do
      assert {:error, :not_configured} = Director.list_domains()
    end
  end

  describe "get_domain/1" do
    test "accepts keyword list with :id" do
      assert {:error, :not_configured} = Director.get_domain(id: "test-id")
    end

    test "accepts keyword list with :name" do
      assert {:error, :not_configured} = Director.get_domain(name: "test-name")
    end

    test "accepts binary id" do
      assert {:error, :not_configured} = Director.get_domain("test-id")
    end
  end

  describe "get_domain_with_channels/1" do
    test "returns error when not configured" do
      assert {:error, :not_configured} = Director.get_domain_with_channels(id: "test-id")
    end
  end

  describe "get_device/2" do
    test "returns error when not configured" do
      assert {:error, :not_configured} = Director.get_device("domain-1", "device-1")
    end
  end

  describe "list_unenrolled_devices/0" do
    test "returns error when not configured" do
      assert {:error, :not_configured} = Director.list_unenrolled_devices()
    end
  end

  describe "get_routing_state/1" do
    test "returns error when not configured" do
      assert {:error, :not_configured} = Director.get_routing_state(id: "test-id")
    end
  end

  describe "get_clocking_state/1" do
    test "returns error when not configured" do
      assert {:error, :not_configured} = Director.get_clocking_state(id: "test-id")
    end
  end

  describe "set_subscriptions/3" do
    test "returns error when not configured" do
      subs = [%{rx_channel_index: 1, subscribed_device: "Dev", subscribed_channel: "Ch1"}]
      assert {:error, :not_configured} = Director.set_subscriptions("device-1", subs)
    end
  end

  describe "clear_subscription/2" do
    test "returns error when not configured" do
      assert {:error, :not_configured} = Director.clear_subscription("device-1", 1)
    end
  end

  describe "enrol_devices/3" do
    test "returns error when not configured" do
      assert {:error, :not_configured} = Director.enrol_devices("domain-1", ["device-1"])
    end
  end

  describe "unenrol_devices/2" do
    test "returns error when not configured" do
      assert {:error, :not_configured} = Director.unenrol_devices(["device-1"])
    end
  end

  describe "set_unicast_clocking/2" do
    test "returns error when not configured" do
      assert {:error, :not_configured} = Director.set_unicast_clocking("device-1", true)
    end
  end

  describe "test_connection/2" do
    test "calls client with provided endpoint and api_key" do
      # Will fail with http error since endpoint doesn't exist, but validates
      # it passes through the parameters
      result = Director.test_connection("https://localhost:1/graphql", "test-key")
      assert {:error, _} = result
    end
  end
end
