




# defmodule ElixirScope.Foundation.Types do
#   @moduledoc """
#   Core type definitions for ElixirScope Foundation layer.

#   Provides common type definitions and protocols used across
#   the Foundation layer and higher layers of ElixirScope.
#   """

#   @typedoc """
#   A unique identifier for events and other entities.
#   Composed of a timestamp and random component for uniqueness.
#   """
#   @type event_id :: non_neg_integer()

#   @typedoc """
#   A high-resolution timestamp in nanoseconds.
#   Used for event ordering and duration measurements.
#   """
#   @type timestamp :: non_neg_integer()

#   @typedoc """
#   A correlation ID for tracing related events.
#   Uses UUID v4 format for compatibility with external systems.
#   """
#   @type correlation_id :: String.t()

#   @typedoc """
#   A path in the configuration tree.
#   Used for accessing and updating configuration values.
#   """
#   @type config_path :: [atom()]

#   @typedoc """
#   A configuration value of any type.
#   """
#   @type config_value :: term()

#   @typedoc """
#   A result type that can be either success or error.
#   """
#   @type result(ok_type, error_type) :: {:ok, ok_type} | {:error, error_type}

#   @typedoc """
#   A result type that can be either success or error with metadata.
#   """
#   @type result_with_meta(ok_type, error_type, meta_type) ::
#     {:ok, ok_type, meta_type} | {:error, error_type, meta_type}

#   @typedoc """
#   A validation result with optional error details.
#   """
#   @type validation_result :: :ok | {:error, term()}

#   @typedoc """
#   A measurement result with duration in nanoseconds.
#   """
#   @type measurement_result(t) :: {t, non_neg_integer()}

#   @typedoc """
#   A memory measurement result with before, after, and difference values.
#   """
#   @type memory_measurement_result(t) :: {t, {non_neg_integer(), non_neg_integer(), integer()}}

#   @typedoc """
#   A telemetry event name as a list of atoms.
#   """
#   @type telemetry_event :: [atom()]

#   @typedoc """
#   A telemetry measurement map.
#   """
#   @type telemetry_measurements :: %{
#     optional(:duration) => non_neg_integer(),
#     optional(:count) => non_neg_integer(),
#     optional(:value) => number(),
#     optional(:error_count) => non_neg_integer(),
#     required(:timestamp) => timestamp()
#   }

#   @typedoc """
#   A telemetry metadata map.
#   """
#   @type telemetry_metadata :: %{
#     optional(:module) => module(),
#     optional(:function) => atom(),
#     optional(:args) => list(),
#     optional(:error_type) => module(),
#     optional(:error_message) => String.t(),
#     optional(atom()) => term()
#   }

#   @typedoc """
#   A process statistics map.
#   """
#   @type process_stats :: %{
#     required(:memory) => non_neg_integer(),
#     required(:reductions) => non_neg_integer(),
#     required(:message_queue_len) => non_neg_integer(),
#     required(:timestamp) => timestamp()
#   }

#   @typedoc """
#   A system statistics map.
#   """
#   @type system_stats :: %{
#     required(:process_count) => non_neg_integer(),
#     required(:total_memory) => non_neg_integer(),
#     required(:scheduler_count) => non_neg_integer(),
#     required(:otp_release) => String.t(),
#     required(:timestamp) => timestamp()
#   }
# end
