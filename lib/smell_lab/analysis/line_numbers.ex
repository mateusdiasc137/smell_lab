defmodule SmellLab.Analysis.LineNumbers do
  def annotate(code) do
    code
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.map_join("\n", fn {line, n} ->
      padded = n |> Integer.to_string() |> String.pad_leading(4)
      "#{padded} | #{line}"
    end)
  end
end
