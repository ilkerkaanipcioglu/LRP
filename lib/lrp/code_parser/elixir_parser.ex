defmodule LRP.CodeParser.ElixirParser do
  @moduledoc """
  Elixir kaynak dosyalarını Elixir'in yerleşik `Code.string_to_quoted/2` AST
  ayrıştırıcısıyla çözümler — sıfır ek bağımlılık.

  Çıktı: her modül için yapılandırılmış metadata map'i.
  Bu, `LRP.Analyzer` tarafından OBJECT/RELATIONSHIP'e dönüştürülür.
  """

  @doc """
  Bir dizindeki tüm .ex ve .exs dosyalarını tarar ve ayrıştırır.
  Döner: {:ok, [module_info]} | {:error, reason}
  """
  def parse_directory(path) do
    if File.dir?(path) do
      files =
        Path.wildcard("#{path}/**/*.{ex,exs}")
        |> Enum.reject(&String.contains?(&1, "/_build/"))
        |> Enum.reject(&String.contains?(&1, "/deps/"))

      results =
        files
        |> Enum.flat_map(fn file ->
          case parse_file(file) do
            {:ok, modules} -> modules
            {:error, _}    -> []
          end
        end)

      {:ok, results}
    else
      {:error, "Dizin bulunamadı: #{path}"}
    end
  end

  @doc "Tek bir dosyayı ayrıştırır. [{module_info}] listesi döner."
  def parse_file(path) do
    case File.read(path) do
      {:ok, source} -> parse_source(source, path)
      {:error, reason} -> {:error, "#{path}: #{reason}"}
    end
  end

  @doc "Kaynak kodu string'i ayrıştırır."
  def parse_source(source, path \\ "unknown") do
    case Code.string_to_quoted(source, file: path) do
      {:ok, ast} ->
        modules = extract_modules(ast, path)
        {:ok, modules}

      {:error, {_meta, message, token}} ->
        {:error, "Syntax error in #{path}: #{message}#{token}"}
    end
  end

  # ─── AST Traversal ──────────────────────────────────────────────────────────

  defp extract_modules(ast, path) do
    {_, acc} = Macro.prewalk(ast, [], fn node, acc ->
      case node do
        {:defmodule, _meta, [{:__aliases__, _, parts} | body_list]} ->
          mod_name = parts |> Enum.map(&to_string/1) |> Enum.join(".")
          info = extract_module_info(mod_name, body_list, path)
          {node, [info | acc]}

        _ ->
          {node, acc}
      end
    end)

    Enum.reverse(acc)
  end

  defp extract_module_info(name, body_list, path) do
    body = List.flatten(body_list)

    %{
      name:         name,
      path:         path,
      functions:    extract_function_names(body),
      aliases:      extract_aliases(body),
      uses:         extract_uses(body),
      imports:      extract_imports(body),
      moduledoc:    extract_moduledoc(body),
      has_broadway: has_pattern?(body, :broadway),
      has_ecto:     has_pattern?(body, :ecto),
      has_genserver: has_pattern?(body, :genserver),
      line_count:   count_lines(path)
    }
  end

  # Fonksiyon adları ve ariteleri
  defp extract_function_names(body) do
    {_, fns} = Macro.prewalk(body, [], fn node, acc ->
      case node do
        {def_type, _, [{name, _, args} | _]}
        when def_type in [:def, :defp] and is_atom(name) ->
          arity = if is_list(args), do: length(args), else: 0
          {node, ["#{name}/#{arity}" | acc]}
        _ ->
          {node, acc}
      end
    end)
    fns |> Enum.uniq() |> Enum.sort()
  end

  # alias X.Y → "X.Y"
  defp extract_aliases(body) do
    {_, aliases} = Macro.prewalk(body, [], fn node, acc ->
      case node do
        {:alias, _, [{:__aliases__, _, parts} | _]} ->
          name = parts |> Enum.map(&to_string/1) |> Enum.join(".")
          {node, [name | acc]}
        {:alias, _, [{{:., _, [{:__aliases__, _, parts}, _]}, _, _} | _]} ->
          name = parts |> Enum.map(&to_string/1) |> Enum.join(".")
          {node, [name | acc]}
        _ ->
          {node, acc}
      end
    end)
    aliases |> Enum.uniq() |> Enum.sort()
  end

  # use X.Y → "X.Y"
  defp extract_uses(body) do
    {_, uses} = Macro.prewalk(body, [], fn node, acc ->
      case node do
        {:use, _, [{:__aliases__, _, parts} | _]} ->
          name = parts |> Enum.map(&to_string/1) |> Enum.join(".")
          {node, [name | acc]}
        _ ->
          {node, acc}
      end
    end)
    uses |> Enum.uniq() |> Enum.sort()
  end

  # import X.Y
  defp extract_imports(body) do
    {_, imports} = Macro.prewalk(body, [], fn node, acc ->
      case node do
        {:import, _, [{:__aliases__, _, parts} | _]} ->
          name = parts |> Enum.map(&to_string/1) |> Enum.join(".")
          {node, [name | acc]}
        _ ->
          {node, acc}
      end
    end)
    imports |> Enum.uniq() |> Enum.sort()
  end

  # @moduledoc string
  defp extract_moduledoc(body) do
    {_, doc} = Macro.prewalk(body, nil, fn node, acc ->
      case node do
        {:@, _, [{:moduledoc, _, [text]}]} when is_binary(text) ->
          {node, String.slice(text, 0, 200)}
        _ ->
          {node, acc}
      end
    end)
    doc
  end

  # Belli pattern'ların varlığını kontrol et
  defp has_pattern?(body, :broadway) do
    source = Macro.to_string(body)
    String.contains?(source, "Broadway") or String.contains?(source, "Broadway.Message")
  end
  defp has_pattern?(body, :ecto) do
    source = Macro.to_string(body)
    String.contains?(source, "Ecto") or String.contains?(source, "Repo.")
  end
  defp has_pattern?(body, :genserver) do
    source = Macro.to_string(body)
    String.contains?(source, "GenServer") or String.contains?(source, "handle_call")
  end

  defp count_lines(path) do
    case File.read(path) do
      {:ok, content} -> content |> String.split("\n") |> length()
      _ -> 0
    end
  end
end
