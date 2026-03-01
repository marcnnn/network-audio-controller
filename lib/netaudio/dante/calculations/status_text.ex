defmodule Netaudio.Dante.Calculations.StatusText do
  @moduledoc """
  Ash calculation that resolves subscription status codes to human-readable labels.
  """

  use Ash.Resource.Calculation

  alias Netaudio.Dante.Constants

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def load(_query, _opts, _context) do
    []
  end

  @impl true
  def calculate(records, opts, _context) do
    field = Keyword.get(opts, :field, :status_code)

    Enum.map(records, fn record ->
      code = Map.get(record, field)

      if code do
        Constants.subscription_status_label(code)
      else
        ["Unknown"]
      end
    end)
  end
end
