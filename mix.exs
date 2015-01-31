defmodule Graphitex.Mixfile do
  use Mix.Project

  @description "Carbon wrapper for Elixir."

  def project do
    [
        app: :graphitex,
        version: "0.0.1",
        elixir: "~> 1.0",
        deps: deps,
        package: package,
        description: @description,
        source_url: "https://github.com/tappsi/graphitex"
    ]
  end

  def application do
    dev_apps = Mix.env == :dev && [:reprise] || []
    [applications: dev_apps ++ [:logger],
     mod: {Metrics, []}]
  end

  defp deps do
    [
        {:reprise, "~> 0.3.0", only: :dev}
    ]
  end

  defp package do
    [
        contributors: ["Ricardo Lanziano", "Óscar López", "Maicol Garces"],
        licenses: ["FreeBSD License"],
        links: %{"GitHub" => "https://github.com/tappsi/graphitex"}
    ]
  end
end
