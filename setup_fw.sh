#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

on_error(){ local code=$?; echo "[ERROR] Error at or near line ${1:-?} (exit ${code})" >&2; exit ${code}; }
trap 'on_error $LINENO' ERR
trap 'echo "[WARN] Interrupted"; exit 130' INT TERM

# Colors and log helpers
if [ -t 1 ]; then
  RED="$(tput setaf 1)"
  GREEN="$(tput setaf 2)"
  YELLOW="$(tput setaf 3)"
  BLUE="$(tput setaf 4)"
  BOLD="$(tput bold)"
  RESET="$(tput sgr0)"
else
  RED="" GREEN="" YELLOW="" BLUE="" BOLD="" RESET=""
fi
info(){ printf "%s %s\n" "${BLUE}[..]${RESET}" "$*"; }
ok(){ printf "%s %s\n" "${GREEN}[OK]${RESET}" "$*"; }
warn(){ printf "%s %s\n" "${YELLOW}[WARN]${RESET}" "$*"; }
err(){ printf "%s %s\n" "${RED}[ERROR]${RESET}" "$*" >&2; }


# ==========================================
# 🛡️  FIREWALL SETUP (UFW)
# ==========================================
echo ""
echo "${BLUE}=================================================${RESET}"
echo "${BOLD}       🛡️   BITCOIN NODE FIREWALL SETUP        ${RESET}"
echo "${BLUE}=================================================${RESET}"
echo ""

info "Configuring Firewall for Bitcoin Node"

sudo apt update && sudo apt install -y ufw
ok "ufw installed (or already present)"

info "Setting default policies"
sudo ufw default deny incoming
sudo ufw default allow outgoing
ok "Default policies set"

info ">> SSH <<"
sudo ufw allow 22/tcp comment 'SSH' && ok "Allowed SSH (22/tcp)"

info ">> Bitcoin P2P <<"
sudo ufw allow 8333/tcp comment 'Bitcoin P2P' && ok "Allowed Bitcoin P2P (8333/tcp)"

info ">> Bitcoin RPC <<"
sudo ufw allow 8332/tcp comment 'Bitcoin core RPC' && ok "Allowed Bitcoin RPC (8332/tcp)"

info ">> Tor SOCKS <<"
sudo ufw allow 9050/tcp comment 'Tor SOCKS' && ok "Allowed Tor SOCKS (9050/tcp)"

info ">> Tor Control <<"
sudo ufw allow 9051/tcp comment 'Tor Control' && ok "Allowed Tor Control (9051/tcp)"

info ">> Electrs <<"
sudo ufw allow 50001/tcp comment 'Electrs TCP' && ok "Allowed Electrs TCP (50001/tcp)"
sudo ufw allow 50002/tcp comment 'Electrs SSL' && ok "Allowed Electrs SSL (50002/tcp)"

info ">> BTC-RPC-Explorer <<"
sudo ufw allow 3002/tcp comment 'btc-rpc-explorer' && ok "Allowed BTC-RPC-Explorer (3002/tcp)"

info ">> Mempool <<"
sudo ufw allow 8888/tcp comment 'Mempool' && ok "Allowed Mempool (8888/tcp)"

info ">> i2pd <<"
sudo ufw allow 7070/tcp comment 'i2pd WebConsole' && ok "Allowed i2pd WebConsole (7070/tcp)"
sudo ufw allow 7656/tcp comment 'i2pd SAM' && ok "Allowed i2pd SAM (7656/tcp)"

info "Enabling UFW (confirm)"
echo "y" | sudo ufw enable
ok "UFW enabled"

sudo ufw status verbose
echo ""
echo "${GREEN}=================================================${RESET}"
echo "${BOLD}      ✅  FIREWALL CONFIG COMPLETE  ✅       ${RESET}"
echo "${GREEN}=================================================${RESET}"
echo ""

