defmodule SmellLab.Retrieval.CatalogLoader do
  def load_dir(dir) do
    dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".md"))
    |> Enum.sort()
    |> Enum.map(fn file ->
      path = Path.join(dir, file)
      text = File.read!(path) |> String.trim()

      %{
        id: Path.rootname(file),
        path: path,
        text: text,
        chunks: [text]
      }
    end)
  end
end
