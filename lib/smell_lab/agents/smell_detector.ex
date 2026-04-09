defmodule SmellLab.Agents.SmellDetector do
  require Logger

  alias SmellLab.Analysis.LineNumbers
  alias SmellLab.Analysis.Prompts
  alias SmellLab.Analysis.Schemas
  alias SmellLab.Retrieval.Index
  alias SmellLab.Llm.ReqLlmAdapter

  def run(code) when is_binary(code) do
    Logger.info("SmellDetector.run started")

    annotated = LineNumbers.annotate(code)

    query = """
    Elixir code smell analysis:
    #{code}
    """

    smell_chunks = Index.search(:smells, query, 3)
    Logger.info("SmellDetector retrieved #{length(smell_chunks)} smell chunks")

    prompt = Prompts.smell_prompt(annotated, smell_chunks)
    Logger.info("SmellDetector prompt size: #{String.length(prompt)} chars")

    case ReqLlmAdapter.generate_object(prompt, Schemas.smell_detection_schema()) do
      {:ok, _result} = ok ->
        Logger.info("SmellDetector LLM call finished successfully")
        ok

      {:error, reason} = error ->
        Logger.error("SmellDetector LLM call failed: #{inspect(reason, pretty: true)}")
        error
    end
  end
end
