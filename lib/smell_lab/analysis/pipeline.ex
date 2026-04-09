defmodule SmellLab.Analysis.Pipeline do
  require Logger

  alias SmellLab.Agents.SmellDetector
  alias SmellLab.Agents.Refactorer

  def run(code) do
    t0 = System.monotonic_time(:millisecond)
    Logger.info("Pipeline started")

    with {:ok, detection} <- SmellDetector.run(code) do
      t1 = System.monotonic_time(:millisecond)
      Logger.info("SmellDetector finished in #{t1 - t0}ms")

      if truthy?(detection[:has_smell] || detection["has_smell"]) do
        Logger.info("Smell detected, starting Refactorer")

        with {:ok, refactoring} <- Refactorer.run(code, detection) do
          t2 = System.monotonic_time(:millisecond)
          Logger.info("Refactorer finished in #{t2 - t1}ms")
          Logger.info("Pipeline total #{t2 - t0}ms")

          {:ok, %{detection: detection, refactoring: refactoring}}
        else
          {:error, reason} = error ->
            Logger.error("Refactorer failed: #{inspect(reason, pretty: true)}")
            error
        end
      else
        t2 = System.monotonic_time(:millisecond)
        Logger.info("No smell detected")
        Logger.info("Pipeline total #{t2 - t0}ms")

        {:ok, %{detection: detection, refactoring: nil}}
      end
    else
      {:error, reason} = error ->
        Logger.error("SmellDetector failed: #{inspect(reason, pretty: true)}")
        error
    end
  end

  defp truthy?(value), do: value in [true, "true"]
end
