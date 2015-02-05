use Mix.Config

port = 20037

config :logger, :console,
  level: :warn

config :tcp_listener,
  port: port

config :metrics,
  carbon_host_port: {"localhost", port},
  interval: 10,
  prefix: "test.metrics."
