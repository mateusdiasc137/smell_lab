defmodule SmellLab.Analysis.Prompts do
  def smell_prompt(code_with_lines, smell_chunks) do
    """
    You are an Elixir expert.

    Your task is to decide if the following code contains code smells.

    Rules:
    - use only the smells described in catalog.
    - if you not sure if there is a smell, return has_smell=false.
    - the location must point to the most relevant lines.
    - be conservative with false positives

    SMELLS CATALOG:
    #{Enum.map_join(smell_chunks, "\n\n---\n\n", & &1.text)}

    CODE:
    #{code_with_lines}
    """
  end

  def refactor_prompt(original_code, detection, treatments_text) do
  """
  You are an expert in refactoring Elixir code.

  A code smell was detected:
  - id: #{detection["smell_id"] || detection[:smell_id] || ""}
  - name: #{detection["smell_name"] || detection[:smell_name]}
  - lines: #{detection["start_line"] || detection[:start_line]}-#{detection["end_line"] || detection[:end_line]}

  Your task:
  - choose the most appropriate treatment from the catalog
  - apply it to the code
  - preserve behavior
  - make the smallest useful change
  - produce idiomatic Elixir

  Rules:
  - Return ONLY the final refactored Elixir code.
  - Do NOT return JSON.
  - Do NOT return markdown.
  - Do NOT explain your reasoning.
  - Do NOT include comments before or after the code.
  - If no safe refactoring is possible, return the original code unchanged.

  Treatment catalog:
  #{treatments_text}

  Original code:
  #{original_code}
  """
end
end
