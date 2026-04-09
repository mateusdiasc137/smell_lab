defmodule SmellLab.Llm.ReqLlmAdapter do
  @behaviour SmellLab.LLM.Behaviour
  require Logger

  @model System.get_env("LLM_MODEL", "google:gemini-2.5-flash")
  @embedding_model System.get_env("EMBED_MODEL", "google:gemini-embedding-001")

  @default_timeout 20_000

  @impl true
  def generate_object(prompt, schema, opts \\ []) do
    Logger.info("ReqLlmAdapter.generate_object start")

    merged_opts =
      Keyword.merge(
        [
          receive_timeout: @default_timeout,
          max_retries: 0
        ],
        opts
      )

    result = ReqLLM.generate_object(@model, prompt, schema, merged_opts)

    case result do
      {:ok, response} ->
        Logger.info("ReqLlmAdapter.generate_object success")
        {:ok, ReqLLM.Response.object(response)}

      {:error, reason} = error ->
        Logger.error("ReqLlmAdapter.generate_object error: #{inspect(reason, pretty: true)}")
        error

      other ->
        Logger.error("ReqLlmAdapter.generate_object unexpected response: #{inspect(other, pretty: true)}")
        {:error, {:unexpected_response, other}}
    end
  end

  @impl true
  def embed(texts, opts \\ []) do
    Logger.info("ReqLlmAdapter.embed start with #{length(texts)} texts")

    merged_opts =
      Keyword.merge(
        [
          receive_timeout: @default_timeout,
          max_retries: 0
        ],
        opts
      )

    result = ReqLLM.Embedding.embed(@embedding_model, texts, merged_opts)

    case result do
      {:ok, embeddings} = ok ->
        Logger.info("ReqLlmAdapter.embed success")
        ok

      {:error, reason} = error ->
        Logger.error("ReqLlmAdapter.embed error: #{inspect(reason, pretty: true)}")
        error

      other ->
        Logger.error("ReqLlmAdapter.embed unexpected response: #{inspect(other, pretty: true)}")
        {:error, {:unexpected_response, other}}
    end
  end
end
