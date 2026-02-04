#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

on_error(){ local code=$?; echo "[ERROR] Error at or near line ${1:-?} (exit ${code})" >&2; exit ${code}; }
trap 'on_error $LINENO' ERR
trap 'echo "[WARN] Interrupted"; exit 130' INT TERM

# Colors & logging helpers
if [ -t 1 ]; then
  RED="$(tput setaf 1)"
  GREEN="$(tput setaf 2)"
  YELLOW="$(tput setaf 3)"
  BLUE="$(tput setaf 4)"
  RESET="$(tput sgr0)"
else
  RED="" GREEN="" YELLOW="" BLUE="" RESET=""
fi
info(){ printf "%s %s\n" "${BLUE}[..]${RESET}" "$*"; }
ok(){ printf "%s %s\n" "${GREEN}[OK]${RESET}" "$*"; }
warn(){ printf "%s %s\n" "${YELLOW}[WARN]${RESET}" "$*"; }
err(){ printf "%s %s\n" "${RED}[ERROR]${RESET}" "$*" >&2; }

info "Starting i2pd Setup for Bitcoin Node"

info "Installing prerequisites (curl, gnupg, lsb-release if missing)"
sudo apt update
sudo apt install -y curl gnupg lsb-release
ok "Prerequisites installed"


# Backup existing i2pd repository configurations if present
if [ -f /usr/share/keyrings/i2pd-archive-keyring.gpg ]; then
  sudo cp /usr/share/keyrings/i2pd-archive-keyring.gpg /usr/share/keyrings/i2pd-archive-keyring.gpg.bak.$(date -Iseconds) || true
  sudo rm -f /usr/share/keyrings/i2pd-archive-keyring.gpg
fi
if [ -f /etc/apt/sources.list.d/i2pd.list ]; then
  sudo cp /etc/apt/sources.list.d/i2pd.list /etc/apt/sources.list.d/i2pd.list.bak.$(date -Iseconds) || true
  sudo rm -f /etc/apt/sources.list.d/i2pd.list
fi

# Use official i2pd repository setup script (handles GPG key and repository configuration)
info "Adding i2pd repository using official setup script..."
if wget -q -O - https://repo.i2pd.xyz/.help/add_repo | sudo bash -s -; then
  ok "i2pd repository and GPG key added successfully"
else
  err "Failed to add i2pd repository"
  exit 1
fi

info "Updating apt and installing i2pd"
sudo apt update
sudo apt install -y i2pd
ok "i2pd installed"


info "Backing up existing i2pd config (if any) and writing new config"
sudo mkdir -p /etc/i2pd
if [ -f /etc/i2pd/i2pd.conf ]; then
  sudo cp /etc/i2pd/i2pd.conf /etc/i2pd/i2pd.conf.bak.$(date -Iseconds) || true
fi

sudo bash -c 'cat > /etc/i2pd/i2pd.conf <<EOF
# i2pd configuration for Bitcoin node
# See https://i2pd.readthedocs.io/en/latest/user-guide/configuration/

# Logging
log = file
loglevel = warn

# Network
ipv4 = true
ipv6 = true

# SAM interface (required for Bitcoin Core)
[sam]
enabled = true
address = 127.0.0.1
port = 7656

# HTTP webconsole
[http]
enabled = true
address = 127.0.0.1
port = 7070
EOF'

# Create tunnels.conf file and tunnels.conf.d directory
sudo mkdir -p /etc/i2pd/tunnels.conf.d
sudo touch /etc/i2pd/tunnels.conf
if getent group i2pd >/dev/null 2>&1; then
  sudo chown -R root:i2pd /etc/i2pd
  sudo chmod -R 0750 /etc/i2pd
  sudo chmod 0640 /etc/i2pd/i2pd.conf || true
else
  sudo chown -R root:root /etc/i2pd
  sudo chmod -R 0755 /etc/i2pd
fi
ok "i2pd configuration written and permissions set"

info "Enabling and restarting i2pd"
sudo systemctl enable i2pd
sudo systemctl restart i2pd

if sudo systemctl is-active --quiet i2pd; then
  ok "i2pd is active and running"
  info "SAM Bridge is running on 127.0.0.1:7656"
  info "You can check status at http://127.0.0.1:7070"
else
  err "i2pd failed to start — check 'journalctl -u i2pd -n 50 --no-pager'"
  sudo systemctl status i2pd || true
  exit 1
fi
