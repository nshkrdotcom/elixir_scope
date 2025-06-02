# Elixir, Poolboy, and Little's Law

-----

**Samuel Mullen**

[Articles](https://www.google.com/search?q=null) | [About](https://www.google.com/search?q=null) | [Contact](https://www.google.com/search?q=null)

With its simple and expressive syntax, Elixir is often compared to the Ruby programming language. It’s easy to see why: function definitions, `do/end` blocks, exclamatory and interrogatory variable naming, and even function names all arise from—or at least were heavily influenced by—Ruby. But saying Elixir is like Ruby because it shares some syntax features is akin to saying I’m like Steve Jobs because I wear black turtlenecks. I’m not, and I don’t.

In truth, Elixir shares far more similarities with its technological parent, Erlang, than it ever could with Ruby. Although it shares few syntactical similarities, as with most things, it’s what’s below the surface that counts. In this case, it’s the **BEAM**, which means that like Erlang, Elixir is a concurrent programming language.

Because it’s built on the BEAM, Elixir is easily capable of handling thousands, hundreds of thousands, or even millions of processes at a time. Unfortunately, not every system we interact with has this same capability. Databases, cloud services, and internal and external APIs regularly set limits on how much and how often we can access them. So, even though our Elixir applications can handle massive concurrency, we must sometimes impose limits on our own applications to accommodate them.

## Worker Pools

A simple way to enforce connection limits is through the use of **worker pools** or **thread pools**. Put simply, a worker pool is a design pattern for limiting the number of processes or threads created for a specific task. In most programming languages, using a worker pool “increases performance and avoids latency in execution due to frequent creation and destruction of threads for short-lived tasks.” But this isn’t a problem for the BEAM. Instead, rather than using worker pools to increase efficiency, Erlang and Elixir developers tend to use them to enforce limits, reducing efficiency.

One way to envision a worker pool is to imagine a group of 20 teenagers who work for a lawn mowing service. The lawn mowing service has 10 mowers. When a teenager gets a mowing assignment, they “check out” a mower. Then, when the teenager completes the assignment, they check the mower back in, freeing it up for the next teenager in line. While a mower is checked out, teenagers must either go do something else, or wait until one is returned. In this scenario, teenagers may be in a position of waiting, but it has the advantage of ensuring all lawn mowers are used to capacity.

Worker pools work the same way. You create a pool of workers to handle a specific task. When processes need a worker, they check one out, use it, and then check it back in. When all workers are fully utilized, requesting processes queue up, waiting for workers to become available.

An easy way to know if you need a worker pool is to examine the outputs. As mentioned above, databases, cloud services, and APIs often restrict the number of connections they allow. These are all moments to make use of a pool of workers. “Essentially, this technique keeps the concurrency level under control, and it works best when dealing with resources that can’t cope with a large number of concurrent requests.” (Elixir in Action)

Consider these conditions to decide if you need a worker pool:

  * There are access (i.e. connection) constraints
  * There are clearly defined resource constraints
  * There are internally imposed limits

If there are no output constraints, a worker pool may not be the right choice for your situation.

-----

## Poolboy

There are no official, or even popular, Elixir worker pool libraries, but if you know **Just Enough Erlang**, you can take advantage of the excellent **Poolboy** library. If you’ve never heard of it, “Poolboy is a lightweight, generic pooling library for Erlang with a focus on simplicity, performance, and rock-solid disaster recovery.” The library lives up to its description.

Installing Poolboy is no different from any other **Hex** package, and once installed, you can start using Poolboy with three simple steps:

1.  Create a worker for the pool
2.  Start the Poolboy supervisor configured to use the worker
3.  Make use of workers

Let’s look at each of these steps:

### Create a Worker for the Pool

Poolboy workers are GenServers. When the Poolboy supervisor starts, it creates a supervised process for each worker, then, as requests come in, Poolboy hands out these GenServer workers to do the work.

For our example, we’ll create a simple GenServer to square numbers passed into it.

```elixir
defmodule MyApp.SquareWorker do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil)
  end

  def init(_) do
    {:ok, nil}
  end

  def handle_call({:square, x}, _from, state) do
    IO.puts("PID: #{inspect(self())} - #{x * x}")
    Process.sleep(1000)

    {:reply, x * x, state}
  end
end
```

The GenServer is very basic, and even so, there are a few points to note. First, you’ll see we didn’t give the GenServer a name in `GenServer.start_link/2`. This is because Poolboy starts multiple instances of the GenServer and defining a name causes a conflict.

The next thing to note is that we’re not storing state. It starts as `nil` and is never changed. There are certainly times to keep state with pool workers—such as keeping a DB connection—but we don’t need to in our example.

Lastly, calls to `:square` receive a number and return its square after a one-second delay. We also output some information to see what’s going on. The one-second delay becomes important later in our experiments.

### Start the Poolboy Supervisor

With our worker created, we can now configure and start Poolboy in our application. It’s oftentimes easier to do this in its own supervisor, but for the purposes of our example, we’ll do this in the `application.ex` file.

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      :poolboy.child_spec(:square_worker, poolboy_config())
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp poolboy_config do
    [
      name: {:local, :square_worker},
      worker_module: MyApp.SquareWorker,
      size: 5,
      max_overflow: 0
    ]
  end
end
```

To add Poolboy to the list of supervised processes, we use the `:poolboy.child_spec/2` function, passing it a unique identifier for the first argument (the pool’s name), and a list of properties for the second. In the example, we used a function to return a property list, but that’s not necessary. Let’s look at each of the available properties:

  * **name**: A two-item tuple comprised of `:global`, `:local`, or `:via`, and the pool’s name. It’s unlikely you’ll use anything other than `:local`. The other options deal with registering the process in the global registry or in a separate registry altogether.
  * **worker\_module**: This is the name of the module which holds the worker’s logic. In our case, it’s `MyApp.SquareWorker`.
  * **size**: Defines the number of workers which are always running.
  * **max\_overflow**: Defines the number of extra workers to launch when load exceeds the available workers.
  * **strategy** (not shown): “`lifo` or `fifo`, determines whether checked-in workers should be placed first or last in the line of available workers. So, `lifo` operates like a traditional stack; `fifo` like a queue. Default is `lifo`.”

With the worker and Poolboy set up, let’s turn our attention to how to use them.

### Make Use of Workers

There are two ways to make use of Poolboy: 1) manually check processes in and out; 2) use Poolboy’s transaction function. We’ll look at each in turn:

#### Checking Processes In and Out

Checking processes in and out of Poolboy’s worker pool is accomplished with the appropriately named `checkout/3` and `checkin/2` functions. Here’s an example of how you might do it:

```elixir
iex 1> worker_pid = :poolboy.checkout(:square_worker)
#PID<0.187.0>
iex 2> GenServer.call(worker_pid, {:square, 4})
PID: #PID<0.187.0> - 16
16
iex 3> :poolboy.checkin(:square_worker, worker_pid)
:ok
```

Here, the first thing we do is “check out” a worker (i.e., PID to a GenServer) from the `:square_worker` pool. Next, we use the `GenServer.call/3` function, passing along the worker PID, and the argument to be matched against. Once the call to GenServer is completed, we check the worker back in to the `:square_worker` pool.

Our pool is set up to handle five workers. What would happen if we performed a checkout six times? If you try this, and wait patiently (i.e., more than 5 seconds), you’ll see the following error:

```
** (exit) exited in: :gen_server.call(:worker, {:checkout, #Reference<0.797852558.3545497601.41814>, true}, 5000)
    ** (EXIT) time out
    (stdlib) gen_server.erl:223: :gen_server.call/3
    (poolboy) /Users/samullen/sandbox/elixir/my_app/deps/poolboy/src/poolboy.erl:63: :poolboy.checkout/3
```

You may have expected Poolboy to refuse your sixth request, but it doesn’t. Instead, it queues it up to be used once a worker is freed. Because Poolboy, like all GenServers, has a five-second timeout, the process crashes once the timeout has expired. There are a few ways to handle this:

  * Provide a larger timeout when you check out the process
  * “Block” processes from checkout attempts when no workers are available
  * Increase the number of processes in the configuration
  * Give an overflow value in the configuration

To increase the timeout, you merely need to pass it along with a “block” value when checking out:

```elixir
iex 4> worker_pid = :poolboy.checkout(:square_worker, true, 20_000)
```

There are times when increasing the timeout makes sense, but it feels…dirty.

Next, you can pass `false` for the `:block` value and handle things manually. Here’s an example of a function you could write to do just that:

```elixir
def squarer(x) do
  case :poolboy.checkout(:square_worker, false) do
    :full ->
      Process.sleep 100
      squarer(x)

    worker_pid ->
      GenServer.call(worker_pid, {:square, x})
      :poolboy.checkin(:square_worker, worker_pid)
  end
end
```

The last two options, increasing `:size` and `:max_overflow`, should be self-explanatory.

Like handling memory allocation in C, manually checking processes in and out is potentially error-prone. Instead of inviting memory leaks, however, you quickly exceed your pool size and your process dies. Thankfully, this is much easier to track down than memory leaks in C.

If performing a `checkout` and `checkin` each time you want to work with a pool seems like one step too many, you can use Poolboy’s `transaction/2` function.

#### Transactions

The best way to think about Poolboy transactions is similar to how Wikipedia describes **database transactions**. They “symbolize a unit of work performed…, and [are] treated in a coherent and reliable way independent of other transactions.” The check-in/check-out process is handled for you. You’re responsible for providing the transaction’s logic.

Here’s what a transaction looks like in all its glory:

```elixir
:poolboy.transaction(:square_worker, fn pid ->
  GenServer.call(pid, {:square, 4})
end)
```

With this knowledge, we can now use Poolboy to calculate squares for us in groups of five (the pool size we defined above).

```elixir
defmodule MyApp.Tester do
  def run do
    1..25
    |> Enum.map(&spawn_workers/1)
    |> Enum.map(&Task.await/1)
  end

  def spawn_workers(i) do
    Task.async(fn ->
      :poolboy.transaction(:square_worker, fn pid ->
        GenServer.call(pid, {:square, i})
      end)
    end)
  end
end
```

In the code above, we are using the `Task` module to launch new processes, each of which uses `:poolboy.transaction/2` to square the integer provided to it (from 1 to 25). In spite of there being five worker GenServers, we still need to use `Task.async/1` (or even `spawn/1`) if we want to do any sort of concurrent work.

Once we map the integers through `Task.async/1`, we must then wait for each of them to finish with `Task.await/1`.

Running this, we see the resulting output, five lines at a time:

```
iex [19:18 :: 1] > MyApp.Tester.run
PID: #PID<0.190.0> - 1
PID: #PID<0.189.0> - 4
PID: #PID<0.187.0> - 16
PID: #PID<0.188.0> - 9
PID: #PID<0.186.0> - 25
PID: #PID<0.187.0> - 36
PID: #PID<0.188.0> - 49
PID: #PID<0.189.0> - 100
PID: #PID<0.190.0> - 64
PID: #PID<0.186.0> - 81
PID: #PID<0.186.0> - 144
PID: #PID<0.188.0> - 169
PID: #PID<0.190.0> - 225
PID: #PID<0.189.0> - 196
PID: #PID<0.187.0> - 121
PID: #PID<0.186.0> - 289
PID: #PID<0.187.0> - 256
PID: #PID<0.188.0> - 361
PID: #PID<0.189.0> - 324
PID: #PID<0.190.0> - 400
PID: #PID<0.186.0> - 441
PID: #PID<0.187.0> - 484
PID: #PID<0.188.0> - 529
PID: #PID<0.190.0> - 625
PID: #PID<0.189.0> - 576
[1, 4, 9, 16, 25, 36, 49, 64, 81, 100, 121, 144, 169, 196, 225, 256, 289,
 324, 361, 400, 441, 484, 529, 576, 625]
iex [19:18 :: 2] >
```

Being mindful of GenServer’s default timeout, what do you think will happen if we increase the range from `1..25` to `1..26`? If you answered, “the server dies and everything in the mailbox is lost,” you’re right.

How do we handle this? Unlike using Poolboy’s `checkin/checkout` functions, `transaction/2` doesn’t offer a way to return a `:full` response. The only thing we can do is increase the process count. But by how much?

-----

## Little’s Law

To figure out how many processes to use, we need two pieces of information: the arrival rate of the data and the average processing time. This calculation was “discovered” by John Little and states that “the long-term average number $L$ of customers in a stationary system is equal to the long-term average effective arrival rate $\\lambda$ multiplied by the average time $W$ that a customer spends in the system.” (Little’s Law). The formula looks like this:

$$L = \lambda W$$

Where:

  * $L$: Customers in a stationary system. Items in the queue.
  * $\\lambda$: Arrival Rate or throughput
  * $W$: Average wait time in the queueing system

For our situation, we know $W$ is one second, because that’s the value we’re passing to `Process.sleep/1`. Unfortunately, $\\lambda$ is a problem at the moment, because passing a range to `Enum.map/2` is effectively an infinite speed. Since we won’t deal with infinite throughputs in the “real world”, let’s tweak our test runner so our calculations make more sense.

```elixir
defmodule MyApp.Tester do
  def run do
    1..100
    |> Stream.map(fn i ->
      Process.sleep(100)
      spawn_workers(i)
    end)
    |> Enum.to_list()
    |> Enum.map(&Task.await/1)
  end

  def spawn_workers(i) do
    Task.async(fn ->
      :poolboy.transaction(:worker, fn pid ->
        GenServer.call(pid, {:square, i})
      end)
    end)
  end
end
```

By adding `Stream.map/2` and `Enum.to_list/1` to the pipeline in `Tester.run/0`, we’ve slowed the arrival rate to 10 (1 arrival / 100ms). Because we’ve added a delay to our arrival rate, it also makes sense to increase the number of requests from 25 to 100. Now our formula looks like this for a single process:

$10 = 10 \\cdot 1$

Since we have a pool of five workers, we need to change $W$, the average wait time, to 0.2 (1 / 5 = 0.2).

$2 = 10 \\cdot 0.2$

We now have two items in the queue at any given time. The question is, is that enough to get us around the default five-second timeout? We can figure that out by multiplying $L$ by $W$, or $2 \\cdot 0.2$. The resulting value, 0.4, is twice the amount of time items stay in the queueing system, which means our queue is going to continue to expand until the timeout is reached. If you run `Tester.run/0` with the new code, you’ll see it die at item 56.

We have three choices now: If we are not constrained by the number of connections we can create, we can increase the pool to 10, bringing the time in queue ($W$) in line with the arrival rate ($\\lambda$). Alternatively, if we are constrained by the number of connections, we can work at improving the time items spend in the queue ($W$). Lastly, and this usually isn’t what you want to do, we can slow down how fast we receive requests.

When we increase the pool count to 10 and rerun our `Tester.run` function, we reach equilibrium and are able to successfully output the square of all 100 numbers.

### Overflow

The system we’ve created is, for the most part, unchanging. Requests come in every tenth of a second, and are processed every second. There is no variation. It’s unlikely you’ll ever work with a system like this outside of practice examples. Instead, what we usually deal with is the ebb and flow of everyday life. Websites, APIs, and our backend processes all experience spikes in traffic; some due to normal daily life, and others due to “breaking” news.

It’s these spikes that Poolboy’s `:max_overflow` option was designed to address. If you’ve already used Little’s Law to calculate the number of processes you need, and you know the amount of traffic increases you regularly experience, it’s a simple matter to calculate the overflow value.

From our example, if we were to get an increase in throughput from 10/sec to 15/sec at certain times of the day, we could see there’s a 50% increase in traffic (($15 - 10) / 10 \\cdot 100$). Based on this, we know our `:max_overflow` value needs to be 50% of our pool `:size`: i.e., 5.

Again, this only works if you have connections available to use. If that’s not an option, you’ll need to address improving algorithm efficiency.

-----

## Summary

In many languages, thread pools greatly simplify and reduce the overhead of creating new threads to perform tasks. With the BEAM’s ability to easily create thousands of processes in less memory than other languages take to make a single thread, this isn’t useful to Elixir. Instead, we use worker pools to impose limits on our processes to keep from overwhelming systems with which we interact.

**Poolboy** is a simple and robust library we can use to bring worker pools to our Elixir projects. All that’s required is to define the pool’s name, the worker to use, and how many workers should be made available. This latter piece being a basic calculation of **Little’s Law**.

**Little’s Law** states that “the long-term average number $L$ of customers in a stationary system is equal to the long-term average effective arrival rate $\\lambda$ multiplied by the average time $W$ that a customer spends in the system.” It’s a simple formula we used to work out the number of processes needed to eliminate a Poolboy bottleneck, and it’s one you’ll quickly realize that affects every area of your projects.

-----

Copyright © Mullen, LLC. 2025
