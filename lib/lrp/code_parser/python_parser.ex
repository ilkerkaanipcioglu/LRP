defmodule LRP.CodeParser.PythonParser do
  @moduledoc """
  Python kaynak dosyalarını (.py) hafif Regex kurallarıyla analiz eder.
  NIF veya tree-sitter bağımlılığı olmadan, hızlı ve idempotent analiz sunar.

  Çıktı formatı `LRP.CodeParser.ElixirParser` ile uyumludur.
  """

  @doc """
  Bir dizindeki tüm .py dosyalarını tarar ve ayrıştırır.
  Döner: {:ok, [module_info]} | {:error, reason}
  """
  def parse_directory(path) do
    if File.dir?(path) do
      files =
        Path.wildcard("#{path}/**/*.py")
        |> Enum.reject(&String.contains?(&1, "/venv/"))
        |> Enum.reject(&String.contains?(&1, "/.venv/"))
        |> Enum.reject(&String.contains?(&1, "/__pycache__/"))

      results =
        files
        |> Enum.flat_map(fn file ->
          case parse_file(file) do
            {:ok, classes} -> classes
            {:error, _}    -> []
          end
        end)

      {:ok, results}
    else
      {:error, "Dizin bulunamadı: #{path}"}
    end
  end

  @doc "Tek bir Python dosyasını ayrıştırır. Sınıf bazlı modül listesi döner."
  def parse_file(path) do
    case File.read(path) do
      {:ok, source} ->
        {:ok, parse_source(source, path)}
      {:error, reason} ->
        {:error, "#{path}: #{reason}"}
    end
  end

  @doc "Python kaynak kodu string'ini Regex ile ayrıştırır."
  def parse_source(source, path \\ "unknown") do
    lines = String.split(source, "\n")
    
    # Python'da dosyanın kendisi bir modüldür, ayrıca içindeki sınıflar da alt modüllerdir.
    # Kolaylık için her class'ı bir "Module" olarak tanımlıyoruz. 
    # Class yoksa dosyanın kendisini tek bir modül olarak alıyoruz.
    classes = extract_classes(lines, path)

    if classes == [] do
      # Class tanımlanmamışsa, tüm dosyayı tek bir modül gibi analiz et
      [
        %{
          name:         file_module_name(path),
          path:         path,
          functions:    extract_global_functions(lines),
          aliases:      extract_imports(lines),
          uses:         [],
          imports:      [],
          moduledoc:    extract_module_docstring(source),
          has_broadway: false,
          has_ecto:     false,
          has_genserver: false,
          line_count:   length(lines)
        }
      ]
    else
      classes
    end
  end

  # Sınıfları (class X) çıkarma
  defp extract_classes(lines, path) do
    # Regex for class definition: class ClassName(ParentClass): or class ClassName:
    class_regex = ~r/^\s*class\s+([a-zA-Z0-9_]+)(?:\(([^)]+)\))?\s*:/
    all_imports = extract_imports(lines)

    Enum.reduce(lines, {[], nil}, fn line, {acc, current_class} ->
      case Regex.run(class_regex, line) do
        [_, name | parent_info] ->
          parents = case parent_info do
            [p] when is_binary(p) -> String.split(p, ",") |> Enum.map(&String.trim/1)
            _ -> []
          end

          class_meta = %{
            name:         name,
            path:         path,
            functions:    [],
            aliases:      all_imports,
            uses:         parents, # Kalıtım alınan sınıflar 'use' gibi eşlenir
            imports:      [],
            moduledoc:    nil,
            has_broadway: false,
            has_ecto:     false,
            has_genserver: false,
            line_count:   length(lines)
          }

          {[class_meta | acc], name}

        nil ->
          if current_class do
            # Mevcut sınıfın fonksiyonlarını topla
            case Regex.run(~r/^\s+def\s+([a-zA-Z0-9_]+)\s*\(([^)]*)\)/, line) do
              [_, fn_name, args] ->
                arity = case String.trim(args) do
                  "" -> 0
                  other -> String.split(other, ",") |> length()
                end
                
                # En son eklenen sınıfın functions listesini güncelle
                [head | tail] = acc
                updated_head = Map.update!(head, :functions, &["#{fn_name}/#{arity}" | &1])
                {[updated_head | tail], current_class}

              nil ->
                {acc, current_class}
            end
          else
            {acc, nil}
          end
      end
    end)
    |> elem(0)
    |> Enum.map(fn class -> 
      Map.update!(class, :functions, &Enum.reverse/1)
    end)
    |> Enum.reverse()
  end

  # Global fonksiyonları çıkarma (sınıf dışı)
  defp extract_global_functions(lines) do
    Enum.reduce(lines, [], fn line, acc ->
      case Regex.run(~r/^def\s+([a-zA-Z0-9_]+)\s*\(([^)]*)\)/, line) do
        [_, fn_name, args] ->
          arity = case String.trim(args) do
            "" -> 0
            other -> String.split(other, ",") |> length()
          end
          ["#{fn_name}/#{arity}" | acc]
        nil ->
          acc
      end
    end)
    |> Enum.reverse()
  end

  # Import'ları (import X, from X import Y) çıkarma
  defp extract_imports(lines) do
    Enum.reduce(lines, [], fn line, acc ->
      cond do
        # from module import something
        String.match?(line, ~r/^\s*from\s+/) ->
          case Regex.run(~r/^\s*from\s+([a-zA-Z0-9_.]+)\s+import/, line) do
            [_, mod] -> [mod | acc]
            nil -> acc
          end

        # import module
        String.match?(line, ~r/^\s*import\s+/) ->
          case Regex.run(~r/^\s*import\s+([a-zA-Z0-9_.,\s]+)/, line) do
            [_, mods] -> 
              parsed = String.split(mods, ",") |> Enum.map(&String.trim/1)
              parsed ++ acc
            nil -> acc
          end

        true ->
          acc
      end
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  # Modül docstring'i çıkarma (ilk """ veya ''' bloğu)
  defp extract_module_docstring(source) do
    case Regex.run(~r/^[ \t]*(?:"""|''')([\s\S]*?)(?:"""|''')/, source) do
      [_, doc] -> String.slice(String.trim(doc), 0, 200)
      nil -> nil
    end
  end

  defp file_module_name(path) do
    path
    |> Path.basename(".py")
    |> Macro.camelize()
  end
end
