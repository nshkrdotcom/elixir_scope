defmodule ElixirScope.Foundation.ConfigTest do
  # Config tests must be synchronous
  use ExUnit.Case, async: false
  @moduletag :foundation

  alias ElixirScope.Foundation.{Config, Error}
  alias ElixirScope.Foundation.TestHelpers

  setup do
    # Ensure Config GenServer is available
    :ok = TestHelpers.ensure_config_available()

    # Store original config for restoration
    original_config = Config.get()

    on_exit(fn ->
      # Restore any changed values
      try do
        if GenServer.whereis(Config) do
          # Restore sampling rate if changed
          case original_config do
            %Config{ai: %{planning: %{sampling_rate: rate}}} ->
              Config.update([:ai, :planning, :sampling_rate], rate)

            _ ->
              :ok
          end
        end
      catch
        :exit, _ -> :ok
      end
    end)

    %{original_config: original_config}
  end

  describe "configuration validation" do
    test "validates default configuration" do
      config = %Config{}
      assert :ok = Config.validate(config)
    end

    test "validates complete AI configuration" do
      config = %Config{
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
        }
      }

      assert :ok = Config.validate(config)
    end

    test "rejects invalid AI provider" do
      config = %Config{
        ai: %{
          provider: :invalid_provider,
          analysis: %{max_file_size: 1000, timeout: 1000, cache_ttl: 1000},
          planning: %{default_strategy: :balanced, performance_target: 0.01, sampling_rate: 1.0}
        }
      }

      assert {:error, %Error{code: :invalid_config_value}} = Config.validate(config)
    end

    test "rejects invalid sampling rate" do
      config = %Config{
        ai: %{
          provider: :mock,
          analysis: %{max_file_size: 1000, timeout: 1000, cache_ttl: 1000},
          planning: %{
            default_strategy: :balanced,
            performance_target: 0.01,
            # Invalid: > 1.0
            sampling_rate: 1.5
          }
        }
      }

      assert {:error, %Error{code: :range_error}} = Config.validate(config)
    end
  end

  describe "configuration server operations" do
    test "gets full configuration", %{original_config: _config} do
      config = Config.get()
      assert %Config{} = config
      assert config.ai.provider == :mock
    end

    test "gets configuration by path", %{original_config: _config} do
      provider = Config.get([:ai, :provider])
      assert provider == :mock

      sampling_rate = Config.get([:ai, :planning, :sampling_rate])
      assert is_number(sampling_rate)
      assert sampling_rate >= 0
      assert sampling_rate <= 1
    end

    test "updates allowed configuration paths", %{original_config: _config} do
      assert :ok = Config.update([:ai, :planning, :sampling_rate], 0.8)

      updated_rate = Config.get([:ai, :planning, :sampling_rate])
      assert updated_rate == 0.8
    end

    test "rejects updates to forbidden paths", %{original_config: _config} do
      result = Config.update([:ai, :provider], :openai)
      assert {:error, %Error{code: :config_update_forbidden}} = result

      # Verify unchanged
      provider = Config.get([:ai, :provider])
      assert provider == :mock
    end

    test "validates updates before applying", %{original_config: _config} do
      result = Config.update([:ai, :planning, :sampling_rate], 1.5)
      assert {:error, %Error{code: :range_error}} = result
    end
  end

  test "handles service unavailable gracefully" do
    # Stop the config server
    if pid = GenServer.whereis(Config) do
      GenServer.stop(pid)
    end

    # Calls should return service unavailable error
    assert {:error, %Error{code: :service_unavailable}} = Config.get()
    assert {:error, %Error{code: :service_unavailable}} = Config.get([:ai, :provider])

    assert {:error, %Error{code: :service_unavailable}} =
             Config.update([:ai, :planning, :sampling_rate], 0.5)

    # Restart for cleanup
    TestHelpers.ensure_config_available()
  end
end
