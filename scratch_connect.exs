# Scratch script to test connection to lestupid
IO.puts("GitHub API checking...")
case Req.get("https://api.github.com/repos/ilkerkaanipcioglu/lestupid") do
  {:ok, %{status: 200, body: body}} ->
    IO.puts("Repo is PUBLIC! Name: #{body["full_name"]}")
  {:ok, %{status: status, body: body}} ->
    IO.puts("Failed with status: #{status}")
    IO.inspect(body)
  {:error, reason} ->
    IO.puts("Error:")
    IO.inspect(reason)
end
