defmodule ElixirScope.Foundation.Types.Config do
  @moduledoc """
  Pure data structure for ElixirScope configuration.

  Contains no business logic - just data and Access implementation.
  All validation and manipulation logic is in separate modules.
  """

  @behaviour Access

  defstruct [
    # AI Configuration
    ai: %{
      provider: :mock,
      api_key: nil,
      model: "gpt-4",
      analysis: %{
        max_file_size: 1_000_000,
        timeout: 30_000,
        cache_ttl: 3600
      },
      planning: %{
        default_strategy: :balanced,
        performance_target: 0.01,
        sampling_rate: 1.0
      }
    },

    # Capture Configuration
    capture: %{
      ring_buffer: %{
        size: 1024,
        max_events: 1000,
        overflow_strategy: :drop_oldest,
        num_buffers: :schedulers
      },
      processing: %{
        batch_size: 100,
        flush_interval: 50,
        max_queue_size: 1000
      },
      vm_tracing: %{
        enable_spawn_trace: true,
        enable_exit_trace: true,
        enable_message_trace: false,
        trace_children: true
      }
    },

    # Storage Configuration
    storage: %{
      hot: %{
        max_events: 100_000,
        max_age_seconds: 3600,
        prune_interval: 60_000
      },
      warm: %{
        enable: false,
        path: "./elixir_scope_data",
        max_size_mb: 100,
        compression: :zstd
      },
      cold: %{
        enable: false
      }
    },

    # Interface Configuration
    interface: %{
      query_timeout: 10_000,
      max_results: 1000,
      enable_streaming: true
    },

    # Development Configuration
    dev: %{
      debug_mode: false,
      verbose_logging: false,
      performance_monitoring: true
    }
  ]

  @type t :: %__MODULE__{
          ai: map(),
          capture: map(),
          storage: map(),
          interface: map(),
          dev: map()
        }

  ## Access Behavior Implementation

  @impl Access
  def fetch(%__MODULE__{} = config, key) do
    config
    |> Map.from_struct()
    |> Map.fetch(key)
  end

  @impl Access
  def get_and_update(%__MODULE__{} = config, key, function) do
    map_config = Map.from_struct(config)

    case Map.get_and_update(map_config, key, function) do
      {current_value, updated_map} ->
        case struct(__MODULE__, updated_map) do
          updated_config when is_struct(updated_config, __MODULE__) ->
            {current_value, updated_config}

          _ ->
            {current_value, config}
        end
    end
  end

  @impl Access
  def pop(%__MODULE__{} = config, key) do
    map_config = Map.from_struct(config)
    {value, updated_map} = Map.pop(map_config, key)
    updated_config = struct(__MODULE__, updated_map)
    {value, updated_config}
  end

  @doc """
  Create a new configuration with default values.
  """
  @spec new() :: %__MODULE__{
          ai: %{
            analysis: %{cache_ttl: 3600, max_file_size: 1_000_000, timeout: 30000},
            api_key: nil,
            model: <<_::40>>,
            planning: %{
              default_strategy: :balanced,
              performance_target: float(),
              sampling_rate: float()
            },
            provider: :mock
          },
          capture: %{
            processing: %{batch_size: 100, flush_interval: 50, max_queue_size: 1000},
            ring_buffer: %{
              max_events: 1000,
              num_buffers: :schedulers,
              overflow_strategy: :drop_oldest,
              size: 1024
            },
            vm_tracing: %{
              enable_exit_trace: true,
              enable_message_trace: false,
              enable_spawn_trace: true,
              trace_children: true
            }
          },
          dev: %{
            debug_mode: false,
            performance_monitoring: true,
            verbose_logging: false
          },
          interface: %{enable_streaming: true, max_results: 1000, query_timeout: 10000},
          storage: %{
            cold: %{enable: false},
            hot: %{max_age_seconds: 3600, max_events: 100_000, prune_interval: 60000},
            warm: %{
              compression: :zstd,
              enable: false,
              max_size_mb: 100,
              path: <<_::152>>
            }
          }
        }
  def new, do: %__MODULE__{}

  @doc """
  Create a new configuration with overrides.
  """
  @spec new(keyword()) :: t()
  def new(overrides) do
    config = new()
    Enum.reduce(overrides, config, fn {key, value}, acc ->
      case Map.get(acc, key) do
        existing_value when is_map(existing_value) and is_map(value) ->
          # Deep merge maps
          merged_value = deep_merge(existing_value, value)
          Map.put(acc, key, merged_value)
        _ ->
          # Replace non-map values
          Map.put(acc, key, value)
      end
    end)
  end

  # Helper function for deep merging maps
  defp deep_merge(original, override) when is_map(original) and is_map(override) do
    Map.merge(original, override, fn _key, v1, v2 ->
      if is_map(v1) and is_map(v2) do
        deep_merge(v1, v2)
      else
        v2
      end
    end)
  end
end
