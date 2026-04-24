defmodule SmellLab.Retrieval.Index do
  use GenServer
  require Logger

  alias SmellLab.Llm.ReqLlmAdapter

  # API pública

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, Keyword.put_new(opts, :name, __MODULE__))
  end

  def search(index_name, query, k \\ 5) when is_atom(index_name) and is_binary(query) do
    GenServer.call(__MODULE__, {:search, index_name, query, k}, 60_000)
  end

  @spec get_smell(binary()) :: any()
  def get_smell(smell_id) when is_binary(smell_id) do
    GenServer.call(__MODULE__, {:get_smell, smell_id}, 30_000)
  end

  def reload do
    GenServer.call(__MODULE__, :reload, 60_000)
  end

  def status do
    GenServer.call(__MODULE__, :status)
  end

  # Callbacks

  @impl true
  def init(_opts) do
    case load_all_indexes() do
      {:ok, indexes} ->
        Logger.info(
          "Vector indexes loaded successfully. smells=#{length(indexes.smells)} refactorings=#{length(indexes.refactorings)}"
        )

        {:ok,
         %{
           smells: indexes.smells,
           refactorings: indexes.refactorings,
           ready?: true,
           last_error: nil
         }}

      {:error, reason} ->
        Logger.error("Failed to load vector indexes: #{inspect(reason, pretty: true)}")

        {:ok,
         %{
           smells: [],
           refactorings: [],
           ready?: false,
           last_error: reason
         }}
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, %{ready?: state.ready?, last_error: state.last_error}, state}
  end

  def handle_call(:reload, _from, state) do
    case load_all_indexes() do
      {:ok, indexes} ->
        new_state = %{
          state
          | smells: indexes.smells,
            refactorings: indexes.refactorings,
            ready?: true,
            last_error: nil
        }

        {:reply, :ok, new_state}

      {:error, reason} ->
        Logger.error("Failed to reload vector indexes: #{inspect(reason, pretty: true)}")
        {:reply, {:error, reason}, %{state | ready?: false, last_error: reason}}
    end
  end

  @impl true
  def handle_call({:search, _index_name, _query, _k}, _from, %{ready?: false} = state) do
    Logger.warning("Index.search/3 called before vector index was ready")
    {:reply, [], state}
  end

  def handle_call({:get_smell, _smell_id}, _from, %{ready?: false} = state) do
    {:reply, {:error, :index_not_ready}, state}
  end

  def handle_call({:get_smell, smell_id}, _from, state) do
    smell =
      state.smells
      |> Enum.filter(&(&1.smell_id == smell_id))
      #|> Enum.sort_by(fn doc -> if doc.kind == "example", do: 0, else: 1 end)
      |> List.first()

    Logger.info("[info] get_smell reachead, list size: #{length(state.smells)}")
    case smell do
      nil -> {:reply, {:error, {:smell_not_found, smell_id}}, state}
      doc -> {:reply, {:ok, doc}, state}
    end
  end

  def handle_call({:search, index_name, query, k}, _from, state) do
    docs = Map.get(state, index_name, [])

    cond do
      String.trim(query) == "" ->
        {:reply, [], state}

      docs == [] ->
        {:reply, [], state}

      true ->
        case ReqLlmAdapter.embed_query(query) do
          {:ok, query_embedding} ->
            results =
              docs
              |> Enum.map(fn doc ->
                score = cosine_similarity(query_embedding, doc.embedding)
                Map.put(doc, :score, score)
              end)
              |> Enum.sort_by(& &1.score, :desc)
              |> Enum.take(k)

            Logger.info("Vector search ranking for #{index_name}:")

            Enum.with_index(results, 1)
            |> Enum.each(fn {doc, idx} ->
              Logger.info(
                "##{idx} smell_id=#{doc.smell_id} kind=#{doc.kind} score=#{Float.round(doc.score, 6)} path=#{doc.path}"
              )
            end)

            {:reply, results, state}

          {:error, reason} ->
            Logger.error("Failed to embed query: #{inspect(reason, pretty: true)}")
            {:reply, [], state}
        end
    end
  end

  # Internals

  defp load_all_indexes do
    smell_index_path = System.get_env("SMELL_INDEX_PATH", "priv/indexes/smells_google.json")

    with {:ok, smells} <- load_json_index(smell_index_path) do
      {:ok, %{smells: smells, refactorings: []}}
    end
  end

  defp load_json_index(path) do
    if File.exists?(path) do
      path
      |> File.read!()
      |> Jason.decode!()
      |> parse_documents()
    else
      {:error, {:index_file_not_found, path}}
    end
  end

  defp parse_documents(%{"documents" => documents}) when is_list(documents) do
    {:ok,
     Enum.map(documents, fn doc ->
       %{
         id: doc["id"],
         smell_id: doc["smell_id"],
         title: doc["title"],
         kind: doc["kind"],
         category: doc["category"],
         refactoring_pipeline: doc["refactoring_pipeline"] || [],
         path: doc["path"],
         text: doc["text"],
         embedding: doc["embedding"]
       }
     end)}
  end

  defp parse_documents(other), do: {:error, {:invalid_index_format, other}}

  defp cosine_similarity(a, b) when is_list(a) and is_list(b) do
    dot =
      Enum.zip(a, b)
      |> Enum.reduce(0.0, fn {x, y}, acc -> acc + x * y end)

    norm_a =
      a
      |> Enum.reduce(0.0, fn x, acc -> acc + x * x end)
      |> :math.sqrt()

    norm_b =
      b
      |> Enum.reduce(0.0, fn x, acc -> acc + x * x end)
      |> :math.sqrt()

    case norm_a * norm_b do
      0.0 -> 0.0
      denom -> dot / denom
    end
  end
end
