defmodule SmellLab.Agents.Refactorer do
  require Logger

  alias SmellLab.Analysis.Prompts
  alias SmellLab.Analysis.Schemas
  alias SmellLab.Retrieval.Index
  alias SmellLab.Llm.ReqLlmAdapter

  def run(code, detection) when is_binary(code) and is_map(detection) do
    Logger.info("Refactorer.run started")

    smell_name = detection[:smell_name] || detection["smell_name"] || "unknown"

    query = """
    Refactor Elixir code for smell #{smell_name}:
    #{code}
    """

    refactoring_chunks = Index.search(:refactorings, query, 3)
    Logger.info("Refactorer retrieved #{length(refactoring_chunks)} refactoring chunks")

    prompt = Prompts.refactor_prompt(code, detection, refactoring_chunks)
    Logger.info("Refactorer prompt size: #{String.length(prompt)} chars")

    case ReqLlmAdapter.generate_object(prompt, Schemas.refactor_schema()) do
      {:ok, _result} = ok ->
        Logger.info("Refactorer LLM call finished successfully")
        ok

      {:error, reason} = error ->
        Logger.error("Refactorer LLM call failed: #{inspect(reason, pretty: true)}")
        error
    end
  end
end
