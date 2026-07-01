defmodule LRP.CliHelpers do
  @moduledoc """
  Tüm LRP Mix task'lerinin kullandığı ortak terminal yardımcıları.
  Banner, tablo, JSON çıktı, ANSI renk ve uygulama başlatma.
  """

  # ─── ANSI Renk ──────────────────────────────────────────────────────────────

  @colors %{
    green:   "\e[32m",
    red:     "\e[31m",
    yellow:  "\e[33m",
    cyan:    "\e[36m",
    bold:    "\e[1m",
    dim:     "\e[2m",
    reset:   "\e[0m"
  }

  def color(text, c), do: "#{@colors[c]}#{text}#{@colors[:reset]}"
  def green(t),   do: color(t, :green)
  def red(t),     do: color(t, :red)
  def yellow(t),  do: color(t, :yellow)
  def cyan(t),    do: color(t, :cyan)
  def bold(t),    do: color(t, :bold)
  def dim(t),     do: color(t, :dim)

  # ─── Banner ─────────────────────────────────────────────────────────────────

  def banner(title) do
    width  = max(String.length(title) + 4, 44)
    line   = String.duplicate("═", width - 2)
    pad    = div(width - 2 - String.length(title), 2)
    spaces = String.duplicate(" ", pad)

    IO.puts(cyan("╔#{line}╗"))
    IO.puts(cyan("║#{spaces}#{bold(title)}#{spaces}#{if rem(String.length(title), 2) == 1, do: " ", else: ""}║"))
    IO.puts(cyan("╚#{line}╝"))
    IO.puts("")
  end

  # ─── Tablo ──────────────────────────────────────────────────────────────────

  @doc """
  Sütun başlıkları ve satır listesiyle güzel bir tablo basar.

  ## Örnek
      table(["ID", "Ad", "Durum"], [
        ["abc-123", "Harezm", "active"],
        ["def-456", "Demo",   "active"]
      ])
  """
  def table(headers, rows) do
    all_rows  = [headers | rows]
    col_count = length(headers)

    widths =
      Enum.map(0..(col_count - 1), fn i ->
        all_rows
        |> Enum.map(fn row -> row |> Enum.at(i, "") |> to_string() |> String.length() end)
        |> Enum.max()
      end)

    separator = "─" <> Enum.map_join(widths, "─┼─", fn w -> String.duplicate("─", w) end) <> "─"

    print_row = fn row, color_fn ->
      cells =
        row
        |> Enum.with_index()
        |> Enum.map_join(" │ ", fn {cell, i} ->
          str = to_string(cell)
          str <> String.duplicate(" ", Enum.at(widths, i) - String.length(str))
        end)

      IO.puts(color_fn.(" #{cells} "))
    end

    IO.puts(dim("┌─#{separator}─┐"))
    print_row.(headers, &bold/1)
    IO.puts(dim("├─#{separator}─┤"))
    Enum.each(rows, &print_row.(&1, fn x -> x end))
    IO.puts(dim("└─#{separator}─┘"))
    IO.puts("")
  end

  # ─── JSON Çıktı ─────────────────────────────────────────────────────────────

  @doc "Veriyi MCP/agent uyumlu JSON olarak basar."
  def json_output(data) do
    IO.puts(Jason.encode!(data, pretty: false))
  end

  # ─── Uygulama Başlatma ──────────────────────────────────────────────────────

  @doc "DB bağlantısı için OTP uygulamasını başlatır. Hata varsa açıklayıcı mesajla çıkar."
  def start_app do
    Mix.Task.run("app.start")
  rescue
    e ->
      IO.puts(red("❌ Uygulama başlatılamadı: #{Exception.message(e)}"))
      IO.puts(yellow("   → mix ecto.create ve mix ecto.migrate çalıştırıldı mı?"))
      System.halt(1)
  end

  # ─── Yardımcı ───────────────────────────────────────────────────────────────

  def truncate(str, max \\ 40) do
    str = to_string(str)
    if String.length(str) > max, do: String.slice(str, 0, max - 1) <> "…", else: str
  end

  def format_datetime(%DateTime{} = dt) do
    "#{dt.year}-#{pad(dt.month)}-#{pad(dt.day)} #{pad(dt.hour)}:#{pad(dt.minute)}"
  end
  def format_datetime(%NaiveDateTime{} = dt) do
    "#{dt.year}-#{pad(dt.month)}-#{pad(dt.day)} #{pad(dt.hour)}:#{pad(dt.minute)}"
  end
  def format_datetime(nil), do: "—"
  def format_datetime(other), do: to_string(other)

  defp pad(n), do: String.pad_leading(to_string(n), 2, "0")
end
