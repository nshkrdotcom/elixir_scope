# ORIG_FILE
defmodule ElixirScope.Phoenix.Integration do
  @moduledoc """
  Phoenix-specific integration for ElixirScope instrumentation.

  This module provides specialized tracing for Phoenix applications including:
  - HTTP request/response lifecycle
  - LiveView mount, events, and state changes
  - Channel connections and message flow
  - Ecto query correlation
  """

  alias ElixirScope.Capture.Runtime.InstrumentationRuntime
  alias ElixirScope.Utils

  @doc """
  Enables Phoenix instrumentation by attaching telemetry handlers.
  """
  def enable do
    attach_http_handlers()
    attach_liveview_handlers()
    attach_channel_handlers()
    attach_ecto_handlers()
  end

  @doc """
  Disables Phoenix instrumentation.
  """
  def disable do
    :telemetry.detach(:elixir_scope_phoenix_http)
    :telemetry.detach(:elixir_scope_phoenix_liveview)
    :telemetry.detach(:elixir_scope_phoenix_channel)
    :telemetry.detach(:elixir_scope_phoenix_ecto)
  end

  # HTTP Request/Response Handlers

  defp attach_http_handlers do
    :telemetry.attach_many(
      :elixir_scope_phoenix_http,
      [
        [:phoenix, :endpoint, :start],
        [:phoenix, :endpoint, :stop],
        [:phoenix, :router_dispatch, :start],
        [:phoenix, :router_dispatch, :stop],
        [:phoenix, :controller, :start],
        [:phoenix, :controller, :stop]
      ],
      &handle_http_event/4,
      %{}
    )
  end

  def handle_http_event([:phoenix, :endpoint, :start], _measurements, metadata, _config) do
    correlation_id = generate_correlation_id()

    # Store correlation ID in conn for downstream use
    conn = put_correlation_id(metadata.conn, correlation_id)

    InstrumentationRuntime.report_phoenix_request_start(
      correlation_id,
      conn.method,
      conn.request_path,
      conn.params,
      conn.remote_ip
    )

    # Update metadata for downstream handlers
    %{metadata | conn: conn}
  end

  def handle_http_event([:phoenix, :endpoint, :stop], measurements, metadata, _config) do
    correlation_id = get_correlation_id(metadata.conn)

    InstrumentationRuntime.report_phoenix_request_complete(
      correlation_id,
      metadata.conn.status,
      measurements.duration,
      response_size(metadata.conn)
    )
  end

  def handle_http_event([:phoenix, :controller, :start], _measurements, metadata, _config) do
    correlation_id = get_correlation_id(metadata.conn)

    InstrumentationRuntime.report_phoenix_controller_entry(
      correlation_id,
      metadata.controller,
      metadata.action,
      metadata.params
    )
  end

  def handle_http_event([:phoenix, :controller, :stop], measurements, metadata, _config) do
    correlation_id = get_correlation_id(metadata.conn)

    InstrumentationRuntime.report_phoenix_controller_exit(
      correlation_id,
      metadata.controller,
      metadata.action,
      measurements.duration
    )
  end

  # LiveView Handlers

  defp attach_liveview_handlers do
    :telemetry.attach_many(
      :elixir_scope_phoenix_liveview,
      [
        [:phoenix, :live_view, :mount, :start],
        [:phoenix, :live_view, :mount, :stop],
        [:phoenix, :live_view, :handle_event, :start],
        [:phoenix, :live_view, :handle_event, :stop],
        [:phoenix, :live_view, :handle_info, :start],
        [:phoenix, :live_view, :handle_info, :stop]
      ],
      &handle_liveview_event/4,
      %{}
    )
  end

  def handle_liveview_event(
        [:phoenix, :live_view, :mount, :start],
        _measurements,
        metadata,
        _config
      ) do
    correlation_id = generate_correlation_id()

    # Store correlation ID in socket for downstream use
    socket = put_socket_correlation_id(metadata.socket, correlation_id)

    InstrumentationRuntime.report_liveview_mount_start(
      correlation_id,
      metadata.module,
      metadata.params,
      socket.assigns
    )

    %{metadata | socket: socket}
  end

  def handle_liveview_event([:phoenix, :live_view, :mount, :stop], measurements, metadata, _config) do
    correlation_id = get_socket_correlation_id(metadata.socket)

    InstrumentationRuntime.report_liveview_mount_complete(
      correlation_id,
      metadata.socket.assigns,
      measurements.duration
    )
  end

  def handle_liveview_event(
        [:phoenix, :live_view, :handle_event, :start],
        _measurements,
        metadata,
        _config
      ) do
    correlation_id = get_socket_correlation_id(metadata.socket)

    InstrumentationRuntime.report_liveview_handle_event_start(
      correlation_id,
      metadata.event,
      metadata.params,
      metadata.socket.assigns
    )
  end

  def handle_liveview_event(
        [:phoenix, :live_view, :handle_event, :stop],
        measurements,
        metadata,
        _config
      ) do
    correlation_id = get_socket_correlation_id(metadata.socket)

    # Capture state changes
    old_assigns = get_previous_assigns(metadata.socket)
    new_assigns = metadata.socket.assigns

    InstrumentationRuntime.report_liveview_handle_event_complete(
      correlation_id,
      metadata.event,
      old_assigns,
      new_assigns,
      measurements.duration
    )
  end

  # Channel Handlers

  defp attach_channel_handlers do
    :telemetry.attach_many(
      :elixir_scope_phoenix_channel,
      [
        [:phoenix, :channel, :join, :start],
        [:phoenix, :channel, :join, :stop],
        [:phoenix, :channel, :handle_in, :start],
        [:phoenix, :channel, :handle_in, :stop]
      ],
      &handle_channel_event/4,
      %{}
    )
  end

  def handle_channel_event([:phoenix, :channel, :join, :start], _measurements, metadata, _config) do
    correlation_id = generate_correlation_id()

    InstrumentationRuntime.report_phoenix_channel_join_start(
      correlation_id,
      metadata.socket.channel,
      metadata.socket.topic,
      metadata.params
    )
  end

  def handle_channel_event([:phoenix, :channel, :join, :stop], measurements, metadata, _config) do
    InstrumentationRuntime.report_phoenix_channel_join_complete(
      metadata.socket.channel,
      metadata.socket.topic,
      measurements.duration,
      metadata.result
    )
  end

  def handle_channel_event(
        [:phoenix, :channel, :handle_in, :start],
        _measurements,
        metadata,
        _config
      ) do
    correlation_id = generate_correlation_id()

    InstrumentationRuntime.report_phoenix_channel_message_start(
      correlation_id,
      metadata.socket.channel,
      metadata.event,
      metadata.payload
    )
  end

  def handle_channel_event([:phoenix, :channel, :handle_in, :stop], measurements, metadata, _config) do
    InstrumentationRuntime.report_phoenix_channel_message_complete(
      metadata.socket.channel,
      metadata.event,
      measurements.duration,
      metadata.result
    )
  end

  # Ecto Query Handlers

  defp attach_ecto_handlers do
    :telemetry.attach_many(
      :elixir_scope_phoenix_ecto,
      [
        [:ecto, :repo, :query, :start],
        [:ecto, :repo, :query, :stop]
      ],
      &handle_ecto_event/4,
      %{}
    )
  end

  def handle_ecto_event([:ecto, :repo, :query, :start], _measurements, metadata, _config) do
    # Try to get correlation ID from current process
    correlation_id = get_process_correlation_id() || generate_correlation_id()

    InstrumentationRuntime.report_ecto_query_start(
      correlation_id,
      metadata.repo,
      metadata.source,
      sanitize_query(metadata.query),
      length(metadata.params || [])
    )
  end

  def handle_ecto_event([:ecto, :repo, :query, :stop], measurements, metadata, _config) do
    correlation_id = get_process_correlation_id()

    InstrumentationRuntime.report_ecto_query_complete(
      correlation_id,
      metadata.repo,
      measurements.query_time,
      measurements.decode_time,
      metadata.result
    )
  end

  # Utility Functions

  defp generate_correlation_id do
    Utils.generate_correlation_id()
  end

  defp put_correlation_id(conn, correlation_id) do
    try do
      apply(Plug.Conn, :put_private, [conn, :elixir_scope_correlation_id, correlation_id])
    rescue
      UndefinedFunctionError ->
        # Fallback if Plug.Conn is not available
        %{
          conn
          | private: Map.put(conn.private || %{}, :elixir_scope_correlation_id, correlation_id)
        }
    end
  end

  defp get_correlation_id(conn) do
    conn.private[:elixir_scope_correlation_id]
  end

  defp put_socket_correlation_id(socket, correlation_id) do
    if Code.ensure_loaded?(Phoenix.LiveView) do
      # Use the assign function from the socket itself
      socket
      |> Map.update!(:assigns, &Map.put(&1, :elixir_scope_correlation_id, correlation_id))
    else
      # Fallback if Phoenix.LiveView is not available
      %{socket | assigns: Map.put(socket.assigns, :elixir_scope_correlation_id, correlation_id)}
    end
  end

  defp get_socket_correlation_id(socket) do
    socket.assigns[:elixir_scope_correlation_id]
  end

  defp get_process_correlation_id do
    Process.get(:elixir_scope_correlation_id)
  end

  defp response_size(conn) do
    try do
      case apply(Plug.Conn, :get_resp_header, [conn, "content-length"]) do
        [size] -> String.to_integer(size)
        _ -> byte_size(conn.resp_body || "")
      end
    rescue
      UndefinedFunctionError ->
        # Fallback if Plug.Conn is not available
        byte_size(conn.resp_body || "")
    end
  end

  defp get_previous_assigns(socket) do
    # This would need to be stored during previous operations
    Process.get({:elixir_scope_previous_assigns, socket.id}, %{})
  end

  defp sanitize_query(query) do
    # Remove sensitive data from query for logging
    String.replace(query, ~r/\$\d+/, "?")
  end
end
