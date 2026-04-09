defmodule SmellLabWeb.EditorLive do
  use SmellLabWeb, :live_view

  alias SmellLab.Analysis.Pipeline

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       code: "",
       result: nil,
       error: nil,
       loading: false
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-3 gap-4 p-6">
      <div class="col-span-1">
        <h2 class="font-bold mb-2">Código Elixir</h2>

        <form phx-submit="analyze" phx-change="change">
          <textarea
            name="code"
            rows="28"
            class="w-full border rounded p-2 font-mono text-sm"
          ><%= @code %></textarea>

          <button
            type="submit"
            class="mt-3 px-4 py-2 rounded bg-zinc-900 text-white disabled:opacity-50"
            disabled={@loading}
          >
            <%= if @loading, do: "Analisando...", else: "Analisar" %>
          </button>
        </form>

        <%= if @error do %>
          <div class="mt-4 border rounded p-3 text-sm whitespace-pre-wrap text-red-700">
            <%= @error %>
          </div>
        <% end %>
      </div>

      <div class="col-span-1">
        <h2 class="font-bold mb-2">Detecção</h2>

        <%= if @result && @result.detection do %>
          <div class="border rounded p-3 text-sm space-y-2">
            <p><strong>Tem smell?</strong> <%= inspect(field(@result.detection, :has_smell)) %></p>
            <p><strong>Smell:</strong> <%= field(@result.detection, :smell_name) %></p>
            <p><strong>Confiança:</strong> <%= field(@result.detection, :confidence) %></p>
            <p><strong>Linhas:</strong> <%= field(@result.detection, :start_line) %> - <%= field(@result.detection, :end_line) %></p>
            <p><strong>Explicação:</strong></p>
            <pre class="whitespace-pre-wrap"><%= field(@result.detection, :explanation) %></pre>
          </div>
        <% else %>
          <div class="border rounded p-3 text-sm text-zinc-500">
            Nenhum resultado ainda.
          </div>
        <% end %>
      </div>

      <div class="col-span-1">
        <h2 class="font-bold mb-2">Sugestão de refatoração</h2>

        <%= if @result && @result.refactoring do %>
          <div class="border rounded p-3 text-sm space-y-3">
            <%= if summary = field(@result.refactoring, :summary) do %>
              <div>
                <p><strong>Resumo:</strong></p>
                <pre class="whitespace-pre-wrap"><%= summary %></pre>
              </div>
            <% end %>

            <%= if warnings = field(@result.refactoring, :warnings) do %>
              <div>
                <p><strong>Avisos:</strong></p>
                <pre class="whitespace-pre-wrap"><%= inspect(warnings, pretty: true) %></pre>
              </div>
            <% end %>

            <div>
              <p><strong>Código refatorado:</strong></p>
              <pre class="border rounded p-3 mt-2 whitespace-pre-wrap font-mono text-sm"><%= field(@result.refactoring, :refactored_code) %></pre>
            </div>

            <div>
              <p><strong>Debug do resultado bruto:</strong></p>
              <pre class="border rounded p-3 mt-2 whitespace-pre-wrap text-xs"><%= inspect(@result.refactoring, pretty: true) %></pre>
            </div>
          </div>
        <% else %>
          <div class="border rounded p-3 text-sm text-zinc-500">
            Nenhuma refatoração retornada.
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("change", %{"code" => code}, socket) do
    {:noreply, assign(socket, code: code)}
  end

  @impl true
  def handle_event("analyze", _params, socket) do
    code = socket.assigns.code

    {:noreply,
     socket
     |> assign(:loading, true)
     |> assign(:error, nil)
     |> start_async(:analysis, fn ->
       Pipeline.run(code)
     end)}
  end

  @impl true
  def handle_async(:analysis, {:ok, {:ok, result}}, socket) do
    {:noreply,
     socket
     |> assign(:loading, false)
     |> assign(:result, normalize_result(result))
     |> assign(:error, nil)}
  end

  def handle_async(:analysis, {:ok, {:error, reason}}, socket) do
    {:noreply,
     socket
     |> assign(:loading, false)
     |> assign(:result, nil)
     |> assign(:error, inspect(reason, pretty: true))}
  end

  def handle_async(:analysis, {:exit, reason}, socket) do
    {:noreply,
     socket
     |> assign(:loading, false)
     |> assign(:result, nil)
     |> assign(:error, "Falha na análise: #{inspect(reason, pretty: true)}")}
  end

  defp normalize_result(%{detection: detection, refactoring: refactoring}) do
    %{
      detection: normalize_map(detection),
      refactoring: normalize_map(refactoring)
    }
  end

  defp normalize_result(other), do: other

  defp normalize_map(nil), do: nil

  defp normalize_map(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {k, v}, acc ->
      key =
        cond do
          is_atom(k) -> k
          is_binary(k) -> String.to_atom(k)
          true -> k
        end

      Map.put(acc, key, v)
    end)
  end

  defp field(nil, _key), do: nil
  defp field(map, key) when is_map(map), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))
end
