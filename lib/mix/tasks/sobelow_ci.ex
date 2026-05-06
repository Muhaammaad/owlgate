defmodule Mix.Tasks.SobelowCi do
  @moduledoc "Runs Sobelow with `.sobelow-conf`"
  use Mix.Task

  @shortdoc "Runs Sobelow with project configuration"

  @impl Mix.Task
  def run(args) when is_list(args) do
    Mix.Task.run("sobelow", ["--config", "--quiet"] ++ args)
  end
end
