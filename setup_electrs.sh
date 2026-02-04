#!/usr/bin/env bash
set -Eeuo pipefail

### ===== CONFIG =====
ELECTRS_DIR="$HOME/electrs"
ELECTRS_REPO="https://github.com/romanz/electrs.git"
ELECTRS_USER="$(whoami)"
CONF_FILE="$ELECTRS_DIR/electrs.toml"
SERVICE_FILE="/etc/systemd/system/electrs.service"

### ===== COLORS =====
if [ -t 1 ]; then
  RED="$(tput setaf 1)"
  GREEN="$(tput setaf 2)"
  YELLOW="$(tput setaf 3)"
  BLUE="$(tput setaf 4)"
  MAGENTA="$(tput setaf 5)"
  CYAN="$(tput setaf 6)"
  WHITE="$(tput setaf 7)"
  BOLD="$(tput bold)"
  RESET="$(tput sgr0)"
else
  RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN="" WHITE="" BOLD="" RESET=""
fi

log() {
  printf "%s %s\n" "${BLUE}[..]${RESET}" "$*"
}

ok() {
  printf "%s %s\n" "${GREEN}[OK]${RESET}" "$*"
}

warn() {
  printf "%s %s\n" "${YELLOW}[WARN]${RESET}" "$*"
}

die() {
  printf "%s %s\n" "${RED}[ERROR]${RESET}" "$*" >&2
  exit 1
}

# ==========================================
# ⚡  ELECTRS SETUP
# ==========================================
echo ""
echo "${BLUE}=================================================${RESET}"
echo "${BOLD}     ⚡   ELECTRUM SERVER IN RUST (ELECTRS)    ${RESET}"
echo "${BLUE}=================================================${RESET}"
echo ""

### ===== CHECK =====
log "Starting Electrs (Rust) installation"

command -v bitcoind >/dev/null 2>&1 || warn "bitcoind not found in PATH (ensure it's installed & running)"

### ===== SYSTEM PACKAGES =====
log "Installing system dependencies"
sudo apt update
sudo apt install -y build-essential libclang-dev git

### ===== RUST =====
if ! command -v cargo >/dev/null 2>&1; then
  log "Installing Rust toolchain"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
else
  log "Rust already installed"
fi

source "$HOME/.cargo/env"

### ===== CLONE =====
if [ ! -d "$ELECTRS_DIR" ]; then
  log "Cloning electrs repository"
  git clone "$ELECTRS_REPO" "$ELECTRS_DIR"
else
  log "Electrs repository already exists"
fi

cd "$ELECTRS_DIR"

### ===== BUILD =====
log "Building electrs (this may take a while)"
cargo build --locked --release

./target/release/electrs --version || die "Build failed"

### ===== CONFIG =====
log "Creating electrs.toml"

cat <<EOF | tee "$CONF_FILE" > /dev/null
# Bitcoin Core
network = "bitcoin"
daemon_rpc_addr = "127.0.0.1:8332"
daemon_p2p_addr = "127.0.0.1:8333"
cookie_file = "$HOME/.bitcoin/.cookie"

# Electrum RPC
electrum_rpc_addr = "0.0.0.0:50001"

# Database
db_dir = "$ELECTRS_DIR/db"

# Logging
log_filters = "INFO"
EOF

### ===== SYSTEMD =====
log "Creating systemd service"

sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Electrs (Rust Electrum Server)
After=network.target bitcoind.service
Requires=bitcoind.service

[Service]
User=$ELECTRS_USER
Group=$ELECTRS_USER
WorkingDirectory=$ELECTRS_DIR
ExecStart=$ELECTRS_DIR/target/release/electrs --conf $CONF_FILE
Restart=always
RestartSec=30
TimeoutStopSec=60
KillMode=process

Environment=RUST_BACKTRACE=1
LimitNOFILE=1048576

# Security (safe for RocksDB)
PrivateTmp=true
NoNewPrivileges=true
ProtectHome=false
ProtectSystem=full
ReadWritePaths=$ELECTRS_DIR

[Install]
WantedBy=multi-user.target
EOF

### ===== ENABLE & START =====
log "Reloading systemd"
sudo systemctl daemon-reload

log "Enabling electrs"
sudo systemctl enable electrs.service

log "Starting electrs"
sudo systemctl restart electrs.service

echo
log "Electrs service status:"
sudo systemctl --no-pager status electrs.service

ok "Electrs setup completed successfully"

echo ""
echo "${GREEN}=================================================${RESET}"
echo "${BOLD}      ✅  ELECTRS SETUP COMPLETED SUCCESSFULLY ✅    ${RESET}"
echo "${GREEN}=================================================${RESET}"
echo " 📝 Service status: ${BOLD}sudo systemctl status electrs${RESET}"
echo " 🔍 Check logs:     ${BOLD}sudo journalctl -u electrs -f${RESET}"
echo ""
