defmodule NetaudioWeb.Api.DirectorController do
  @moduledoc """
  JSON API controller for the Dante Director / DDM Managed API.

  Provides a REST-like interface to the GraphQL-based Dante Managed API,
  making it easy for external integrations to consume.
  """

  use NetaudioWeb, :controller

  alias Netaudio.Director

  @doc "GET /api/director/status - Check Director API connection status"
  def status(conn, _params) do
    if Director.configured?() do
      case Director.test_connection() do
        :ok -> json(conn, %{status: "connected", configured: true})
        {:ok, _} -> json(conn, %{status: "connected", configured: true})
        {:error, reason} -> json(conn, %{status: "error", configured: true, error: inspect(reason)})
      end
    else
      json(conn, %{status: "not_configured", configured: false})
    end
  end

  @doc "GET /api/director/domains - List all domains"
  def list_domains(conn, _params) do
    case Director.list_domains() do
      {:ok, domains} -> json(conn, %{data: domains})
      {:error, reason} -> error_response(conn, reason)
    end
  end

  @doc "GET /api/director/domains/:id - Get domain with devices"
  def get_domain(conn, %{"id" => id}) do
    case Director.get_domain(id: id) do
      {:ok, domain} -> json(conn, %{data: domain})
      {:error, reason} -> error_response(conn, reason)
    end
  end

  @doc "GET /api/director/domains/:id/routing - Get routing state for domain"
  def get_routing(conn, %{"id" => id}) do
    case Director.get_routing_state(id: id) do
      {:ok, domain} -> json(conn, %{data: domain})
      {:error, reason} -> error_response(conn, reason)
    end
  end

  @doc "GET /api/director/domains/:id/clocking - Get clocking state for domain"
  def get_clocking(conn, %{"id" => id}) do
    case Director.get_clocking_state(id: id) do
      {:ok, domain} -> json(conn, %{data: domain})
      {:error, reason} -> error_response(conn, reason)
    end
  end

  @doc "GET /api/director/domains/:domain_id/devices/:device_id - Get device detail"
  def get_device(conn, %{"domain_id" => domain_id, "device_id" => device_id}) do
    case Director.get_device(domain_id, device_id) do
      {:ok, device} -> json(conn, %{data: device})
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{error: "Device not found"})
      {:error, reason} -> error_response(conn, reason)
    end
  end

  @doc "GET /api/director/unenrolled - List unenrolled devices"
  def list_unenrolled(conn, _params) do
    case Director.list_unenrolled_devices() do
      {:ok, devices} -> json(conn, %{data: devices})
      {:error, reason} -> error_response(conn, reason)
    end
  end

  @doc "POST /api/director/subscriptions - Set subscriptions"
  def set_subscriptions(conn, %{"device_id" => device_id, "subscriptions" => subs}) do
    case Director.set_subscriptions(device_id, subs) do
      :ok -> json(conn, %{ok: true})
      {:error, reason} -> error_response(conn, reason)
    end
  end

  @doc "DELETE /api/director/subscriptions - Clear a subscription"
  def clear_subscription(conn, %{"device_id" => device_id, "rx_channel_index" => index}) do
    case Director.clear_subscription(device_id, index) do
      :ok -> json(conn, %{ok: true})
      {:error, reason} -> error_response(conn, reason)
    end
  end

  @doc "POST /api/director/enrol - Enrol devices into a domain"
  def enrol_devices(conn, %{"domain_id" => domain_id, "device_ids" => device_ids} = params) do
    opts = if params["clear_config"], do: [clear_config: true], else: []

    case Director.enrol_devices(domain_id, device_ids, opts) do
      :ok -> json(conn, %{ok: true})
      {:error, reason} -> error_response(conn, reason)
    end
  end

  @doc "POST /api/director/unenrol - Unenrol devices"
  def unenrol_devices(conn, %{"device_ids" => device_ids} = params) do
    opts = if params["clear_config"], do: [clear_config: true], else: []

    case Director.unenrol_devices(device_ids, opts) do
      :ok -> json(conn, %{ok: true})
      {:error, reason} -> error_response(conn, reason)
    end
  end

  @doc "POST /api/director/graphql - Raw GraphQL proxy"
  def graphql(conn, %{"query" => query_string} = params) do
    variables = Map.get(params, "variables", %{})

    case Director.Client.query(query_string, variables) do
      {:ok, data} -> json(conn, %{data: data})
      {:error, {:graphql_errors, errors, data}} -> json(conn, %{data: data, errors: errors})
      {:error, reason} -> error_response(conn, reason)
    end
  end

  defp error_response(conn, :not_configured) do
    conn |> put_status(:service_unavailable) |> json(%{error: "Director API not configured"})
  end

  defp error_response(conn, :unauthorized) do
    conn |> put_status(:unauthorized) |> json(%{error: "Invalid API key"})
  end

  defp error_response(conn, :forbidden) do
    conn |> put_status(:forbidden) |> json(%{error: "Insufficient permissions"})
  end

  defp error_response(conn, :rate_limited) do
    conn |> put_status(:too_many_requests) |> json(%{error: "Rate limited"})
  end

  defp error_response(conn, reason) do
    conn |> put_status(:bad_gateway) |> json(%{error: inspect(reason)})
  end
end
