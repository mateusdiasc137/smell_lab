defmodule SmellLab.Refactorings.Catalog do
  @moduledoc false

  require Logger

  @refactorings_path "priv/catalogs/refactorings.json"
  @refactoring_for_smells_path "priv/catalogs/refactoring_for_smells.json"

  def resolved_treatments_for_smell(smell_id) when is_binary(smell_id) do
    with {:ok, smell_map} <- load_refactoring_pipeline(),
         {:ok, refactorings_catalog} <- load_refactorings_catalog(),
         {:ok, smell_entry} <- find_smell_entry(smell_map, smell_id),
         {:ok, resolved} <- resolve_treatments(smell_entry, refactorings_catalog) do
      {:ok, resolved}
    end
  end

  def prompt_text_for_smell(smell_id) when is_binary(smell_id) do
    with {:ok, treatments} <- resolved_treatments_for_smell(smell_id) do
      {:ok, format_treatments_for_prompt(treatments)}
    end
  end

  defp load_refactoring_pipeline do
    if File.exists?(@refactoring_for_smells_path) do
      @refactoring_for_smells_path
      |> File.read!()
      |> Jason.decode!()
      |> normalize_refactoring_pipeline_catalog()
    else
      {:error, {:refactorings_for_smells_not_found, @refactoring_for_smells_path}}
    end
  end

  defp normalize_refactoring_pipeline_catalog(%{"smells" => list}) when is_list(list) do
    {:ok, Map.new(list, fn item -> {item["smell_id"], item} end)}
  end

  defp normalize_refactoring_pipeline_catalog(other) do
    {:error, {:invalid_refactorings_for_smells_catalog, other}}
  end

  defp load_refactorings_catalog do
    if File.exists?(@refactorings_path) do
      @refactorings_path
      |> File.read!()
      |> Jason.decode!()
      |> normalize_refactorings_catalog()
    else
      {:error, {:refactorings_catalog_not_found, @refactorings_path}}
    end
  end

  defp normalize_refactorings_catalog(%{"refactorings" => list}) when is_list(list) do
    {:ok, Map.new(list, fn item -> {item["id"], item} end)}
  end

  defp normalize_refactorings_catalog(map) when is_map(map) do
    if Map.has_key?(map, "refactorings") do
      {:error, :invalid_refactorings_catalog}
    else
      {:ok, map}
    end
  end

  defp find_smell_entry(smell_map, smell_id) do
    case Map.get(smell_map, smell_id) do
      nil -> {:error, {:smell_not_found_in_refactoring_map, smell_id}}
      smell_entry -> {:ok, smell_entry}
    end
  end

  defp resolve_treatments(smell_entry, refactorings_catalog) do
    smell_id = smell_entry["smell_id"]
    treatments = smell_entry["treatments"] || []

    resolved =
      Enum.map(treatments, fn treatment ->
        resolve_treatment(smell_id, treatment, refactorings_catalog)
      end)

    case Enum.find(resolved, &match?({:error, _}, &1)) do
      nil ->
        {:ok, Enum.map(resolved, fn {:ok, treatment} -> treatment end)}

      {:error, reason} = error ->
        Logger.error("Refactoring treatment resolution error: #{inspect(reason, pretty: true)}")
        error
    end
  end

  defp resolve_treatment(smell_id, treatment, refactorings_catalog) do
    steps = treatment["steps"] || []

    resolved_steps =
      Enum.map(steps, fn step_id ->
        case Map.get(refactorings_catalog, step_id) do
          nil ->
            {:error, {:refactoring_not_found, smell_id, step_id}}

          refactoring ->
            {:ok, format_refactoring(refactoring)}
        end
      end)

    case Enum.find(resolved_steps, &match?({:error, _}, &1)) do
      nil ->
        {:ok,
         %{
           smell_id: smell_id,
           treatment_id: treatment["id"],
           label: treatment["label"] || treatment["id"] || "treatment",
           type: treatment["type"] || infer_treatment_type(steps),
           steps: Enum.map(resolved_steps, fn {:ok, step} -> step end)
         }}

      {:error, reason} = error ->
        error
    end
  end

  defp infer_treatment_type([_single]), do: "single"
  defp infer_treatment_type(_), do: "pipeline"

  defp format_refactoring(ref) do
    id = ref["id"] || ref[:id]
    summary = ref["summary"] || ref[:summary] || ""
    intent = ref["intent"] || ref[:intent] || ""
    steps = ref["steps"] || ref[:steps] || []
    example_before = ref["example_before"] || ref[:example_before] || ""
    example_after = ref["example_after"] || ref[:example_after] || ""
    raw_text = ref["text"] || ref[:text]

    text =
      cond do
        is_binary(raw_text) and raw_text != "" ->
          raw_text

        true ->
          """
          id: #{id}

          summary:
          #{summary}

          intent:
          #{intent}

          steps:
          #{Enum.map_join(steps, "\n", fn step -> "- #{step}" end)}

          example_before:
          #{example_before}

          example_after:
          #{example_after}
          """
          |> String.trim()
      end

    %{
      id: id,
      text: text
    }
  end

  defp format_treatments_for_prompt(treatments) do
    treatments
    |> Enum.with_index(1)
    |> Enum.map_join("\n\n", fn {treatment, idx} ->
      """
      TREATMENT #{idx}
      label: #{treatment.label}
      type: #{treatment.type}

      #{format_steps_for_prompt(treatment.steps)}
      """
      |> String.trim()
    end)
  end

  defp format_steps_for_prompt(steps) do
    steps
    |> Enum.with_index(1)
    |> Enum.map_join("\n\n", fn {step, idx} ->
      """
      Step #{idx}
      refactoring_id: #{step.id}

      #{step.text}
      """
      |> String.trim()
    end)
  end
end
