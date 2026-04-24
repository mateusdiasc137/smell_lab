defmodule SmellLab.Llm.ReqLlmAdapter do
  @behaviour SmellLab.Llm.Behaviour
  require Logger

  @default_timeout 200_000

  # Troque aqui para :google ou :ollama
  @provider :google

  defp get_model(provider) do
    case provider do
      :google ->
        System.get_env("LLM_MODEL", "google:gemini-3.1-flash-lite-preview")

      :ollama ->
        ReqLLM.model!(%{
          id: System.get_env("LLM_MODEL", "gemma3"),
          provider: :openai,
          base_url: System.get_env("OLLAMA_BASE_URL", "http://localhost:11434/v1")
        })
    end
  end

  @impl true
  def generate_object(prompt, schema, opts \\ []) do
    Logger.info("ReqLlmAdapter.generate_object start")

    model = get_model(@provider)

    merged_opts =
      Keyword.merge(
        default_opts(@provider),
        opts
      )

    case @provider do
      :google ->
        generate_object_google(model, prompt, schema, merged_opts)

      :ollama ->
        generate_object_ollama(model, prompt, schema, merged_opts)
    end
  end

  @impl true
  def embed_query(text) when is_binary(text) do
    Logger.info("ReqLlmAdapter.embed_query start")

    embed_model = System.get_env("EMBED_MODEL", "google:gemini-embedding-001")

    case ReqLLM.Embedding.embed(
           embed_model,
           [text],
           provider_options: [task_type: "RETRIEVAL_QUERY"],
           req_http_options: [receive_timeout: 120_000]
         ) do
      {:ok, [vector]} when is_list(vector) ->
        Logger.info("ReqLlmAdapter.embed_query success")
        {:ok, vector}

      {:ok, other} ->
        Logger.error("ReqLlmAdapter.embed_query unexpected response: #{inspect(other, pretty: true)}")
        {:error, {:unexpected_embedding_response, other}}

      {:error, reason} = error ->
        Logger.error("ReqLlmAdapter.embed_query error: #{inspect(reason, pretty: true)}")
        error
    end
  end

  defp default_opts(:google) do
    [
      receive_timeout: @default_timeout,
      max_retries: 0,
      max_tokens: 4096
    ]
  end

  defp default_opts(:ollama) do
    [
      receive_timeout: @default_timeout,
      max_retries: 0,
      temperature: 0.0,
      api_key: System.get_env("OPENAI_API_KEY", "ollama")
    ]
  end

  defp generate_object_google(model, prompt, schema, opts) do
    result = ReqLLM.generate_object(model, prompt, schema, opts)

    case result do
      {:ok, response} ->
        Logger.info("ReqLlmAdapter.generate_object success")

        case ReqLLM.Response.unwrap_object(response) do
          {:ok, object} when is_map(object) ->
            {:ok, object}

          {:ok, other} ->
            Logger.error("""
            ReqLlmAdapter.generate_object returned non-map object:
            #{inspect(other, pretty: true)}

            finish_reason:
            #{inspect(ReqLLM.Response.finish_reason(response))}

            text:
            #{ReqLLM.Response.text(response)}
            """)

            {:error, {:unexpected_object_shape, other}}

          {:error, reason} ->
            Logger.error("""
            ReqLlmAdapter.generate_object could not unwrap object:
            #{inspect(reason, pretty: true)}

            finish_reason:
            #{inspect(ReqLLM.Response.finish_reason(response))}

            text:
            #{ReqLLM.Response.text(response)}
            """)

            {:error, {:object_unwrap_failed, reason}}
        end

      {:error, reason} = error ->
        Logger.error("ReqLlmAdapter.generate_object error: #{inspect(reason, pretty: true)}")
        error
    end
  end

  def generate_text(prompt, opts \\ []) do
    Logger.info("ReqLlmAdapter.generate_text start")

    model = get_model(@provider)

    merged_opts =
      Keyword.merge(
        default_opts(@provider),
        opts
      )

    result = ReqLLM.generate_text(model, prompt, merged_opts)

    case result do
      {:ok, response} ->
        Logger.info("ReqLlmAdapter.generate_text success")
        {:ok, ReqLLM.Response.text(response)}

      {:error, reason} = error ->
        Logger.error("ReqLlmAdapter.generate_text error: #{inspect(reason, pretty: true)}")
        error
    end
  end

  defp generate_object_ollama(model, prompt, schema, opts) do
    json_prompt = build_json_prompt(prompt, schema)

    result = ReqLLM.generate_text(model, json_prompt, opts)

    case result do
      {:ok, response} ->
        Logger.info("ReqLlmAdapter.generate_text success")

        text = ReqLLM.Response.text(response)

        with {:ok, json_text} <- extract_json(text),
             {:ok, object} <- Jason.decode(json_text) do
          {:ok, object}
        else
          {:error, reason} = error ->
            Logger.error("""
            ReqLlmAdapter JSON parse error: #{inspect(reason, pretty: true)}
            Raw response:
            #{text}
            """)

            error
        end

      {:error, reason} = error ->
        Logger.error("ReqLlmAdapter.generate_text error: #{inspect(reason, pretty: true)}")
        error
    end
  end

  defp build_json_prompt(prompt, schema) do
    """
    #{prompt}

    IMPORTANTE:
    Responda APENAS com um objeto JSON válido.
    Não use markdown.
    Não use ```json.
    Não escreva explicações fora do JSON.

    Estrutura esperada:
    #{schema_description(schema)}

    Regras:
    - use exatamente as chaves pedidas
    - use valores compatíveis com os tipos pedidos
    - se não souber um campo textual, use ""
    - se não souber uma lista, use []
    - se não houver smell, ainda assim devolva o JSON completo
    """
  end

  defp schema_description(schema) when is_list(schema) do
    schema
    |> Enum.map_join("\n", fn {key, rules} ->
      type = rules |> Keyword.get(:type, :string) |> inspect()
      required = Keyword.get(rules, :required, false)

      "- #{key}: #{type}#{if required, do: " (required)", else: ""}"
    end)
  end

  defp extract_json(text) when is_binary(text) do
    trimmed = String.trim(text)

    cond do
      String.starts_with?(trimmed, "{") and String.ends_with?(trimmed, "}") ->
        {:ok, trimmed}

      true ->
        case Regex.run(~r/```json\s*(\{.*\})\s*```/s, trimmed, capture: :all_but_first) do
          [json] ->
            {:ok, json}

          _ ->
            case Regex.run(~r/(\{.*\})/s, trimmed, capture: :all_but_first) do
              [json] -> {:ok, json}
              _ -> {:error, :json_not_found}
            end
        end
    end
  end
end
