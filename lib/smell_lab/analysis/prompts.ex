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

  def refactor_prompt(original_code, detection, refactoring_chunks) do
    """
    You are an expert in refactoring in Elixir.

    Smell detected:
    - name: #{detection["smell_name"] || detection[:smell_name]}
    - lines: #{detection["start_line"] || detection[:start_line]}-#{detection["end_line"] || detection[:end_line]}
    - Explanation: #{detection["explanation"] || detection[:explanation]}

    Rules:
    - Preserve behavior.
    - Make the least useful change.
    - Produce idiomatic code in Elixir.
    - Use only strategies compatible with the catalog.

    REFACTORING CATALOG:
    #{Enum.map_join(refactoring_chunks, "\n\n---\n\n", & &1.text)}

    ORIGINAL CODE:
    #{original_code}
    """
  end
end
