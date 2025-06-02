defmodule ElixirScope.Foundation.ConcurrencyValidationTest do
  @moduledoc """
  Focused validation that Registry-based concurrency architecture works.
  
  Tests the critical concurrency issues we set out to solve:
  1. Process name registration conflicts
  2. Test isolation failures  
  3. State contamination
  4. Manual process management conflicts
  """

  use ElixirScope.Foundation.ConcurrentTestCase

  alias ElixirScope.Foundation.{ProcessRegistry, ServiceRegistry, TestSupervisor}

  describe "Registry Infrastructure Works" do
    test "ProcessRegistry provides namespace isolation", %{test_ref: test_ref} do
      namespace = {:test, test_ref}

      # Verify test services exist and are isolated
      test_services = ProcessRegistry.list_services(namespace)
      assert length(test_services) >= 2, "Expected isolated test services"
      
      # Verify production services exist separately  
      prod_services = ProcessRegistry.list_services(:production)
      assert length(prod_services) >= 2, "Expected production services"

      # Critical test: same service names, different PIDs = proper isolation
      {:ok, test_config_pid} = ProcessRegistry.lookup(namespace, :config_server)
      {:ok, prod_config_pid} = ProcessRegistry.lookup(:production, :config_server)
      
      assert test_config_pid != prod_config_pid, 
             "ISOLATION FAILURE: Test and production ConfigServer have same PID"
    end

    test "ServiceRegistry provides safe concurrent access", %{namespace: namespace} do
      # Verify we can lookup services safely
      assert {:ok, _pid} = ServiceRegistry.lookup(namespace, :config_server)
      assert {:ok, _pid} = ServiceRegistry.lookup(namespace, :event_store)
      
      # Verify health checks work
      assert {:ok, _pid} = ServiceRegistry.health_check(namespace, :config_server)
    end
  end

  describe "Concurrent Operations Don't Interfere" do
    test "multiple config reads work concurrently", %{namespace: namespace} do
      # Run 20 concurrent config reads
      tasks = for _i <- 1..20 do
        Task.async(fn ->
          case ServiceRegistry.lookup(namespace, :config_server) do
            {:ok, pid} -> GenServer.call(pid, :get_config)
            error -> error
          end
        end)
      end

      results = Task.await_many(tasks, 2000)
      
      # All should succeed
      assert length(results) == 20
      assert Enum.all?(results, &match?({:ok, _}, &1))
    end

    test "concurrent event storage works", %{namespace: namespace} do
      # Create 10 concurrent events
      tasks = for i <- 1..10 do
        Task.async(fn ->
          event = ElixirScope.Foundation.Events.debug_new_event(:test_event, %{id: i})
          case ServiceRegistry.lookup(namespace, :event_store) do
            {:ok, pid} -> GenServer.call(pid, {:store_event, event})
            error -> error
          end
        end)
      end

      results = Task.await_many(tasks, 2000)
      
      # All should succeed with different event IDs
      assert length(results) == 10
      assert Enum.all?(results, &match?({:ok, _}, &1))
      
      # Event IDs should be unique
      event_ids = Enum.map(results, fn {:ok, id} -> id end)
      assert length(Enum.uniq(event_ids)) == 10, "Event IDs should be unique"
    end
  end

  describe "Test Isolation Works" do
    test "multiple test namespaces don't interfere" do
      # Create two isolated test environments
      ref1 = make_ref()
      ref2 = make_ref()
      
      {:ok, _pids1} = TestSupervisor.start_isolated_services(ref1)
      {:ok, _pids2} = TestSupervisor.start_isolated_services(ref2)
      
      :ok = TestSupervisor.wait_for_services_ready(ref1)
      :ok = TestSupervisor.wait_for_services_ready(ref2)
      
      # Both should be healthy
      assert TestSupervisor.namespace_healthy?(ref1)
      assert TestSupervisor.namespace_healthy?(ref2)
      
      # Get PIDs for comparison
      {:ok, pid1} = ServiceRegistry.lookup({:test, ref1}, :config_server)
      {:ok, pid2} = ServiceRegistry.lookup({:test, ref2}, :config_server)
      
      # Critical: different processes for same service in different namespaces
      assert pid1 != pid2, "ISOLATION FAILURE: Same PID used in different test namespaces"
      
      # Cleanup
      TestSupervisor.cleanup_namespace(ref1)
      TestSupervisor.cleanup_namespace(ref2)
      
      # Both should be cleaned up
      refute TestSupervisor.namespace_healthy?(ref1)
      refute TestSupervisor.namespace_healthy?(ref2)
    end

    test "production services unaffected by test cleanup", %{test_ref: test_ref} do
      # Verify production is healthy before test cleanup
      prod_healthy_before = case ServiceRegistry.lookup(:production, :config_server) do
        {:ok, _} -> true
        _ -> false
      end
      
      # Cleanup test namespace  
      TestSupervisor.cleanup_namespace(test_ref)
      
      # Verify production still healthy after test cleanup
      prod_healthy_after = case ServiceRegistry.lookup(:production, :config_server) do
        {:ok, _} -> true
        _ -> false
      end
      
      assert prod_healthy_before == prod_healthy_after, 
             "ISOLATION FAILURE: Test cleanup affected production services"
    end
  end

  describe "Registry Stats Show Proper Separation" do
    test "registry maintains accurate namespace counts" do
      stats = ProcessRegistry.stats()
      
      assert stats.total_services >= stats.production_services
      assert stats.partitions > 0
      assert is_integer(stats.test_namespaces)
    end
  end
end 