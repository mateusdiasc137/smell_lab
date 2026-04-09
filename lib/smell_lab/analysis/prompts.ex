defmodule SmellLab.Analysis.Prompts do
  def smell_prompt(code_with_lines, smell_chunks) do
    """
    Você é um especialista em Elixir.

    Sua tarefa é decidir se o código abaixo contém UM code smell relevante.

    Regras:
    - use apenas os smells descritos no catálogo
    - se não houver smell claro, retorne has_smell=false
    - a localização deve apontar para as linhas mais relevantes
    - seja conservador com falso positivo

    CATÁLOGO DE SMELLS:
    #{Enum.map_join(smell_chunks, "\n\n---\n\n", & &1.text)}

    CÓDIGO:
    #{code_with_lines}
    """
  end

  def refactor_prompt(original_code, detection, refactoring_chunks) do
    """
    Você é um especialista em refatoração de Elixir.

    Smell detectado:
    - nome: #{detection["smell_name"] || detection[:smell_name]}
    - linhas: #{detection["start_line"] || detection[:start_line]}-#{detection["end_line"] || detection[:end_line]}
    - explicação: #{detection["explanation"] || detection[:explanation]}

    Regras:
    - preserve o comportamento
    - faça a menor mudança útil
    - produza código idiomático em Elixir
    - use apenas estratégias compatíveis com o catálogo

    CATÁLOGO DE REFATORAÇÕES:
    #{Enum.map_join(refactoring_chunks, "\n\n---\n\n", & &1.text)}

    CÓDIGO ORIGINAL:
    #{original_code}
    """
  end
end
