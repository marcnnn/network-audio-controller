defmodule Netaudio.Director.ClientTest do
  use ExUnit.Case, async: true

  alias Netaudio.Director.Client

  describe "configured?/0" do
    test "returns false when not configured" do
      # Default test env has no Director config
      refute Client.configured?()
    end
  end

  describe "query/3" do
    test "returns :not_configured when endpoint is nil" do
      assert {:error, :not_configured} = Client.query("{ domains { id } }")
    end

    test "returns :not_configured when api_key is nil" do
      assert {:error, :not_configured} =
               Client.query("{ domains { id } }", %{}, endpoint: "https://example.com/graphql")
    end
  end

  describe "mutate/3" do
    test "returns :not_configured when not set up" do
      assert {:error, :not_configured} = Client.mutate("mutation { test }")
    end
  end

  describe "test_connection/1" do
    test "returns :not_configured when no credentials" do
      assert {:error, :not_configured} = Client.test_connection()
    end
  end
end
