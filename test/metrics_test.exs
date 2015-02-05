defmodule Metrics.Test do
  use ExUnit.Case, async: true

  test "metrics interface can start without connecting to server" do
    nil = Metrics.Interface.get :foo
    :ok = Metrics.Interface.increment :foo
    1 = Metrics.Interface.get :foo
    
    :ok = Application.start :tcp_listener
    :timer.sleep 100
    1 = length TcpListener.received
    Application.stop :tcp_listener
  end

end
