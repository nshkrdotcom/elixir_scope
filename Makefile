# ElixirScope Foundation Layer Development Makefile

# Variables
MIX = mix
ELIXIR = elixir

# Default environment
MIX_ENV ?= dev

# Colors for output
GREEN = \033[0;32m
YELLOW = \033[0;33m
RED = \033[0;31m
NC = \033[0m # No Color

.PHONY: help setup deps compile format credo dialyzer test smoke validate dev-workflow clean

help: ## Show this help message
	@echo "ElixirScope Foundation Layer Development Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $1, $2}'

setup: deps compile dialyzer-plt ## Complete development setup
	@echo "$(GREEN)✅ Foundation layer setup complete$(NC)"

deps: ## Install dependencies
	@echo "$(YELLOW)📦 Installing dependencies...$(NC)"
	$(MIX) deps.get
	$(MIX) deps.compile

compile: ## Compile the project
	@echo "$(YELLOW)🔨 Compiling...$(NC)"
	$(MIX) compile --warnings-as-errors

format: ## Format code
	@echo "$(YELLOW)📝 Formatting code...$(NC)"
	$(MIX) format

format-check: ## Check code formatting
	@echo "$(YELLOW)📝 Checking code formatting...$(NC)"
	$(MIX) format --check-formatted

credo: ## Run Credo static analysis
	@echo "$(YELLOW)🔍 Running Credo analysis...$(NC)"
	$(MIX) credo --strict

dialyzer-plt: ## Build Dialyzer PLT file
	@echo "$(YELLOW)🔬 Building Dialyzer PLT...$(NC)"
	$(MIX) dialyzer --plt

dialyzer: ## Run Dialyzer type checking
	@echo "$(YELLOW)🔬 Running Dialyzer...$(NC)"
	$(MIX) dialyzer --halt-exit-status

test: ## Run all tests
	@echo "$(YELLOW)🧪 Running tests...$(NC)"
	$(MIX) test

smoke: ## Run smoke tests only
	@echo "$(YELLOW)💨 Running smoke tests...$(NC)"
	$(MIX) test test/smoke/ --trace

validate: ## Validate architecture
	@echo "$(YELLOW)🏗️  Validating architecture...$(NC)"
	$(MIX) validate_architecture

dev-workflow: ## Run development workflow script
	@echo "$(YELLOW)🚀 Running development workflow...$(NC)"
	$(MIX) run scripts/dev_workflow.exs

dev-check: format-check credo compile smoke ## Quick development check
	@echo "$(GREEN)✅ Development check passed$(NC)"

ci-check: format-check credo dialyzer test validate ## Full CI check
	@echo "$(GREEN)✅ CI check passed$(NC)"

clean: ## Clean build artifacts
	@echo "$(YELLOW)🧹 Cleaning...$(NC)"
	$(MIX) clean
	$(MIX) deps.clean --all

watch: ## Watch for changes and run tests
	@echo "$(YELLOW)👁️  Watching for changes...$(NC)"
	find lib test -name "*.ex" -o -name "*.exs" | entr -c make dev-check

# Development workflow targets
quick: compile smoke ## Quick check during development
full: clean setup ci-check ## Full validation

# Documentation
docs: ## Generate documentation
	@echo "$(YELLOW)📚 Generating documentation...$(NC)"
	$(MIX) docs

# Performance testing
benchmark: ## Run performance benchmarks
	@echo "$(YELLOW)⚡ Running benchmarks...$(NC)"
	$(MIX) run scripts/benchmark.exs