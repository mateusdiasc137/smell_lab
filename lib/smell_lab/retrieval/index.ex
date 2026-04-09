defmodule SmellLab.Retrieval.Index do
  use GenServer
  require Logger

  alias SmellLab.Retrieval.CatalogLoader

  # API pública

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, Keyword.put_new(opts, :name, __MODULE__))
  end

  def search(index_name, query, k \\ 4) when is_atom(index_name) and is_binary(query) do
    GenServer.call(__MODULE__, {:search, index_name, query, k}, 30_000)
  end

  def reload do
    GenServer.call(__MODULE__, :reload, 60_000)
  end

  def status do
    GenServer.call(__MODULE__, :status)
  end

  # Callbacks do GenServer

  @impl true
  def init(_opts) do
    case load_all_indexes() do
      {:ok, indexes} ->
        Logger.info(
          "Índices carregados com sucesso. smells=#{length(indexes.smells)} refactorings=#{length(indexes.refactorings)}"
        )

        {:ok,
         %{
           smells: indexes.smells,
           refactorings: indexes.refactorings,
           ready?: true,
           last_error: nil
         }}

      {:error, reason} ->
        Logger.error("Falha ao carregar índices: #{inspect(reason, pretty: true)}")

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
        Logger.error("Falha ao recarregar índices: #{inspect(reason, pretty: true)}")
        {:reply, {:error, reason}, %{state | ready?: false, last_error: reason}}
    end
  end

  @impl true
  def handle_call({:search, _index_name, _query, _k}, _from, %{ready?: false} = state) do
    Logger.warning("Index.search/3 chamado antes de o índice estar pronto")
    {:reply, [], state}
  end

  def handle_call({:search, index_name, query, k}, _from, state) do
    items = Map.get(state, index_name, [])

    cond do
      String.trim(query) == "" ->
        {:reply, [], state}

      items == [] ->
        {:reply, [], state}

      true ->
        results =
          items
          |> Enum.map(fn item ->
            score = textual_score(item, query)
            Map.put(item, :score, score)
          end)
          |> Enum.filter(&(&1.score > 0))
          |> Enum.sort_by(& &1.score, :desc)
          |> Enum.take(k)

        {:reply, results, state}
    end
  end

  # Internals

  defp load_all_indexes do
    try do
      smells_docs = CatalogLoader.load_dir("priv/catalogs/smells")
      refactoring_docs = CatalogLoader.load_dir("priv/catalogs/refactorings")

      with {:ok, smells_index} <- build_index(smells_docs),
           {:ok, refactorings_index} <- build_index(refactoring_docs) do
        {:ok, %{smells: smells_index, refactorings: refactorings_index}}
      end
    rescue
      e ->
        {:error, e}
    end
  end

  defp build_index(docs) do
    indexed =
      Enum.map(docs, fn doc ->
        text = normalize_text(doc.text)

        %{
          id: doc.id,
          path: doc.path,
          text: doc.text,
          normalized_text: text,
          tokens: tokenize(text)
        }
      end)

    {:ok, indexed}
  end

  defp textual_score(item, query) do
    normalized_query = normalize_text(query)
    query_tokens = tokenize(normalized_query)

    token_score =
      query_tokens
      |> Enum.reduce(0, fn token, acc ->
        acc + count_token_matches(item.tokens, token)
      end)

    phrase_bonus =
      if String.contains?(item.normalized_text, normalized_query) do
        10
      else
        0
      end

    title_bonus =
      query_tokens
      |> Enum.reduce(0, fn token, acc ->
        if String.contains?(normalize_text(item.id), token), do: acc + 3, else: acc
      end)

    token_score + phrase_bonus + title_bonus
  end

  defp count_token_matches(tokens, token) do
    Enum.count(tokens, &(&1 == token))
  end

  defp normalize_text(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\p{L}\p{N}\s_]/u, " ")
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
  end

  defp tokenize(text) do
    text
    |> String.split(" ", trim: true)
    |> Enum.filter(&(String.length(&1) > 2))
  end
end
