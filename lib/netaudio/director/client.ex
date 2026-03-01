defmodule Netaudio.Director.Client do
  @moduledoc """
  GraphQL HTTP client for the Dante Managed API (Dante Director / DDM).

  The Dante Managed API is a GraphQL API that allows programmatic control
  of Dante devices enrolled in Dante Domain Manager or Dante Director.

  ## Configuration

      config :netaudio, Netaudio.Director.Client,
        endpoint: "https://my-ddm-server.example.com/graphql",
        api_key: "my-api-key"

  ## Authentication

  Authentication is via `authorization` header with the raw API key value
  (no "Bearer" prefix), matching the Dante Director / DDM convention.
  API keys are generated in the Dante Director web UI under Settings > API Keys.

  The default endpoint for Dante Director cloud is:
  `https://api.director.dante.cloud:443/graphql`
  """

  require Logger

  @default_timeout 15_000

  @doc """
  Execute a GraphQL query against the Dante Managed API.
  Returns `{:ok, data}` or `{:error, reason}`.
  """
  def query(query_string, variables \\ %{}, opts \\ []) do
    body =
      Jason.encode!(%{
        query: query_string,
        variables: variables
      })

    endpoint = opts[:endpoint] || config(:endpoint)
    api_key = opts[:api_key] || config(:api_key)

    if is_nil(endpoint) || is_nil(api_key) do
      {:error, :not_configured}
    else
      do_request(endpoint, api_key, body, opts)
    end
  end

  @doc """
  Execute a GraphQL mutation against the Dante Managed API.
  Same interface as `query/3` but semantically indicates a mutation.
  """
  def mutate(mutation_string, variables \\ %{}, opts \\ []) do
    query(mutation_string, variables, opts)
  end

  @doc """
  Check if the Director API is configured (endpoint and API key set).
  """
  def configured? do
    !is_nil(config(:endpoint)) && !is_nil(config(:api_key))
  end

  @doc """
  Test the connection to the Dante Director API.
  """
  def test_connection(opts \\ []) do
    case query("{ domains { id name } }", %{}, opts) do
      {:ok, %{"domains" => _}} -> :ok
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, reason}
    end
  end

  # Private

  defp do_request(endpoint, api_key, body, opts) do
    timeout = opts[:timeout] || @default_timeout
    uri = URI.parse(endpoint)

    # Dante Director uses raw API key in the authorization header (no Bearer prefix)
    # This matches the convention used by Audinate's official clients
    headers = [
      {"content-type", "application/json"},
      {"accept", "application/json"},
      {"authorization", api_key}
    ]

    # Use Erlang's built-in :httpc for HTTP requests
    # (no external HTTP client dependency needed)
    :ok = ensure_httpc_started()

    url = String.to_charlist(endpoint)

    httpc_headers =
      Enum.map(headers, fn {k, v} ->
        {String.to_charlist(k), String.to_charlist(v)}
      end)

    request = {url, httpc_headers, ~c"application/json", body}

    ssl_opts =
      if uri.scheme == "https" do
        [
          ssl: [
            verify: :verify_none,
            versions: [:"tlsv1.2", :"tlsv1.3"]
          ]
        ]
      else
        []
      end

    http_opts = [{:timeout, timeout}, {:connect_timeout, 5_000}] ++ ssl_opts

    case :httpc.request(:post, request, http_opts, body_format: :binary) do
      {:ok, {{_version, status, _reason}, _resp_headers, resp_body}} ->
        handle_response(status, resp_body)

      {:error, reason} ->
        Logger.error("Director API request failed: #{inspect(reason)}")
        {:error, {:http_error, reason}}
    end
  end

  defp handle_response(status, body) when status >= 200 and status < 300 do
    case Jason.decode(body) do
      {:ok, %{"data" => data, "errors" => errors}} when errors != [] ->
        Logger.warning("Director API returned errors: #{inspect(errors)}")
        {:error, {:graphql_errors, errors, data}}

      {:ok, %{"data" => data}} ->
        {:ok, data}

      {:ok, %{"errors" => errors}} ->
        {:error, {:graphql_errors, errors, nil}}

      {:ok, other} ->
        {:error, {:unexpected_response, other}}

      {:error, _} ->
        {:error, {:invalid_json, body}}
    end
  end

  defp handle_response(401, _body), do: {:error, :unauthorized}
  defp handle_response(403, _body), do: {:error, :forbidden}
  defp handle_response(429, _body), do: {:error, :rate_limited}

  defp handle_response(status, body) do
    Logger.error("Director API returned HTTP #{status}: #{inspect(body)}")
    {:error, {:http_status, status, body}}
  end

  defp ensure_httpc_started do
    case :inets.start() do
      :ok -> :ok
      {:error, {:already_started, :inets}} -> :ok
    end

    case :ssl.start() do
      :ok -> :ok
      {:error, {:already_started, :ssl}} -> :ok
    end

    :ok
  end

  defp config(key) do
    Application.get_env(:netaudio, __MODULE__, [])
    |> Keyword.get(key)
  end
end
