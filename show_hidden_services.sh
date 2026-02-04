#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
# Script to show all Tor Hidden Service addresses for Bitcoin Node ecosystem
# Author: Bitcoin Node Setup

# Colors
if [ -t 1 ]; then
  GREEN="$(tput setaf 2)"
  YELLOW="$(tput setaf 3)"
  BLUE="$(tput setaf 4)"
  CYAN="$(tput setaf 6)"
  RESET="$(tput sgr0)"
  BOLD="$(tput bold)"
else
  GREEN="" YELLOW="" BLUE="" CYAN="" RESET="" BOLD=""
fi

# Need root permissions to read /var/lib/tor
if [ "$EUID" -ne 0 ]; then
  echo "${YELLOW}[WARN] This script needs to read /var/lib/tor which requires root permissions.${RESET}"
  echo "Please run with sudo: ${BOLD}sudo $0${RESET}"
  exit 1
fi

echo ""
echo "${BLUE}=================================================${RESET}"
echo "${BOLD}     🕵️  Tor Hidden Services (.onion)     ${RESET}"
echo "${BLUE}=================================================${RESET}"
echo ""

# Helper function to print service info
print_onion() {
    local name="$1"
    local path="$2"
    local desc="$3"

    printf "%-25s" "${CYAN}${name}:${RESET}"
    
    if [ -f "${path}/hostname" ]; then
        onion_addr=$(cat "${path}/hostname")
        echo "${GREEN}${onion_addr}${RESET}"
        if [ -n "$desc" ]; then
            echo "   ${YELLOW}└─ ${desc}${RESET}"
        fi
    else
        echo "${YELLOW}[Waiting for Tor to create key]${RESET}"
        echo "   ${YELLOW}└─ (Restart Tor if this persists: sudo systemctl restart tor)${RESET}"
    fi
    echo ""
}

# 1. Bitcoin RPC
print_onion "Bitcoin RPC" "/var/lib/tor/bitcoinrpc" "For remote node connection (port 8332)"

# 2. Electrs
print_onion "Electrs" "/var/lib/tor/electrs" "Electrum server (TCP: 50001 / SSL: 50002)"

# 3. Mempool
print_onion "Mempool" "/var/lib/tor/mempool" "Mempool Explorer (Web)"

# 4. BTC RPC Explorer
print_onion "BTC RPC Explorer" "/var/lib/tor/bitcoinexplorer" "Block Explorer (Web)"

echo "${BLUE}=================================================${RESET}"
echo "💡 To use these, paste the address into a Tor Browser"
echo "   or configure your wallet to use the proxy (127.0.0.1:9050)"
echo ""
