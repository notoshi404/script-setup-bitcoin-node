#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Exit handler: show error and exit immediately
on_error(){
  local exit_code=$?
  local line=${1:-?}
  err "Error at or near line ${line} (exit ${exit_code})"
  exit "${exit_code}"
}
trap 'on_error $LINENO' ERR
trap 'warn "Interrupted"; exit 130' INT TERM

# Colors for nicer UI
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

info(){ printf "%s %s\n" "${BLUE}[..]${RESET}" "$*"; }
ok(){ printf "%s %s\n" "${GREEN}[OK]${RESET}" "$*"; }
warn(){ printf "%s %s\n" "${YELLOW}[WARN]${RESET}" "$*"; }
err(){ printf "%s %s\n" "${RED}[ERROR]${RESET}" "$*" >&2; }

VERSION="30.2"
ARCH="${ARCH:-}"
if [ -z "${ARCH:-}" ]; then
  case "$(uname -m)" in
    x86_64) ARCH="x86_64-linux-gnu" ;;
    aarch64|arm64) ARCH="aarch64-linux-gnu" ;;
    riscv64) ARCH="riscv64-linux-gnu" ;;
    ppc64|powerpc64|ppc64le) ARCH="powerpc64-linux-gnu" ;;
    *) err "Unsupported architecture: $(uname -m). Supported: x86_64, aarch64, riscv64, powerpc64.\nYou can override with: ARCH=arch-triple ./setup_bitcoind.sh" ; exit 1 ;;
  esac
fi

info "Detected architecture: ${ARCH}"
FILE="bitcoin-${VERSION}-${ARCH}.tar.gz"
URL_BASE="https://bitcoincore.org/bin/bitcoin-core-${VERSION}"

# ==========================================
# ₿  BITCOIN CORE SETUP
# ==========================================
echo ""
echo "${YELLOW}=================================================${RESET}"
echo "${BOLD}     ₿   BITCOIN CORE NODE SETUP ${VERSION}     ${RESET}"
echo "${YELLOW}=================================================${RESET}"
echo ""

info "Starting Secure Bitcoin Core ${VERSION} installation"


info "Installing required system packages"
sudo apt update
sudo apt install -y wget curl gnupg tar python3 ca-certificates
ok "Installed required system packages"

cd /tmp
info "Downloading files..."
TMPDIR="$(mktemp -d)"
# Clean up temporary directory on exit
trap 'test -n "${TMPDIR:-}" && rm -rf "${TMPDIR}"' EXIT
cd "$TMPDIR"

# Verify release exists before attempting downloads
info "Checking release URL availability"
if ! curl -fsS -I "${URL_BASE}/SHA256SUMS" >/dev/null 2>&1; then
  err "Release not found at ${URL_BASE}. Aborting."
  exit 1
fi
ok "Release exists at ${URL_BASE}"

wget -N --https-only "${URL_BASE}/${FILE}"
wget -N --https-only "${URL_BASE}/SHA256SUMS"
wget -N --https-only "${URL_BASE}/SHA256SUMS.asc"

[ -s "$FILE" ] || { echo "Download failed: $FILE missing or empty"; exit 1; }
ok "Downloads completed"

info "Importing Bitcoin Core release signing keys"
curl -s "https://api.github.com/repositories/355107265/contents/builder-keys" | 
grep download_url | 
grep -oE "https://[a-zA-Z0-9./-]+" | 
while read url; do 
    curl -s "$url" | gpg --import > /dev/null 2>&1
done
ok "Imported PGP keys"

info "Verifying PGP signature"
if gpg --verify SHA256SUMS.asc SHA256SUMS 2>&1 | grep -q "Good signature"; then
    echo "[ OK ] PGP Signature is valid."
else
    echo "[ ERROR ] PGP Signature verification failed! Aborting."
    gpg --verify SHA256SUMS.asc SHA256SUMS
    exit 1
fi

info "Verifying checksum"
if sha256sum --ignore-missing --check SHA256SUMS 2>&1 | grep -q "OK"; then
    echo "[ OK ] Checksum matches."
else
    echo "[ ERROR ] Checksum does not match! File might be corrupted."
    exit 1
fi

# Install Bitcoin Core
info "Installing Bitcoin Core"
tar -xzvf "$FILE"
sudo install -m 0755 -o root -g root -t /usr/local/bin bitcoin-${VERSION}/bin/*
ok "Installed bitcoin binaries to /usr/local/bin"

info "Starting bitcoind"
/usr/local/bin/bitcoind -daemon

info "Waiting for Bitcoin to initialize (30 seconds)"
sleep 30

info "Stopping bitcoind to update configuration"
/usr/local/bin/bitcoin-cli stop

sleep 8

ok "bitcoind temporary start/stop sequence complete"

info "Updating bitcoin.conf configuration file"
# Backup existing config to avoid duplicates or data loss
if [ -f "/home/$(whoami)/.bitcoin/bitcoin.conf" ]; then
    mv "/home/$(whoami)/.bitcoin/bitcoin.conf" "/home/$(whoami)/.bitcoin/bitcoin.conf.bak.$(date +%s)"
fi

cat <<EOF > /home/$(whoami)/.bitcoin/bitcoin.conf
# === Bitcoin Core ===
daemon=1
txindex=1
blockfilterindex=1
coinstatsindex=1

# === ZMQ ===
zmqpubrawblock=tcp://0.0.0.0:28332
zmqpubrawtx=tcp://0.0.0.0:28333
zmqpubhashblock=tcp://0.0.0.0:28334
whitelist=127.0.0.1

# === RPC ===
server=1
rpcport=8332
rpcbind=0.0.0.0
rpcallowip=127.0.0.1
rpcallowip=10.0.0.0/8
rpcallowip=172.0.0.0/8
rpcallowip=192.0.0.0/8

# === Network ===
# Tor
listen=1
onlynet=onion
proxy=unix:/run/tor/socks
bind=127.0.0.1
bind=127.0.0.1=onion

# I2P
#onlynet=i2p
#i2psam=127.0.0.1:7656
#i2pacceptincoming=1

debug=tor
debug=i2p

# Network option
#onlynet=ipv4
#onlynet=ipv6

# === Performance ===
#dbcache=2048
EOF

# Systemd Service
info "Creating systemd service for bitcoind"
sudo bash -c "cat > /etc/systemd/system/bitcoind.service <<EOF
[Unit]
Description=Bitcoin daemon
After=network.target

[Service]
ExecStart=/usr/local/bin/bitcoind -daemon \
                                  -pid=/run/bitcoind/bitcoind.pid \
                                  -conf=/home/$(whoami)/.bitcoin/bitcoin.conf \
                                  -datadir=/home/$(whoami)/.bitcoin 

ExecStop=/usr/local/bin/bitcoin-cli stop

# Make sure the config directory is readable by the service user
PermissionsStartOnly=true

# Process management
####################
Type=forking
Restart=on-failure
TimeoutStartSec=infinity
TimeoutStopSec=600


# Directory creation and permissions
####################################

User=$(whoami)
Group=$(whoami)

# /run/bitcoind
RuntimeDirectory=bitcoind
RuntimeDirectoryMode=0710

# /etc/bitcoin
ConfigurationDirectory=bitcoin
ConfigurationDirectoryMode=0710

# /var/lib/bitcoind
StateDirectory=bitcoind
StateDirectoryMode=0710

# Hardening measures
####################

# Provide a private /tmp and /var/tmp.
PrivateTmp=true

# Mount /usr, /boot/ and /etc read-only for the process.
ProtectSystem=full

# Disallow the process and all of its children to gain
# new privileges through execve().
NoNewPrivileges=true

# Use a new /dev namespace only populated with API pseudo devices
# such as /dev/null, /dev/zero and /dev/random.
PrivateDevices=true

# Deny the creation of writable and executable memory mappings.
MemoryDenyWriteExecute=true

[Install]
WantedBy=multi-user.target
EOF"
ok "systemd service for bitcoind created"

# Reload & enable service
info "Reloading systemd, enabling and starting bitcoind service"
sudo systemctl daemon-reload
sudo systemctl enable bitcoind
sudo systemctl start bitcoind

ok "Installation Complete!"
info "Installed: $(/usr/local/bin/bitcoind --version | head -n1)"
info "Service status (brief):"
sudo systemctl --no-pager status bitcoind | sed -n '1,10p'

echo ""
echo "${GREEN}=================================================${RESET}"
echo "${BOLD}   ✅  BITCOIN CORE SETUP COMPLETED SUCCESSFULLY  ✅  ${RESET}"
echo "${GREEN}=================================================${RESET}"
echo ""
echo " 🔍 Check debug log:  ${BOLD}tail -f ~/.bitcoin/debug.log${RESET}"
echo ""

