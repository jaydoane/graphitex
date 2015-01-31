defmodule Metrics do
  use Application

  @moduledoc """
  Start the Metrics.Supervisor for the Metrics.Interface, which periodically sends
  accumulated application metrics to the remote Graphite server
  """

  def start(_type, _args) do
    import Supervisor.Spec
    children = [worker(Metrics.Interface, [], restart: :permanent)]
    opts = [strategy: :one_for_one, name: Metrics.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
