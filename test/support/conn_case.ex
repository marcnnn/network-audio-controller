defmodule NetaudioWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint NetaudioWeb.Endpoint

      use NetaudioWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import NetaudioWeb.ConnCase
    end
  end

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
