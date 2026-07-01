# LRP Setup Script — Windows PowerShell
# Kullanim: .\setup.ps1
# Elixir'i kurup projeyi tek komutla calistirir.

$ErrorActionPreference = "Stop"

function Write-Banner {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║         LRP — Kurulum Basliyor               ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param($n, $msg)
    Write-Host "[$n] $msg" -ForegroundColor Yellow
}

function Write-OK {
    param($msg)
    Write-Host "    OK  $msg" -ForegroundColor Green
}

function Write-Fail {
    param($msg)
    Write-Host "    HATA: $msg" -ForegroundColor Red
}

# ─── Banner ──────────────────────────────────────────────────────────────────

Write-Banner

# ─── 1. Elixir kontrolu ──────────────────────────────────────────────────────

Write-Step 1 "Elixir kontrol ediliyor..."

if (-not (Get-Command elixir -ErrorAction SilentlyContinue)) {
    Write-Fail "Elixir bulunamadi."
    Write-Host ""
    Write-Host "  Kurulum icin:" -ForegroundColor White
    Write-Host "    1. https://elixir-lang.org/install.html" -ForegroundColor White
    Write-Host "    2. Windows: https://github.com/elixir-lang/elixir-windows-setup/releases" -ForegroundColor White
    Write-Host "    3. winget install GNU.Erlang" -ForegroundColor White
    Write-Host ""
    exit 1
}

$elixirVersion = elixir --version 2>&1 | Select-String "Elixir"
Write-OK $elixirVersion

# ─── 2. Hex & Rebar ──────────────────────────────────────────────────────────

Write-Step 2 "Hex ve Rebar guncelleniyor..."
mix local.hex   --force --quiet
mix local.rebar --force --quiet
Write-OK "Hex ve Rebar hazir"

# ─── 3. Bagimliliklar ────────────────────────────────────────────────────────

Write-Step 3 "Bagimliliklar yukleniyor (mix deps.get)..."
mix deps.get --quiet
Write-OK "Bagimliliklar yuklendi"

# ─── 4. Veritabani ───────────────────────────────────────────────────────────

Write-Step 4 "Veritabani olusturuluyor..."
mix ecto.drop   --quiet 2>$null
mix ecto.create --quiet
Write-OK "Veritabani olusturuldu"

# ─── 5. Migration ────────────────────────────────────────────────────────────

Write-Step 5 "Migration'lar calistiriliyor..."
mix ecto.migrate --quiet
Write-OK "Migration'lar tamamlandi"

# ─── 6. Demo verisi ──────────────────────────────────────────────────────────

Write-Step 6 "Demo verisi yukleniyor (mix lrp.seed)..."
mix lrp.seed --quiet
Write-OK "Demo verisi hazir"

# ─── 7. Basarili ─────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║           Kurulum Tamamlandi!                ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Sonraki adimlar:" -ForegroundColor White
Write-Host ""
Write-Host "    mix lrp.status          # Sistem durumu" -ForegroundColor Cyan
Write-Host "    mix lrp.tenant list     # Tenant listesi" -ForegroundColor Cyan
Write-Host "    mix lrp.demo            # Canli demo (5 dk)" -ForegroundColor Cyan
Write-Host "    mix test                # Testleri calistir" -ForegroundColor Cyan
Write-Host ""
Write-Host "  MCP / AI Agent icin:" -ForegroundColor White
Write-Host "    mix lrp.status --json   # JSON cikti" -ForegroundColor Cyan
Write-Host ""
