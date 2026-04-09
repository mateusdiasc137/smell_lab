defmodule SmellLab.Llm.Behaviour do
  @callback generate_object(prompt :: String.t(), schema :: keyword(), opts :: keyword()) ::
    {:ok, map()} | {:error, term()}

  @callback embed(texts :: [String.t()], opts :: keyword()) ::
    {:ok, list(list(number()))} | {:error, term()}
end
