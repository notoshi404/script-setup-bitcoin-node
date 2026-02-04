#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

on_error(){ local code=$?; echo "[ERROR] Error at or near line ${1:-?} (exit ${code})" >&2; exit ${code}; }
trap 'on_error $LINENO' ERR
trap 'echo "[WARN] Interrupted"; exit 130' INT TERM

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
# 🧅  TOR SETUP for Bitcoin Node
# ==========================================
echo ""
echo "${BLUE}=================================================${RESET}"
echo "${BOLD}       🧅   BITCOIN NODE TOR SETUP             ${RESET}"
echo "${BLUE}=================================================${RESET}"
echo ""

info "Tor Setup for Bitcoin Node"

info "Installing tor (if missing)"
sudo apt update
sudo apt install -y tor
ok "tor package installed (or already present)"

sudo cp /etc/tor/torrc /etc/tor/torrc.bak

sudo bash -c "cat > /etc/tor/torrc <<EOF

SocksPort unix:/run/tor/socks
SocksPort 9050

# ControlPort & Authentication
ControlPort 9051
CookieAuthentication 1
CookieAuthFileGroupReadable 1

DataDirectory /var/lib/tor

# Bitcoin RPC
HiddenServiceDir /var/lib/tor/bitcoinrpc
HiddenServiceVersion 3
HiddenServicePort 8332 127.0.0.1:8332
HiddenServiceEnableIntroDoSDefense 1

# Electrs
HiddenServiceDir /var/lib/tor/electrs
HiddenServiceVersion 3
HiddenServicePort 50001 127.0.0.1:50001
HiddenServiceEnableIntroDoSDefense 1

# BTC RPC Explorer
HiddenServiceDir /var/lib/tor/bitcoinexplorer
HiddenServiceVersion 3
HiddenServicePort 3002 127.0.0.1:3002
HiddenServiceEnableIntroDoSDefense 1

# Mempool
HiddenServiceDir /var/lib/tor/mempool
HiddenServiceVersion 3
HiddenServicePort 8888 127.0.0.1:8888
HiddenServiceEnableIntroDoSDefense 1
EOF"

info "Setting up permissions"
sudo mkdir -p /run/tor
sudo chown -R debian-tor:debian-tor /run/tor
sudo chmod -R 2750 /run/tor
sudo usermod -a -G debian-tor $(whoami)

info "Checking Tor configuration..."
if sudo -u debian-tor tor --verify-config | grep -q "Configuration was valid"; then
    ok "Tor configuration is valid — restarting and enabling service"
    sudo systemctl restart tor
    sudo systemctl enable tor
    ok "Tor setup complete"
    info "[!] IMPORTANT: Please log out and log back in to apply group changes."
else
    err "Tor configuration is invalid — aborting. See output below:"
    sudo -u debian-tor tor --verify-config || true
    exit 1
fi


SERVICES=("bitcoinrpc" "electrs" "bitcoinexplorer" "mempool")

info "Starting Tor Services Setup"

for service in "${SERVICES[@]}"; do
    TARGET="/var/lib/tor/$service"
    info "Configuring: ${TARGET}"
    sudo mkdir -p "$TARGET"
    sudo chown -R debian-tor:debian-tor "$TARGET"
    sudo chmod 700 "$TARGET"
    ok "Configured ${TARGET} (owner=debian-tor, mode=700)"
done

info "Re-checking Tor configuration after service dirs"
if sudo -u debian-tor tor --verify-config | grep -q "Configuration was valid"; then
    ok "Tor configuration valid — restarting tor"
    sudo systemctl restart tor
    
    echo ""
    echo "${GREEN}=================================================${RESET}"
    echo "${BOLD}     ✅  TOR SETUP COMPLETED SUCCESSFULLY  ✅    ${RESET}"
    echo "${GREEN}=================================================${RESET}"
    echo " You can now view your hidden services with:"
    echo " ${BOLD}sudo ./show_hidden_services.sh${RESET}"
    echo ""
else
    err "Tor configuration invalid after changes — see output below:"
    sudo -u debian-tor tor --verify-config || true
    exit 1
fi

ok "Tor setup completed successfully"
