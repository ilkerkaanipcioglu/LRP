$path = "B:\DEV\HAREZM_EKOSISTEMI\LRP\LRP_Demo_UI\SAP_GUI\nakit akış\index.html"
$content = Get-Content $path -Raw
$pattern = "(?s)<style>.*?</style>"
$newContent = $content -replace $pattern, '<link rel="stylesheet" href="../sapgui.css" />'
Set-Content $path -Value $newContent -NoNewline
