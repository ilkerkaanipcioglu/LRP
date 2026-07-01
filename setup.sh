#!/usr/bin/env bash
# LRP Setup Script — Linux / macOS
# Kullanım: ./setup.sh
# Elixir'i kontrol eder, bağımlılıkları yükler, DB'yi kurar, seed çalıştırır.

set -e

# ─── Renkler ─────────────────────────────────────────────────────────────────

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

banner() {
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════╗${RESET}"
  echo -e "${CYAN}║         LRP — Kurulum Başlıyor               ║${RESET}"
  echo -e "${CYAN}╚══════════════════════════════════════════════╝${RESET}"
  echo ""
}

step() {
  echo -e "${YELLOW}[$1]${RESET} $2"
}

ok() {
  echo -e "    ${GREEN}✓${RESET} $1"
}

fail() {
  echo -e "    ${RED}✗ HATA: $1${RESET}"
}

# ─── Banner ──────────────────────────────────────────────────────────────────

banner

# ─── 1. Elixir kontrolü ──────────────────────────────────────────────────────

step 1 "Elixir kontrol ediliyor..."

if ! command -v elixir &> /dev/null; then
  fail "Elixir bulunamadı."
  echo ""
  echo "  Kurulum için:"
  echo "    macOS : brew install elixir"
  echo "    Ubuntu: https://elixir-lang.org/install.html#gnu-linux"
  echo "    asdf  : asdf plugin add elixir && asdf install elixir latest"
  echo ""
  exit 1
fi

ELIXIR_VER=$(elixir --version | grep Elixir | head -1)
ok "$ELIXIR_VER"

# ─── 2. Hex & Rebar ──────────────────────────────────────────────────────────

step 2 "Hex ve Rebar güncelleniyor..."
mix local.hex   --force --quiet
mix local.rebar --force --quiet
ok "Hex ve Rebar hazır"

# ─── 3. Bağımlılıklar ────────────────────────────────────────────────────────

step 3 "Bağımlılıklar yükleniyor (mix deps.get)..."
mix deps.get --quiet
ok "Bağımlılıklar yüklendi"

# ─── 4. Veritabanı ───────────────────────────────────────────────────────────

step 4 "Veritabanı oluşturuluyor..."
mix ecto.drop   --quiet 2>/dev/null || true
mix ecto.create --quiet
ok "Veritabanı oluşturuldu"

# ─── 5. Migration ────────────────────────────────────────────────────────────

step 5 "Migration'lar çalıştırılıyor..."
mix ecto.migrate --quiet
ok "Migration'lar tamamlandı"

# ─── 6. Demo verisi ──────────────────────────────────────────────────────────

step 6 "Demo verisi yükleniyor (mix lrp.seed)..."
mix lrp.seed --quiet
ok "Demo verisi hazır"

# ─── 7. Başarılı ─────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║           Kurulum Tamamlandı! ✅              ║${RESET}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${RESET}"
echo ""
echo "  Sonraki adımlar:"
echo ""
echo -e "    ${CYAN}mix lrp.status${RESET}          # Sistem durumu"
echo -e "    ${CYAN}mix lrp.tenant list${RESET}     # Tenant listesi"
echo -e "    ${CYAN}mix lrp.demo${RESET}            # Canlı demo (5 dk)"
echo -e "    ${CYAN}mix test${RESET}                # Testleri çalıştır"
echo ""
echo "  MCP / AI Agent için:"
echo -e "    ${CYAN}mix lrp.status --json${RESET}   # JSON çıktı"
echo ""
