defmodule Netaudio.Director.QueriesTest do
  use ExUnit.Case, async: true

  alias Netaudio.Director.Queries

  describe "queries" do
    test "list_domains returns a valid GraphQL query" do
      query = Queries.list_domains()
      assert query =~ "query ListDomains"
      assert query =~ "domains"
      assert query =~ "id"
      assert query =~ "name"
    end

    test "get_domain returns a query with id and name variables" do
      query = Queries.get_domain()
      assert query =~ "query GetDomain"
      assert query =~ "$id: ID"
      assert query =~ "$name: String"
      assert query =~ "domain("
      assert query =~ "devices"
    end

    test "get_device returns a query with domain and device variables" do
      query = Queries.get_device()
      assert query =~ "query GetDevice"
      assert query =~ "$deviceId: ID!"
      assert query =~ "rxChannels"
      assert query =~ "txChannels"
    end

    test "get_domain_with_channels includes channel fields" do
      query = Queries.get_domain_with_channels()
      assert query =~ "query GetDomainWithChannels"
      assert query =~ "rxChannels"
      assert query =~ "txChannels"
    end

    test "list_unenrolled_devices returns valid query" do
      query = Queries.list_unenrolled_devices()
      assert query =~ "unenrolledDevices"
    end

    test "get_routing_state includes subscription fields" do
      query = Queries.get_routing_state()
      assert query =~ "GetRoutingState"
      assert query =~ "subscribedDevice"
      assert query =~ "subscribedChannel"
      assert query =~ "status"
    end

    test "get_clocking_state includes clocking fields" do
      query = Queries.get_clocking_state()
      assert query =~ "GetClockingState"
      assert query =~ "clockingState"
      assert query =~ "locked"
      assert query =~ "grandLeader"
      assert query =~ "clockPreferences"
      assert query =~ "unicastClocking"
    end
  end

  describe "mutations" do
    test "enrol_devices returns a valid mutation" do
      mutation = Queries.enrol_devices()
      assert mutation =~ "mutation EnrolDevices"
      assert mutation =~ "DevicesEnroll"
      assert mutation =~ "$input: DevicesEnrollInput!"
      assert mutation =~ "ok"
    end

    test "unenrol_devices returns a valid mutation" do
      mutation = Queries.unenrol_devices()
      assert mutation =~ "mutation UnenrolDevices"
      assert mutation =~ "DevicesUnenroll"
      assert mutation =~ "$input: DevicesUnenrollInput!"
    end

    test "set_subscriptions returns a valid mutation" do
      mutation = Queries.set_subscriptions()
      assert mutation =~ "mutation SetSubscriptions"
      assert mutation =~ "DeviceRxChannelsSubscriptionSet"
      assert mutation =~ "$input: DeviceRxChannelsSubscriptionSetInput!"
    end

    test "clear_subscription delegates to set_subscriptions" do
      assert Queries.clear_subscription() == Queries.set_subscriptions()
    end

    test "set_unicast_clocking returns a valid mutation" do
      mutation = Queries.set_unicast_clocking()
      assert mutation =~ "mutation SetUnicastClocking"
      assert mutation =~ "DeviceClockingUnicastSet"
    end
  end
end
