%{
  nodes: [
    # === File: lib/elixir_scope/foundation.ex ===
    %{id: "file:lib/elixir_scope/foundation.ex", type: :FILE, label: "lib/elixir_scope/foundation.ex", properties: %{path: "lib/elixir_scope/foundation.ex"}},
    %{id: "mod:ElixirScope.Foundation", type: :MODULE, label: "ElixirScope.Foundation", properties: %{file_path: "lib/elixir_scope/foundation.ex", lines: {1, 131}}},
    %{id: "attr:mod:ElixirScope.Foundation.@moduledoc", type: :ATTRIBUTE, label: "@moduledoc", properties: %{value: "Main public API for ElixirScope Foundation layer..."}},
    %{id: "alias:ElixirScope.Foundation.Config", type: :ALIAS, label: "Config", properties: %{target_module: "ElixirScope.Foundation.Config", original_name: "ElixirScope.Foundation.Config"}},
    %{id: "alias:ElixirScope.Foundation.Events", type: :ALIAS, label: "Events", properties: %{target_module: "ElixirScope.Foundation.Events", original_name: "ElixirScope.Foundation.Events"}},
    %{id: "alias:ElixirScope.Foundation.Telemetry", type: :ALIAS, label: "Telemetry", properties: %{target_module: "ElixirScope.Foundation.Telemetry", original_name: "ElixirScope.Foundation.Telemetry"}},
    %{id: "alias:ElixirScope.Foundation.Types.Error", type: :ALIAS, label: "Error", properties: %{target_module: "ElixirScope.Foundation.Types.Error", original_name: "ElixirScope.Foundation.Types.Error"}},
    %{id: "func:ElixirScope.Foundation.initialize/1", type: :FUNCTION_DEF, label: "initialize/1", properties: %{arity: 1, kind: :public, lines: {24, 33}}},
    %{id: "spec:ElixirScope.Foundation.initialize/1", type: :SPEC, label: "initialize(keyword()) :: :ok | {:error, Error.t()}", properties: %{spec_string: "initialize(keyword()) :: :ok | {:error, Error.t()}"}},
    %{id: "param:func:ElixirScope.Foundation.initialize/1.opts", type: :PARAMETER, label: "opts", properties: %{type_string: "keyword()", default_value: "[]"}},
    %{id: "prim_type:keyword", type: :PRIMITIVE_TYPE, label: "keyword", properties: %{}},
    %{id: "prim_type:ok", type: :PRIMITIVE_TYPE, label: ":ok", properties: %{}},
    %{id: "type:ElixirScope.Foundation.Types.Error.t", type: :TYPE_USAGE, label: "Error.t()", properties: %{module: "ElixirScope.Foundation.Types.Error", type_name: "t"}}, # Note: This is a usage, definition is in Types.Error
    %{id: "func:ElixirScope.Foundation.status/0", type: :FUNCTION_DEF, label: "status/0", properties: %{arity: 0, kind: :public, lines: {46, 59}}},
    %{id: "spec:ElixirScope.Foundation.status/0", type: :SPEC, label: "status() :: {:ok, map()} | {:error, Error.t()}", properties: %{spec_string: "status() :: {:ok, map()} | {:error, Error.t()}"}},
    %{id: "prim_type:map", type: :PRIMITIVE_TYPE, label: "map", properties: %{}},
    %{id: "func:ElixirScope.Foundation.available?/0", type: :FUNCTION_DEF, label: "available?/0", properties: %{arity: 0, kind: :public, lines: {67, 69}}},
    %{id: "spec:ElixirScope.Foundation.available?/0", type: :SPEC, label: "available?() :: boolean()", properties: %{spec_string: "available?() :: boolean()"}},
    %{id: "prim_type:boolean", type: :PRIMITIVE_TYPE, label: "boolean", properties: %{}},
    %{id: "func:ElixirScope.Foundation.version/0", type: :FUNCTION_DEF, label: "version/0", properties: %{arity: 0, kind: :public, lines: {77, 79}}},
    %{id: "spec:ElixirScope.Foundation.version/0", type: :SPEC, label: "version() :: String.t()", properties: %{spec_string: "version() :: String.t()"}},
    %{id: "prim_type:string", type: :PRIMITIVE_TYPE, label: "String.t()", properties: %{}},
    %{id: "func:ElixirScope.Foundation.shutdown/0", type: :FUNCTION_DEF, label: "shutdown/0", properties: %{arity: 0, kind: :public, lines: {90, 98}}},
    %{id: "spec:ElixirScope.Foundation.shutdown/0", type: :SPEC, label: "shutdown() :: :ok", properties: %{spec_string: "shutdown() :: :ok"}},
    %{id: "func:ElixirScope.Foundation.health/0", type: :FUNCTION_DEF, label: "health/0", properties: %{arity: 0, kind: :public, lines: {110, 124}}},
    %{id: "spec:ElixirScope.Foundation.health/0", type: :SPEC, label: "health() :: {:ok, map()} | {:error, Error.t()}", properties: %{spec_string: "health() :: {:ok, map()} | {:error, Error.t()}"}},
    %{id: "func:ElixirScope.Foundation.determine_overall_health/1", type: :FUNCTION_DEF, label: "determine_overall_health/1", properties: %{arity: 1, kind: :private, lines: {128, 131}}},
    %{id: "param:func:ElixirScope.Foundation.determine_overall_health/1.service_status", type: :PARAMETER, label: "service_status", properties: %{}},

    # === File: lib/elixir_scope/foundation/application.ex ===
    %{id: "file:lib/elixir_scope/foundation/application.ex", type: :FILE, label: "lib/elixir_scope/foundation/application.ex", properties: %{path: "lib/elixir_scope/foundation/application.ex"}},
    %{id: "mod:ElixirScope.Foundation.Application", type: :MODULE, label: "ElixirScope.Foundation.Application", properties: %{file_path: "lib/elixir_scope/foundation/application.ex", lines: {1, 21}}},
    %{id: "attr:mod:ElixirScope.Foundation.Application.@moduledoc", type: :ATTRIBUTE, label: "@moduledoc", properties: %{value: "Main application module for ElixirScope Foundation layer..."}},
    %{id: "macro_usage:ElixirScope.Foundation.Application.use_Application", type: :MACRO_USAGE, label: "use Application", properties: %{macro_module: "Application"}},
    %{id: "callback_def:ElixirScope.Foundation.Application.start/2", type: :CALLBACK_DEF, label: "start/2", properties: %{behaviour: "Application", arity: 2, lines: {10, 21}}},

    # === File: lib/elixir_scope/foundation/config.ex ===
    %{id: "file:lib/elixir_scope/foundation/config.ex", type: :FILE, label: "lib/elixir_scope/foundation/config.ex", properties: %{path: "lib/elixir_scope/foundation/config.ex"}},
    %{id: "mod:ElixirScope.Foundation.Config", type: :MODULE, label: "ElixirScope.Foundation.Config", properties: %{file_path: "lib/elixir_scope/foundation/config.ex", lines: {1, 154}}},
    %{id: "attr:mod:ElixirScope.Foundation.Config.@moduledoc", type: :ATTRIBUTE, label: "@moduledoc", properties: %{value: "Public API for configuration management."}},
    %{id: "behaviour_impl:ElixirScope.Foundation.Config.ElixirScope.Foundation.Contracts.Configurable", type: :BEHAVIOUR_IMPL, label: "implements ElixirScope.Foundation.Contracts.Configurable", properties: %{}},
    %{id: "mod:ElixirScope.Foundation.Contracts.Configurable", type: :MODULE, label: "ElixirScope.Foundation.Contracts.Configurable", properties: %{file_path: "lib/elixir_scope/foundation/contracts/configurable.ex"}}, # Define if not already
    %{id: "alias:ElixirScope.Foundation.Config.ConfigServer", type: :ALIAS, label: "ConfigServer", properties: %{target_module: "ElixirScope.Foundation.Services.ConfigServer", original_name: "ElixirScope.Foundation.Services.ConfigServer"}},
    %{id: "alias:ElixirScope.Foundation.Config.Config", type: :ALIAS, label: "Config (Type)", properties: %{target_module: "ElixirScope.Foundation.Types.Config", original_name: "ElixirScope.Foundation.Types.Config"}},
    %{id: "alias:ElixirScope.Foundation.Config.Error", type: :ALIAS, label: "Error (Type)", properties: %{target_module: "ElixirScope.Foundation.Types.Error", original_name: "ElixirScope.Foundation.Types.Error"}},
    %{id: "type:ElixirScope.Foundation.Config.config_path", type: :TYPE_DEF, label: "config_path :: [atom()]", properties: %{definition: "[atom()]"}},
    %{id: "type:ElixirScope.Foundation.Config.config_value", type: :TYPE_DEF, label: "config_value :: term()", properties: %{definition: "term()"}},
    %{id: "func:ElixirScope.Foundation.Config.initialize/0", type: :FUNCTION_DEF, label: "initialize/0", properties: %{arity: 0, kind: :public, lines: {19, 21}}},
    %{id: "spec:ElixirScope.Foundation.Config.initialize/0", type: :SPEC, label: "initialize() :: :ok | {:error, Error.t()}", properties: %{}},
    %{id: "func:ElixirScope.Foundation.Config.initialize/1", type: :FUNCTION_DEF, label: "initialize/1", properties: %{arity: 1, kind: :public, lines: {29, 31}}},
    %{id: "spec:ElixirScope.Foundation.Config.initialize/1", type: :SPEC, label: "initialize(keyword()) :: :ok | {:error, Error.t()}", properties: %{}},
    %{id: "func:ElixirScope.Foundation.Config.status/0", type: :FUNCTION_DEF, label: "status/0", properties: %{arity: 0, kind: :public, lines: {39, 41}}},
    %{id: "spec:ElixirScope.Foundation.Config.status/0", type: :SPEC, label: "status() :: {:ok, map()} | {:error, Error.t()}", properties: %{}},
    %{id: "delegate_def:ElixirScope.Foundation.Config.get/0", type: :DELEGATE_DEF, label: "get/0", properties: %{to_module: "ElixirScope.Foundation.Services.ConfigServer", lines: {49,49}}},
    %{id: "spec:ElixirScope.Foundation.Config.get/0", type: :SPEC, label: "get() :: {:ok, Config.t()} | {:error, Error.t()}", properties: %{}},
    %{id: "type:ElixirScope.Foundation.Types.Config.t", type: :TYPE_USAGE, label: "Config.t()", properties: %{module: "ElixirScope.Foundation.Types.Config", type_name: "t"}},
    %{id: "delegate_def:ElixirScope.Foundation.Config.get/1", type: :DELEGATE_DEF, label: "get/1", properties: %{to_module: "ElixirScope.Foundation.Services.ConfigServer", lines: {61,61}}},
    %{id: "spec:ElixirScope.Foundation.Config.get/1", type: :SPEC, label: "get(config_path()) :: {:ok, config_value()} | {:error, Error.t()}", properties: %{}},
    %{id: "delegate_def:ElixirScope.Foundation.Config.update/2", type: :DELEGATE_DEF, label: "update/2", properties: %{to_module: "ElixirScope.Foundation.Services.ConfigServer", lines: {73,73}}},
    %{id: "spec:ElixirScope.Foundation.Config.update/2", type: :SPEC, label: "update(config_path(), config_value()) :: :ok | {:error, Error.t()}", properties: %{}},
    %{id: "delegate_def:ElixirScope.Foundation.Config.validate/1", type: :DELEGATE_DEF, label: "validate/1", properties: %{to_module: "ElixirScope.Foundation.Services.ConfigServer", lines: {83,83}}},
    %{id: "spec:ElixirScope.Foundation.Config.validate/1", type: :SPEC, label: "validate(Config.t()) :: :ok | {:error, Error.t()}", properties: %{}},
    %{id: "delegate_def:ElixirScope.Foundation.Config.updatable_paths/0", type: :DELEGATE_DEF, label: "updatable_paths/0", properties: %{to_module: "ElixirScope.Foundation.Services.ConfigServer", lines: {95,95}}},
    %{id: "spec:ElixirScope.Foundation.Config.updatable_paths/0", type: :SPEC, label: "updatable_paths() :: [config_path()]", properties: %{}},
    %{id: "delegate_def:ElixirScope.Foundation.Config.reset/0", type: :DELEGATE_DEF, label: "reset/0", properties: %{to_module: "ElixirScope.Foundation.Services.ConfigServer", lines: {104,104}}},
    %{id: "spec:ElixirScope.Foundation.Config.reset/0", type: :SPEC, label: "reset() :: :ok | {:error, Error.t()}", properties: %{}},
    %{id: "delegate_def:ElixirScope.Foundation.Config.available?/0", type: :DELEGATE_DEF, label: "available?/0", properties: %{to_module: "ElixirScope.Foundation.Services.ConfigServer", lines: {113,113}}},
    %{id: "spec:ElixirScope.Foundation.Config.available?/0", type: :SPEC, label: "available?() :: boolean()", properties: %{}},
    %{id: "func:ElixirScope.Foundation.Config.subscribe/0", type: :FUNCTION_DEF, label: "subscribe/0", properties: %{arity: 0, kind: :public, lines: {124, 126}}},
    %{id: "spec:ElixirScope.Foundation.Config.subscribe/0", type: :SPEC, label: "subscribe() :: :ok | {:error, Error.t()}", properties: %{}},
    %{id: "func:ElixirScope.Foundation.Config.unsubscribe/0", type: :FUNCTION_DEF, label: "unsubscribe/0", properties: %{arity: 0, kind: :public, lines: {134, 136}}},
    %{id: "spec:ElixirScope.Foundation.Config.unsubscribe/0", type: :SPEC, label: "unsubscribe() :: :ok", properties: %{}},
    %{id: "func:ElixirScope.Foundation.Config.get_with_default/2", type: :FUNCTION_DEF, label: "get_with_default/2", properties: %{arity: 2, kind: :public, lines: {144, 149}}},
    %{id: "spec:ElixirScope.Foundation.Config.get_with_default/2", type: :SPEC, label: "get_with_default(config_path(), config_value()) :: config_value()", properties: %{}},
    %{id: "func:ElixirScope.Foundation.Config.safe_update/2", type: :FUNCTION_DEF, label: "safe_update/2", properties: %{arity: 2, kind: :public, lines: {157, 170}}},
    %{id: "spec:ElixirScope.Foundation.Config.safe_update/2", type: :SPEC, label: "safe_update(config_path(), config_value()) :: :ok | {:error, Error.t()}", properties: %{}},

    # === File: lib/elixir_scope/foundation/events.ex ===
    %{id: "file:lib/elixir_scope/foundation/events.ex", type: :FILE, label: "lib/elixir_scope/foundation/events.ex", properties: %{path: "lib/elixir_scope/foundation/events.ex"}},
    %{id: "mod:ElixirScope.Foundation.Events", type: :MODULE, label: "ElixirScope.Foundation.Events", properties: %{file_path: "lib/elixir_scope/foundation/events.ex", lines: {1, 208}}},
    %{id: "attr:mod:ElixirScope.Foundation.Events.@moduledoc", type: :ATTRIBUTE, label: "@moduledoc", properties: %{value: "Public API for event management and storage."}},
    %{id: "behaviour_impl:ElixirScope.Foundation.Events.ElixirScope.Foundation.Contracts.EventStore", type: :BEHAVIOUR_IMPL, label: "implements ElixirScope.Foundation.Contracts.EventStore", properties: %{}},
    %{id: "mod:ElixirScope.Foundation.Contracts.EventStore", type: :MODULE, label: "ElixirScope.Foundation.Contracts.EventStore", properties: %{file_path: "lib/elixir_scope/foundation/contracts/event_store.ex"}},
    %{id: "alias:ElixirScope.Foundation.Events.EventStore", type: :ALIAS, label: "EventStore (Service)", properties: %{target_module: "ElixirScope.Foundation.Services.EventStore", original_name: "ElixirScope.Foundation.Services.EventStore"}},
    %{id: "alias:ElixirScope.Foundation.Events.Event", type: :ALIAS, label: "Event (Type)", properties: %{target_module: "ElixirScope.Foundation.Types.Event", original_name: "ElixirScope.Foundation.Types.Event"}},
    # (Skipping detailed breakdown of all Events functions due to repetition, similar to Config)
    %{id: "func:ElixirScope.Foundation.Events.new_event/3", type: :FUNCTION_DEF, label: "new_event/3", properties: %{arity: 3, kind: :public}},
    %{id: "func:ElixirScope.Foundation.Events.serialize/1", type: :FUNCTION_DEF, label: "serialize/1", properties: %{arity: 1, kind: :public}},
    %{id: "func:ElixirScope.Foundation.Events.deserialize/1", type: :FUNCTION_DEF, label: "deserialize/1", properties: %{arity: 1, kind: :public}},
    %{id: "delegate_def:ElixirScope.Foundation.Events.store/1", type: :DELEGATE_DEF, label: "store/1", properties: %{to_module: "ElixirScope.Foundation.Services.EventStore"}},

    # === File: lib/elixir_scope/foundation/telemetry.ex ===
    %{id: "file:lib/elixir_scope/foundation/telemetry.ex", type: :FILE, label: "lib/elixir_scope/foundation/telemetry.ex", properties: %{path: "lib/elixir_scope/foundation/telemetry.ex"}},
    %{id: "mod:ElixirScope.Foundation.Telemetry", type: :MODULE, label: "ElixirScope.Foundation.Telemetry", properties: %{file_path: "lib/elixir_scope/foundation/telemetry.ex", lines: {1, 175}}},
    %{id: "attr:mod:ElixirScope.Foundation.Telemetry.@moduledoc", type: :ATTRIBUTE, label: "@moduledoc", properties: %{value: "Public API for telemetry and metrics collection."}},
    %{id: "alias:ElixirScope.Foundation.Telemetry.TelemetryService", type: :ALIAS, label: "TelemetryService", properties: %{target_module: "ElixirScope.Foundation.Services.TelemetryService", original_name: "ElixirScope.Foundation.Services.TelemetryService"}},
    # (Skipping detailed breakdown of all Telemetry functions)
    %{id: "delegate_def:ElixirScope.Foundation.Telemetry.execute/3", type: :DELEGATE_DEF, label: "execute/3", properties: %{to_module: "ElixirScope.Foundation.Services.TelemetryService"}},

    # === File: lib/elixir_scope/foundation/utils.ex ===
    %{id: "file:lib/elixir_scope/foundation/utils.ex", type: :FILE, label: "lib/elixir_scope/foundation/utils.ex", properties: %{path: "lib/elixir_scope/foundation/utils.ex"}},
    %{id: "mod:ElixirScope.Foundation.Utils", type: :MODULE, label: "ElixirScope.Foundation.Utils", properties: %{file_path: "lib/elixir_scope/foundation/utils.ex", lines: {1, 298}}},
    %{id: "attr:mod:ElixirScope.Foundation.Utils.@moduledoc", type: :ATTRIBUTE, label: "@moduledoc", properties: %{value: "Pure utility functions for the Foundation layer."}},
    %{id: "func:ElixirScope.Foundation.Utils.generate_id/0", type: :FUNCTION_DEF, label: "generate_id/0", properties: %{arity: 0, kind: :public}},
    %{id: "func:ElixirScope.Foundation.Utils.monotonic_timestamp/0", type: :FUNCTION_DEF, label: "monotonic_timestamp/0", properties: %{arity: 0, kind: :public}},
    %{id: "func:ElixirScope.Foundation.Utils.truncate_if_large/2", type: :FUNCTION_DEF, label: "truncate_if_large/2", properties: %{arity: 2, kind: :public}},

    # === File: lib/elixir_scope/foundation/types.ex ===
    %{id: "file:lib/elixir_scope/foundation/types.ex", type: :FILE, label: "lib/elixir_scope/foundation/types.ex", properties: %{path: "lib/elixir_scope/foundation/types.ex"}},
    %{id: "mod:ElixirScope.Foundation.Types", type: :MODULE, label: "ElixirScope.Foundation.Types", properties: %{file_path: "lib/elixir_scope/foundation/types.ex", lines: {1, 54}}},
    %{id: "attr:mod:ElixirScope.Foundation.Types.@moduledoc", type: :ATTRIBUTE, label: "@moduledoc", properties: %{value: "Core type definitions for ElixirScope Foundation layer."}},
    %{id: "type:ElixirScope.Foundation.Types.timestamp", type: :TYPE_DEF, label: "timestamp :: integer()", properties: %{definition: "integer()"}},
    %{id: "type:ElixirScope.Foundation.Types.event_id", type: :TYPE_DEF, label: "event_id :: pos_integer()", properties: %{definition: "pos_integer()"}},
    # (More types)

    # === File: lib/elixir_scope/foundation/types/config.ex ===
    %{id: "file:lib/elixir_scope/foundation/types/config.ex", type: :FILE, label: "lib/elixir_scope/foundation/types/config.ex", properties: %{path: "lib/elixir_scope/foundation/types/config.ex"}},
    %{id: "mod:ElixirScope.Foundation.Types.Config", type: :MODULE, label: "ElixirScope.Foundation.Types.Config", properties: %{file_path: "lib/elixir_scope/foundation/types/config.ex", lines: {1, 112}}},
    %{id: "attr:mod:ElixirScope.Foundation.Types.Config.@moduledoc", type: :ATTRIBUTE, label: "@moduledoc", properties: %{value: "Pure data structure for ElixirScope configuration."}},
    %{id: "behaviour_impl:ElixirScope.Foundation.Types.Config.Access", type: :BEHAVIOUR_IMPL, label: "implements Access", properties: %{}},
    %{id: "struct:ElixirScope.Foundation.Types.Config", type: :STRUCT_DEF, label: "ElixirScope.Foundation.Types.Config", properties: %{fields: [:ai, :capture, :storage, :interface, :dev]}},
    %{id: "type:ElixirScope.Foundation.Types.Config.t", type: :TYPE_DEF, label: "t :: %__MODULE__{...}", properties: %{definition: "%__MODULE__{...}"}},
    %{id: "callback_def:ElixirScope.Foundation.Types.Config.fetch/2", type: :CALLBACK_DEF, label: "fetch/2", properties: %{behaviour: "Access", arity: 2}},
    %{id: "callback_def:ElixirScope.Foundation.Types.Config.get_and_update/3", type: :CALLBACK_DEF, label: "get_and_update/3", properties: %{behaviour: "Access", arity: 3}},
    %{id: "callback_def:ElixirScope.Foundation.Types.Config.pop/2", type: :CALLBACK_DEF, label: "pop/2", properties: %{behaviour: "Access", arity: 2}},
    %{id: "func:ElixirScope.Foundation.Types.Config.new/0", type: :FUNCTION_DEF, label: "new/0", properties: %{arity: 0, kind: :public}},
    %{id: "func:ElixirScope.Foundation.Types.Config.new/1", type: :FUNCTION_DEF, label: "new/1", properties: %{arity: 1, kind: :public}},

    # === File: lib/elixir_scope/foundation/types/event.ex ===
    %{id: "file:lib/elixir_scope/foundation/types/event.ex", type: :FILE, label: "lib/elixir_scope/foundation/types/event.ex", properties: %{path: "lib/elixir_scope/foundation/types/event.ex"}},
    %{id: "mod:ElixirScope.Foundation.Types.Event", type: :MODULE, label: "ElixirScope.Foundation.Types.Event", properties: %{file_path: "lib/elixir_scope/foundation/types/event.ex", lines: {1, 35}}},
    %{id: "attr:mod:ElixirScope.Foundation.Types.Event.@moduledoc", type: :ATTRIBUTE, label: "@moduledoc", properties: %{value: "Event data structure for ElixirScope."}},
    %{id: "struct:ElixirScope.Foundation.Types.Event", type: :STRUCT_DEF, label: "ElixirScope.Foundation.Types.Event", properties: %{fields: [:event_id, :event_type, :timestamp, :wall_time, :node, :pid, :correlation_id, :parent_id, :data]}},
    %{id: "type:ElixirScope.Foundation.Types.Event.t", type: :TYPE_DEF, label: "t :: %__MODULE__{...}", properties: %{definition: "%__MODULE__{...}"}},

    # === File: lib/elixir_scope/foundation/types/error.ex ===
    %{id: "file:lib/elixir_scope/foundation/types/error.ex", type: :FILE, label: "lib/elixir_scope/foundation/types/error.ex", properties: %{path: "lib/elixir_scope/foundation/types/error.ex"}},
    %{id: "mod:ElixirScope.Foundation.Types.Error", type: :MODULE, label: "ElixirScope.Foundation.Types.Error", properties: %{file_path: "lib/elixir_scope/foundation/types/error.ex", lines: {1, 50}}},
    %{id: "attr:mod:ElixirScope.Foundation.Types.Error.@moduledoc", type: :ATTRIBUTE, label: "@moduledoc", properties: %{value: "Pure data structure for ElixirScope errors."}},
    %{id: "struct:ElixirScope.Foundation.Types.Error", type: :STRUCT_DEF, label: "ElixirScope.Foundation.Types.Error", properties: %{fields: [:code, :error_type, :message, :severity, :context, :correlation_id, :timestamp, :stacktrace, :category, :subcategory, :retry_strategy, :recovery_actions]}},
    %{id: "type:ElixirScope.Foundation.Types.Error.t", type: :TYPE_DEF, label: "t :: %__MODULE__{...}", properties: %{definition: "%__MODULE__{...}"}},

    # === File: lib/elixir_scope/foundation/error.ex ===
    %{id: "file:lib/elixir_scope/foundation/error.ex", type: :FILE, label: "lib/elixir_scope/foundation/error.ex", properties: %{path: "lib/elixir_scope/foundation/error.ex"}},
    %{id: "mod:ElixirScope.Foundation.Error", type: :MODULE, label: "ElixirScope.Foundation.Error", properties: %{file_path: "lib/elixir_scope/foundation/error.ex", lines: {1, 190}}},
    %{id: "attr:mod:ElixirScope.Foundation.Error.@moduledoc", type: :ATTRIBUTE, label: "@moduledoc", properties: %{value: "Enhanced error handling..."}},
    %{id: "struct:ElixirScope.Foundation.Error", type: :STRUCT_DEF, label: "ElixirScope.Foundation.Error", properties: %{fields: [:code, :error_type, :message, :severity, :context, :correlation_id, :timestamp, :stacktrace, :category, :subcategory, :retry_strategy, :recovery_actions]}},
    %{id: "type:ElixirScope.Foundation.Error.t", type: :TYPE_DEF, label: "t :: %__MODULE__{...}", properties: %{definition: "%__MODULE__{...}"}},
    %{id: "func:ElixirScope.Foundation.Error.new/3", type: :FUNCTION_DEF, label: "new/3", properties: %{arity: 3, kind: :public}},

    # === File: lib/elixir_scope/foundation/error_context.ex ===
    %{id: "file:lib/elixir_scope/foundation/error_context.ex", type: :FILE, label: "lib/elixir_scope/foundation/error_context.ex", properties: %{path: "lib/elixir_scope/foundation/error_context.ex"}},
    %{id: "mod:ElixirScope.Foundation.ErrorContext", type: :MODULE, label: "ElixirScope.Foundation.ErrorContext", properties: %{file_path: "lib/elixir_scope/foundation/error_context.ex", lines: {1, 176}}},
    %{id: "attr:mod:ElixirScope.Foundation.ErrorContext.@moduledoc", type: :ATTRIBUTE, label: "@moduledoc", properties: %{value: "Enhanced error context system..."}},
    %{id: "struct:ElixirScope.Foundation.ErrorContext", type: :STRUCT_DEF, label: "ElixirScope.Foundation.ErrorContext", properties: %{fields: [:operation_id, :module, :function, :correlation_id, :start_time, :metadata, :breadcrumbs, :parent_context]}},
    %{id: "type:ElixirScope.Foundation.ErrorContext.t", type: :TYPE_DEF, label: "t :: %__MODULE__{...}", properties: %{definition: "%__MODULE__{...}"}},
    %{id: "func:ElixirScope.Foundation.ErrorContext.new/3", type: :FUNCTION_DEF, label: "new/3", properties: %{arity: 3, kind: :public}},

    # === File: lib/elixir_scope/foundation/services/config_server.ex ===
    %{id: "file:lib/elixir_scope/foundation/services/config_server.ex", type: :FILE, label: "lib/elixir_scope/foundation/services/config_server.ex", properties: %{path: "lib/elixir_scope/foundation/services/config_server.ex"}},
    %{id: "mod:ElixirScope.Foundation.Services.ConfigServer", type: :MODULE, label: "ElixirScope.Foundation.Services.ConfigServer", properties: %{file_path: "lib/elixir_scope/foundation/services/config_server.ex", lines: {1, 202}}},
    %{id: "attr:mod:ElixirScope.Foundation.Services.ConfigServer.@moduledoc", type: :ATTRIBUTE, label: "@moduledoc", properties: %{value: "GenServer implementation for configuration management."}},
    %{id: "macro_usage:ElixirScope.Foundation.Services.ConfigServer.use_GenServer", type: :MACRO_USAGE, label: "use GenServer", properties: %{macro_module: "GenServer"}},
    %{id: "behaviour_impl:ElixirScope.Foundation.Services.ConfigServer.Configurable", type: :BEHAVIOUR_IMPL, label: "implements Configurable", properties: %{behaviour_module: "ElixirScope.Foundation.Contracts.Configurable"}},
    %{id: "callback_def:ElixirScope.Foundation.Services.ConfigServer.init/1", type: :CALLBACK_DEF, label: "init/1", properties: %{behaviour: "GenServer", arity: 1}},
    %{id: "callback_def:ElixirScope.Foundation.Services.ConfigServer.handle_call/3", type: :CALLBACK_DEF, label: "handle_call/3", properties: %{behaviour: "GenServer", arity: 3}},
    %{id: "callback_def:ElixirScope.Foundation.Services.ConfigServer.handle_info/2", type: :CALLBACK_DEF, label: "handle_info/2", properties: %{behaviour: "GenServer", arity: 2}},

    # Primitive Type Nodes
    %{id: "prim_type:atom", type: :PRIMITIVE_TYPE, label: "atom", properties: %{}},
    %{id: "prim_type:integer", type: :PRIMITIVE_TYPE, label: "integer", properties: %{}},
    %{id: "prim_type:pos_integer", type: :PRIMITIVE_TYPE, label: "pos_integer", properties: %{}},
    %{id: "prim_type:non_neg_integer", type: :PRIMITIVE_TYPE, label: "non_neg_integer", properties: %{}},
    %{id: "prim_type:binary", type: :PRIMITIVE_TYPE, label: "binary", properties: %{}},
    %{id: "prim_type:pid", type: :PRIMITIVE_TYPE, label: "pid", properties: %{}},
    %{id: "prim_type:datetime", type: :PRIMITIVE_TYPE, label: "DateTime.t()", properties: %{}},
    %{id: "prim_type:term", type: :PRIMITIVE_TYPE, label: "term()", properties: %{}},

    # External Modules (simplified)
    %{id: "ext:Application", type: :EXTERNAL_MODULE, label: "Application (Erlang/Elixir)", properties: %{}},
    %{id: "ext:Supervisor", type: :EXTERNAL_MODULE, label: "Supervisor (Erlang/Elixir)", properties: %{}},
    %{id: "ext:GenServer", type: :EXTERNAL_MODULE, label: "GenServer (Erlang/Elixir)", properties: %{}},
    %{id: "ext:Process", type: :EXTERNAL_MODULE, label: "Process (Erlang/Elixir)", properties: %{}},
    %{id: "ext:System", type: :EXTERNAL_MODULE, label: "System (Erlang/Elixir)", properties: %{}},
    %{id: "ext:Logger", type: :EXTERNAL_MODULE, label: "Logger (Elixir)", properties: %{}},
    %{id: "ext:Map", type: :EXTERNAL_MODULE, label: "Map (Elixir)", properties: %{}},
    %{id: "ext:Enum", type: :EXTERNAL_MODULE, label: "Enum (Elixir)", properties: %{}},
    %{id: "ext:DateTime", type: :EXTERNAL_MODULE, label: "DateTime (Elixir)", properties: %{}},
    %{id: "ext:String", type: :EXTERNAL_MODULE, label: "String (Elixir)", properties: %{}},
    %{id: "ext:Keyword", type: :EXTERNAL_MODULE, label: "Keyword (Elixir)", properties: %{}},
    %{id: "ext:Access", type: :EXTERNAL_MODULE, label: "Access (Elixir behaviour)", properties: %{}},

    # ... more nodes for other files (EventStore, TelemetryService, Logic, Validation, Contracts, GracefulDegradation, TestHelpers)
    # Due to length constraints, I'm abbreviating the full list. The pattern is similar to above.
    %{id: "mod:ElixirScope.Foundation.Services.EventStore", type: :MODULE, label: "ElixirScope.Foundation.Services.EventStore", properties: %{file_path: "lib/elixir_scope/foundation/services/event_store.ex"}},
    %{id: "mod:ElixirScope.Foundation.Services.TelemetryService", type: :MODULE, label: "ElixirScope.Foundation.Services.TelemetryService", properties: %{file_path: "lib/elixir_scope/foundation/services/telemetry_service.ex"}},
    %{id: "mod:ElixirScope.Foundation.Logic.ConfigLogic", type: :MODULE, label: "ElixirScope.Foundation.Logic.ConfigLogic", properties: %{file_path: "lib/elixir_scope/foundation/logic/config_logic.ex"}},
    %{id: "mod:ElixirScope.Foundation.Logic.EventLogic", type: :MODULE, label: "ElixirScope.Foundation.Logic.EventLogic", properties: %{file_path: "lib/elixir_scope/foundation/logic/event_logic.ex"}},
    %{id: "mod:ElixirScope.Foundation.Validation.ConfigValidator", type: :MODULE, label: "ElixirScope.Foundation.Validation.ConfigValidator", properties: %{file_path: "lib/elixir_scope/foundation/validation/config_validator.ex"}},
    %{id: "mod:ElixirScope.Foundation.Validation.EventValidator", type: :MODULE, label: "ElixirScope.Foundation.Validation.EventValidator", properties: %{file_path: "lib/elixir_scope/foundation/validation/event_validator.ex"}},
    %{id: "mod:ElixirScope.Foundation.Config.GracefulDegradation", type: :MODULE, label: "ElixirScope.Foundation.Config.GracefulDegradation", properties: %{file_path: "lib/elixir_scope/foundation/config/graceful_degradation.ex"}},
    %{id: "mod:ElixirScope.Foundation.Events.GracefulDegradation", type: :MODULE, label: "ElixirScope.Foundation.Events.GracefulDegradation", properties: %{file_path: "lib/elixir_scope/foundation/events/graceful_degradation.ex"}},
    %{id: "mod:ElixirScope.Foundation.TestHelpers", type: :MODULE, label: "ElixirScope.Foundation.TestHelpers", properties: %{file_path: "lib/elixir_scope/foundation/test_helpers.ex"}},
  ],
  edges: [
    # === Edges for lib/elixir_scope/foundation.ex ===
    {source: "mod:ElixirScope.Foundation", target: "file:lib/elixir_scope/foundation.ex", type: :DEFINED_IN_FILE, properties: %{}},
    {source: "mod:ElixirScope.Foundation", target: "attr:mod:ElixirScope.Foundation.@moduledoc", type: :HAS_ATTRIBUTE, properties: %{}},
    {source: "mod:ElixirScope.Foundation", target: "alias:ElixirScope.Foundation.Config", type: :DEFINES_ALIAS, properties: %{}},
    {source: "alias:ElixirScope.Foundation.Config", target: "mod:ElixirScope.Foundation.Config", type: :ALIAS_TARGETS, properties: %{}},
    {source: "mod:ElixirScope.Foundation", target: "alias:ElixirScope.Foundation.Events", type: :DEFINES_ALIAS, properties: %{}},
    {source: "alias:ElixirScope.Foundation.Events", target: "mod:ElixirScope.Foundation.Events", type: :ALIAS_TARGETS, properties: %{}},
    {source: "mod:ElixirScope.Foundation", target: "alias:ElixirScope.Foundation.Telemetry", type: :DEFINES_ALIAS, properties: %{}},
    {source: "alias:ElixirScope.Foundation.Telemetry", target: "mod:ElixirScope.Foundation.Telemetry", type: :ALIAS_TARGETS, properties: %{}},
    {source: "mod:ElixirScope.Foundation", target: "alias:ElixirScope.Foundation.Types.Error", type: :DEFINES_ALIAS, properties: %{}},
    {source: "alias:ElixirScope.Foundation.Types.Error", target: "mod:ElixirScope.Foundation.Types.Error", type: :ALIAS_TARGETS, properties: %{}},
    {source: "mod:ElixirScope.Foundation", target: "func:ElixirScope.Foundation.initialize/1", type: :DEFINES_FUNCTION, properties: %{}},
    {source: "func:ElixirScope.Foundation.initialize/1", target: "spec:ElixirScope.Foundation.initialize/1", type: :HAS_SPEC, properties: %{}},
    {source: "spec:ElixirScope.Foundation.initialize/1", target: "param:func:ElixirScope.Foundation.initialize/1.opts", type: :HAS_PARAMETER_SPEC, properties: %{}},
    {source: "param:func:ElixirScope.Foundation.initialize/1.opts", target: "prim_type:keyword", type: :PARAMETER_TYPE, properties: %{}},
    {source: "spec:ElixirScope.Foundation.initialize/1", target: "prim_type:ok", type: :RETURN_TYPE, properties: %{part_of_union: true}},
    {source: "spec:ElixirScope.Foundation.initialize/1", target: "type:ElixirScope.Foundation.Types.Error.t", type: :RETURN_TYPE, properties: %{part_of_union: true, wrapper_type: ":error"}},
    {source: "func:ElixirScope.Foundation.initialize/1", target: "func:ElixirScope.Foundation.Config.initialize/1", type: :CALLS, properties: %{comment: "Inside with"}},
    {source: "func:ElixirScope.Foundation.initialize/1", target: "func:ElixirScope.Foundation.Events.initialize/0", type: :CALLS, properties: %{comment: "Inside with"}},
    {source: "func:ElixirScope.Foundation.initialize/1", target: "func:ElixirScope.Foundation.Telemetry.initialize/0", type: :CALLS, properties: %{comment: "Inside with"}},
    {source: "mod:ElixirScope.Foundation", target: "func:ElixirScope.Foundation.status/0", type: :DEFINES_FUNCTION, properties: %{}},
    {source: "func:ElixirScope.Foundation.status/0", target: "spec:ElixirScope.Foundation.status/0", type: :HAS_SPEC, properties: %{}},
    {source: "spec:ElixirScope.Foundation.status/0", target: "prim_type:map", type: :RETURN_TYPE, properties: %{part_of_union: true, wrapper_type: ":ok"}},
    {source: "func:ElixirScope.Foundation.status/0", target: "func:ElixirScope.Foundation.Config.status/0", type: :CALLS, properties: %{comment: "Inside with"}},
    # ... many more edges for calls, specs, etc.

    # === Edges for lib/elixir_scope/foundation/application.ex ===
    {source: "mod:ElixirScope.Foundation.Application", target: "file:lib/elixir_scope/foundation/application.ex", type: :DEFINED_IN_FILE, properties: %{}},
    {source: "mod:ElixirScope.Foundation.Application", target: "macro_usage:ElixirScope.Foundation.Application.use_Application", type: :USES_MACRO, properties: %{}},
    {source: "macro_usage:ElixirScope.Foundation.Application.use_Application", target: "ext:Application", type: :MACRO_MODULE, properties: %{}},
    {source: "mod:ElixirScope.Foundation.Application", target: "callback_def:ElixirScope.Foundation.Application.start/2", type: :DEFINES_FUNCTION, properties: %{comment: "@impl Application"}},
    {source: "callback_def:ElixirScope.Foundation.Application.start/2", target: "ext:Supervisor", type: :CALLS, properties: %{function_name: "start_link/2"}}, # Simplified call to Supervisor
    {source: "callback_def:ElixirScope.Foundation.Application.start/2", target: "mod:ElixirScope.Foundation.Services.ConfigServer", type: :STARTS_SERVICE, properties: %{}},
    {source: "callback_def:ElixirScope.Foundation.Application.start/2", target: "mod:ElixirScope.Foundation.Services.EventStore", type: :STARTS_SERVICE, properties: %{}},
    {source: "callback_def:ElixirScope.Foundation.Application.start/2", target: "mod:ElixirScope.Foundation.Services.TelemetryService", type: :STARTS_SERVICE, properties: %{}},
    {source: "callback_def:ElixirScope.Foundation.Application.start/2", target: "ext:Task.Supervisor", type: :STARTS_SERVICE, properties: %{}},


    # === Edges for lib/elixir_scope/foundation/config.ex ===
    {source: "mod:ElixirScope.Foundation.Config", target: "file:lib/elixir_scope/foundation/config.ex", type: :DEFINED_IN_FILE, properties: %{}},
    {source: "mod:ElixirScope.Foundation.Config", target: "behaviour_impl:ElixirScope.Foundation.Config.ElixirScope.Foundation.Contracts.Configurable", type: :IMPLEMENTS_BEHAVIOUR, properties: %{}},
    {source: "behaviour_impl:ElixirScope.Foundation.Config.ElixirScope.Foundation.Contracts.Configurable", target: "mod:ElixirScope.Foundation.Contracts.Configurable", type: :REFERENCES_BEHAVIOUR, properties: %{}},
    {source: "delegate_def:ElixirScope.Foundation.Config.get/0", target: "mod:ElixirScope.Foundation.Services.ConfigServer", type: :DELEGATES_TO_MODULE, properties: %{}},
    {source: "spec:ElixirScope.Foundation.Config.get/0", target: "type:ElixirScope.Foundation.Types.Config.t", type: :RETURN_TYPE, properties: %{part_of_union: true, wrapper_type: ":ok"}},
    {source: "func:ElixirScope.Foundation.Config.safe_update/2", target: "func:ElixirScope.Foundation.Config.updatable_paths/0", type: :CALLS, properties: %{}},
    {source: "func:ElixirScope.Foundation.Config.safe_update/2", target: "func:ElixirScope.Foundation.Config.update/2", type: :CALLS, properties: %{comment: "conditional call"}},
    {source: "func:ElixirScope.Foundation.Config.safe_update/2", target: "func:ElixirScope.Foundation.Error.new/3", type: :CALLS, properties: %{comment: "conditional error creation"}},

    # === Edges for lib/elixir_scope/foundation/types/config.ex ===
    {source: "mod:ElixirScope.Foundation.Types.Config", target: "file:lib/elixir_scope/foundation/types/config.ex", type: :DEFINED_IN_FILE, properties: %{}},
    {source: "mod:ElixirScope.Foundation.Types.Config", target: "struct:ElixirScope.Foundation.Types.Config", type: :DEFINES_STRUCT, properties: %{}},
    {source: "mod:ElixirScope.Foundation.Types.Config", target: "type:ElixirScope.Foundation.Types.Config.t", type: :DEFINES_TYPE, properties: %{}},
    {source: "type:ElixirScope.Foundation.Types.Config.t", target: "struct:ElixirScope.Foundation.Types.Config", type: :TYPE_REFS_STRUCT, properties: %{}},
    {source: "mod:ElixirScope.Foundation.Types.Config", target: "behaviour_impl:ElixirScope.Foundation.Types.Config.Access", type: :IMPLEMENTS_BEHAVIOUR, properties: %{}},
    {source: "behaviour_impl:ElixirScope.Foundation.Types.Config.Access", target: "ext:Access", type: :REFERENCES_BEHAVIOUR, properties: %{}},
    {source: "mod:ElixirScope.Foundation.Types.Config", target: "callback_def:ElixirScope.Foundation.Types.Config.fetch/2", type: :DEFINES_FUNCTION, properties: %{comment: "@impl Access"}},

    # === Edges for lib/elixir_scope/foundation/services/config_server.ex ===
    {source: "mod:ElixirScope.Foundation.Services.ConfigServer", target: "file:lib/elixir_scope/foundation/services/config_server.ex", type: :DEFINED_IN_FILE, properties: %{}},
    {source: "mod:ElixirScope.Foundation.Services.ConfigServer", target: "macro_usage:ElixirScope.Foundation.Services.ConfigServer.use_GenServer", type: :USES_MACRO, properties: %{}},
    {source: "macro_usage:ElixirScope.Foundation.Services.ConfigServer.use_GenServer", target: "ext:GenServer", type: :MACRO_MODULE, properties: %{}},
    {source: "mod:ElixirScope.Foundation.Services.ConfigServer", target: "behaviour_impl:ElixirScope.Foundation.Services.ConfigServer.Configurable", type: :IMPLEMENTS_BEHAVIOUR, properties: %{}},
    {source: "callback_def:ElixirScope.Foundation.Services.ConfigServer.init/1", target: "mod:ElixirScope.Foundation.Logic.ConfigLogic", type: :CALLS, properties: %{function_name: "build_config/1"}},
    {source: "callback_def:ElixirScope.Foundation.Services.ConfigServer.handle_call/3", target: "mod:ElixirScope.Foundation.Logic.ConfigLogic", type: :CALLS, properties: %{function_name: "get_config_value/2", comment: "for :get_config_path"}},
    {source: "callback_def:ElixirScope.Foundation.Services.ConfigServer.handle_call/3", target: "mod:ElixirScope.Foundation.Logic.ConfigLogic", type: :CALLS, properties: %{function_name: "update_config/3", comment: "for :update_config"}},
    {source: "callback_def:ElixirScope.Foundation.Services.ConfigServer.handle_info/2", target: "ext:Logger", type: :CALLS, properties: %{function_name: "warning/1", comment: "on unexpected message"}},

    # ... More edges for other files and relationships.
    # This is a representative subset to illustrate the structure.
    # A full graph would be significantly larger.
    {source: "mod:ElixirScope.Foundation.Logic.ConfigLogic", target: "mod:ElixirScope.Foundation.Types.Config", type: :USES_TYPE, properties: %{comment: "for Config.t()"}},
    {source: "mod:ElixirScope.Foundation.Logic.ConfigLogic", target: "mod:ElixirScope.Foundation.Validation.ConfigValidator", type: :CALLS_MODULE, properties: %{comment: "for validation"}},
    {source: "mod:ElixirScope.Foundation.Validation.ConfigValidator", target: "mod:ElixirScope.Foundation.Types.Config", type: :USES_TYPE, properties: %{comment: "for Config.t()"}},
    {source: "mod:ElixirScope.Foundation.Validation.ConfigValidator", target: "mod:ElixirScope.Foundation.Types.Error", type: :USES_TYPE, properties: %{comment: "for Error.t()"}},
    {source: "mod:ElixirScope.Foundation.Config.GracefulDegradation", target: "mod:ElixirScope.Foundation.Config", type: :INTERACTS_WITH, properties: %{comment: "fallback logic for Config API"}},
    {source: "mod:ElixirScope.Foundation.Events.GracefulDegradation", target: "mod:ElixirScope.Foundation.Events", type: :INTERACTS_WITH, properties: %{comment: "fallback logic for Events API"}},
    {source: "mod:ElixirScope.Foundation.TestHelpers", target: "mod:ElixirScope.Foundation.Config", type: :USES_MODULE_IN_TESTS, properties: %{}},
    {source: "mod:ElixirScope.Foundation.TestHelpers", target: "mod:ElixirScope.Foundation.Events", type: :USES_MODULE_IN_TESTS, properties: %{}},
  ]
}