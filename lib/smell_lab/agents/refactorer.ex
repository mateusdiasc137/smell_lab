defmodule SmellLab.Agents.Refactorer do
  require Logger

  alias SmellLab.Analysis.Prompts
  alias SmellLab.Analysis.Schemas
  alias SmellLab.Llm.ReqLlmAdapter
  alias SmellLab.Refactorings.Catalog

  def run(code, detection) when is_binary(code) and is_map(detection) do
    Logger.info("Refactorer.run started")

    smell_id = detection[:smell_id] || detection["smell_id"] || ""

    if String.trim(smell_id) == "" do
      {:error, :missing_smell_id}
    else
      with  {:ok, treatments_text} <- Catalog.prompt_text_for_smell(smell_id) do
        Logger.info( "Refactorer resolved smell_id=#{smell_id}")

        prompt = Prompts.refactor_prompt(code, detection, treatments_text)
        Logger.info("Refactorer prompt size: #{String.length(prompt)} chars")

        case ReqLlmAdapter.generate_text(prompt) do
          {:ok, refactored_code} ->
            {:ok,
            %{
              summary: "Refatoração sugerida com base no tratamento selecionado.",
              refactored_code: clean_code_output(refactored_code),
              changed_regions: [],
              warnings: []
            }}

          {:error, reason} = error ->
            error
        end
      else
        {:error, reason} = error ->
          Logger.error("Refactorer failed before LLM call: #{inspect(reason, pretty: true)}")
          error
      end
    end
  end

  defp clean_code_output(text) do
    text
    |> String.trim()
    |> String.replace(~r/\A```elixir\s*/s, "")
    |> String.replace(~r/\A```\s*/s, "")
    |> String.replace(~r/\s*```\z/s, "")
    |> String.trim()
  end

end
