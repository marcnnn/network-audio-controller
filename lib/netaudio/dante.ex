defmodule Netaudio.Dante do
  @moduledoc """
  Ash domain for Dante network audio device management.
  Provides the API for discovering, querying, and controlling Dante devices.
  """

  use Ash.Domain

  resources do
    resource Netaudio.Dante.Device
    resource Netaudio.Dante.Channel
    resource Netaudio.Dante.Subscription
  end
end
