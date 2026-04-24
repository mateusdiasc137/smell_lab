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

    query = String.trim(code)

    smell_chunks =
      Index.search(:smells, query, 5)
      |> Enum.map(&format_smell_doc_for_prompt/1)

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

  defp format_smell_doc_for_prompt(doc) do
    %{
      doc
      | text: """
      smell_id: #{doc.smell_id}
      title: #{doc.title || doc.smell_id}
      category: #{doc.category}
      kind: #{doc.kind}

      #{doc.text}
      """
    }
  end
end
