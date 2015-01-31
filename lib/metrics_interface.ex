defmodule Metrics.Interface do
  use GenServer
  require Logger

  @moduledoc """
  GenServer which collects metrics, stores them in the server's state
  and periodically sends them to a Grafana server.
  """

  @app :metrics
  @module __MODULE__
  @epoch_seconds 719528 * 24 * 3600
  @tcp_connect_opts [:binary, {:packet, 0}]

  @default_carbon_host_port {"127.0.0.1", 2003}
  @default_prefix "metric."
  @default_interval 30_000

  defstruct host_port: nil, socket: nil, localhost: nil, prefix: nil, interval: nil, metrics: %{}

  #####
  # Public API

  @doc "Start the interface"
  def start_link() do
    GenServer.start_link(@module, [], name: @module)
  end

  @doc "Stop the interface"
  def stop() do
    GenServer.cast(@module, :stop)
  end

  @doc "Obtain the current counter value for the given metric"
  def get(metric) do
    GenServer.call(@module, {:get, metric})
  end

  @doc "Increment by one unit the specified metric counter, or set to 1 if non-existent"
  def increment(metric) do
    GenServer.cast(@module, {:increment, metric})
  end

  @doc "Send accumulated metrics to the server, and zero current metrics if successful"
  def send() do
    GenServer.cast(@module, :send)
  end

  #####
  # Behaviour

  @doc """
  Initialize the interface state and immediately timeout, which triggers a send
  """
  def init([]) do
    info("init")
    host_port = get_env(:carbon_host_port, @default_carbon_host_port)
    prefix = get_env(:prefix, @default_prefix)
    interval = get_env(:interval, @default_interval)
    {:ok, localhost} = :inet.gethostname
    state = %Metrics.Interface{host_port: host_port,
                               prefix: prefix,
                               interval: interval,
                               localhost: localhost}
    {:ok, state, 0} # timeout immediately
  end

  def handle_info(:timeout, %{interval: interval}=state) do
    # debug("handle_info timeout #{inspect state}"
    state = send(state)
    timeout_after(interval)
    {:noreply, state}
  end
  def handle_info({:tcp_closed, socket}, %{socket: socket}=state) do
    info("handle_info tcp_closed, unsetting socket #{inspect socket}")
    {:noreply, %{state | socket: nil}}
  end
  def handle_info({:tcp_error, socket}, %{socket: socket}=state) do
    info("handle_info tcp_error, unsetting socket #{inspect socket}")
    {:noreply, %{state | socket: nil}}
  end
  def handle_info(msg, state) do
    info("unhandled info #{inspect msg}")
    {:noreply, state}
  end

  @doc "Reply with the value of the specified metric"
  def handle_call({:get, metric}, _from, %{metrics: metrics}=state) do
    {:reply, metrics[metric], state}
  end

  def handle_cast({:increment, metric}, %{metrics: metrics}=state) do
    updated = increment(metrics, metric)
    {:noreply, %{state | metrics: updated}}
  end
  def handle_cast(:send, state) do
    state = send(state)
    {:noreply, state}
  end
  @doc "Handle the :stop message"
  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end

  @doc "Terminate the server"
  def terminate(reason, %{socket: socket}) do
    info("terminate reason: #{inspect reason}")
    case socket do
      nil -> :ok
      _ -> :gen_tcp.close(socket)
    end
  end

  @doc "Code change handler"
  def code_change(_from_version, state, _extra) do
    {:ok, state}
  end

  #####
  # Private Helper Functions

  defp timeout_after(interval) when interval > 0 do
    :erlang.send_after(interval, self, :timeout)
  end

  defp send(%{host_port: nil}=state) do
    state
  end
  defp send(%{socket: nil}=state) do
    case connect(state) do
      %{socket: nil}=state ->
        state
      state ->
        send()
        state
    end
  end
  defp send(%{socket: socket}=state) do
    data = format(state)
    case :gen_tcp.send(socket, data) do
      :ok ->
        %{state | metrics: %{}}
      {:error, reason} ->
        info("send error #{inspect reason} #{inspect data}")
        %{state | socket: nil}
    end
  end

  defp string_to_char_list(term) when is_binary(term) do
    String.to_char_list(term)
  end
  defp string_to_char_list(term) do
    term
  end

  defp connect(%{host_port: {host,port}}=state) do
    case :gen_tcp.connect(string_to_char_list(host), port, @tcp_connect_opts) do
      {:ok, socket} ->
        info("connect socket #{inspect socket}")
        %{state | socket: socket}
      {:error, reason} ->
        info("connect error #{inspect reason}")
        state
    end
  end

  def increment(metrics, metric) do
    if Dict.has_key?(metrics, metric) do
      Dict.update!(metrics, metric, &(&1+1))
    else
      Dict.put(metrics, metric, 1)
    end
  end

  defp format(%{localhost: localhost, metrics: metrics}) do
    format(localhost, metrics)
    # "test data\n"
  end

  def format(localhost, metrics) do
    ts = timestamp()
    for {metric, counter} <- metrics, do: "#{localhost}.#{metric} #{counter} #{ts}\n"
  end

  defp timestamp() do
    :calendar.datetime_to_gregorian_seconds(
      :calendar.now_to_universal_time(:erlang.now)) - @epoch_seconds
  end

  defp get_env(key, default) do
    Application.get_env(@app, key, default)    
  end

  # defp debug(msg) do
  #   Logger.debug("#{inspect @module}." <>  msg)
  # end

  defp info(msg) do
    Logger.info("#{inspect @module}." <>  msg)
  end

end
