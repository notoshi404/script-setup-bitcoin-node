#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
# setup_btc_rpc_explorer.sh - BTC RPC Explorer Setup for Bitcoin Node

# ==========================================
# 🎨 COLORS & HELPERS
# ==========================================
if [ -t 1 ]; then
    RED="$(tput setaf 1)"
    GREEN="$(tput setaf 2)"
    YELLOW="$(tput setaf 3)"
    BLUE="$(tput setaf 4)"
    MAGENTA="$(tput setaf 5)"
    CYAN="$(tput setaf 6)"
    BOLD="$(tput bold)"
    RESET="$(tput sgr0)"
else
    RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN="" BOLD="" RESET=""
fi

info(){ printf "%s %s\n" "${BLUE}[..]${RESET}" "$*"; }
ok(){ printf "%s %s\n" "${GREEN}[OK]${RESET}" "$*"; }
warn(){ printf "%s %s\n" "${YELLOW}[WARN]${RESET}" "$*"; }
err(){ printf "%s %s\n" "${RED}[ERROR]${RESET}" "$*" >&2; }

# ==========================================
# 🧭  BTC RPC EXPLORER SETUP
# ==========================================
echo ""
echo "${BLUE}=================================================${RESET}"
echo "${BOLD}     🧭   BTC RPC EXPLORER SETUP               ${RESET}"
echo "${BLUE}=================================================${RESET}"
echo ""

EXPLORER_DIR="/home/$(whoami)/btc-rpc-explorer"
SERVICE_FILE="/etc/systemd/system/btcrpcexplorer.service"
local_ip=$(hostname -I | awk '{print $1}' || echo "Unknown")

info "Installing Node.js v24 via NVM"

# 1. Install NVM
export NVM_DIR="$HOME/.nvm"
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    info "Downloading NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
else
    info "NVM already installed"
fi

# Load NVM (in lieu of restarting shell)
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# 2. Install Node v24
info "Installing Node v24..."
nvm install 24
nvm use 24
nvm alias default 24

# Verify versions
NODE_VER=$(node -v)
NPM_VER=$(npm -v)
info "Verified Node.js version: $NODE_VER"
info "Verified NPM version: $NPM_VER"

# 3. Get actual node path for Systemd
NODE_BIN=$(nvm which 24)
info "Using Node binary at: $NODE_BIN"
ok "Node.js (v24) installed via NVM"

info "Cloning BTC RPC Explorer repository"
if [ ! -d "$EXPLORER_DIR" ]; then
    git clone https://github.com/janoside/btc-rpc-explorer.git "$EXPLORER_DIR"
    ok "Repository cloned"
else
    info "Repository already exists, pulling updates..."
    cd "$EXPLORER_DIR" && git pull
fi

cd "$EXPLORER_DIR"

info "Installing NPM packages (this may take a while)..."
npm install --production >/dev/null 2>&1
ok "NPM packages installed"

info "Configuring .env"
# Create .env config
cat <<EOF > "$EXPLORER_DIR/.env"
BTCEXP_HOST=0.0.0.0
BTCEXP_PORT=3002

# Connect Bitcoin
BTCEXP_BITCOIND_HOST=127.0.0.1
BTCEXP_BITCOIND_PORT=8332
BTCEXP_BITCOIND_COOKIE=/home/$(whoami)/.bitcoin/.cookie
BTCEXP_BITCOIND_RPC_TIMEOUT=0

# Connect Electrs
BTCEXP_ADDRESS_API=electrum
BTCEXP_ELECTRUM_SERVERS=tcp://127.0.0.1:50001
BTCEXP_ELECTRUM_TXINDEX=true

# Use bitcoin-cli
#BTCEXP_BASIC_AUTH_PASSWORD=mypassword
EOF
ok "Configuration written to .env"

info "Creating Systemd Service"
NODE_PATH=$(dirname "$NODE_BIN")
sudo bash -c "cat > $SERVICE_FILE <<EOF
[Unit]
Description=BTC RPC Explorer
Requires=bitcoind.service electrs.service
After=bitcoind.service electrs.service

[Service]
WorkingDirectory=$EXPLORER_DIR
ExecStart=$NODE_PATH/npm start

Environment=PATH=$NODE_PATH:/usr/bin:/bin
Environment=NODE_ENV=production
Environment=BTCEXP_HOST=0.0.0.0

User=$(whoami)
Group=$(whoami)

# Hardening Measures
####################
PrivateTmp=true
ProtectSystem=full
NoNewPrivileges=true
PrivateDevices=true

[Install]
WantedBy=multi-user.target
EOF"
ok "Systemd service created"

info "Enabling and Starting Service"
sudo systemctl daemon-reload
sudo systemctl enable btcrpcexplorer
sudo systemctl start btcrpcexplorer

info "Waiting for service to initialize..."
sleep 5

echo ""
info "BTC RPC Explorer service status:"
sudo systemctl --no-pager status btcrpcexplorer

echo ""
echo "${GREEN}=================================================${RESET}"
echo "${BOLD}   ✅  BTC EXPLORER SETUP COMPLETED SUCCESSFULLY  ✅ ${RESET}"
echo "${GREEN}=================================================${RESET}"
echo " 🌐 Open in browser: ${BOLD}http://$local_ip:3002${RESET}"
echo " 📝 Service status:  ${BOLD}sudo systemctl status btcrpcexplorer${RESET}"
echo " 🔍 Check logs:      ${BOLD}sudo journalctl -u btcrpcexplorer -f${RESET}"
echo ""
