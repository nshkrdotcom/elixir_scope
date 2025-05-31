defmodule ElixirScope.Foundation.Types do
  @moduledoc """
  Core type definitions for ElixirScope Foundation layer.

  Defines all fundamental types used throughout the ElixirScope system.
  These types serve as contracts between layers and ensure consistency.
  """

  # Time-related types
  @type timestamp :: integer()
  @type duration :: non_neg_integer()

  # ID types
  @type event_id :: pos_integer()
  @type correlation_id :: String.t()
  @type call_id :: pos_integer()

  # Result types
  @type result(success, error) :: {:ok, success} | {:error, error}
  @type result(success) :: result(success, term())

  # Location types
  @type file_path :: String.t()
  @type line_number :: pos_integer()
  @type column_number :: pos_integer()

  @type source_location :: %{
          file: file_path(),
          line: line_number(),
          column: column_number() | nil
        }

  # Process-related types
  @type process_info :: %{
          pid: pid(),
          registered_name: atom() | nil,
          status: atom(),
          memory: non_neg_integer(),
          reductions: non_neg_integer()
        }

  # Metrics types
  @type metric_name :: atom()
  @type metric_value :: number()
  @type metric_metadata :: map()

  @type performance_metric :: %{
          name: metric_name(),
          value: metric_value(),
          timestamp: timestamp(),
          metadata: metric_metadata()
        }

  # Configuration types
  @type config_key :: atom()
  @type config_value :: term()
  @type config_path :: [config_key()]

  # Event types (basic structure)
  @type event_type :: atom()
  @type event_data :: term()

  # Function-related types
  @type module_name :: module()
  @type function_name :: atom()
  @type function_arity :: arity()
  @type function_args :: [term()]

  # @type mfa :: {module_name(), function_name(), function_arity()}
  @type function_call :: {module_name(), function_name(), function_args()}

  # Error types
  @type error_reason :: atom() | String.t() | tuple()
  @type stacktrace :: [tuple()]

  # Data size types
  @type byte_size :: non_neg_integer()
  @type data_size_limit :: non_neg_integer()

  # Truncation types
  @type truncated_data :: {:truncated, byte_size(), String.t()}
  @type maybe_truncated(t) :: t | truncated_data()
end
