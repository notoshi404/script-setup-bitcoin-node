#!/bin/bash
set -u
# check_status.sh - All-in-one Bitcoin Node Status Dashboard

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
    DIM="$(tput dim)"
    RESET="$(tput sgr0)"
else
    RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN="" BOLD="" DIM="" RESET=""
fi

# Box Drawing Characters
BOX_H="="
BOX_V="┃"
BOX_TL="┏"
BOX_TR="┓"
BOX_BL="┗"
BOX_BR="┛"
BOX_VL="┣"
BOX_VR="┫"

print_header() {
    local title="  $1  "
    local width=52
    local title_len=${#title}
    local total_pads=$(( width - title_len ))
    local side_len=$(( total_pads / 2 ))
    
    printf "\n${CYAN}"
    for ((i=0; i<side_len; i++)); do printf "$BOX_H"; done
    printf "${BOLD}%s${RESET}${CYAN}" "$title"
    for ((i=0; i<$((total_pads - side_len)); i++)); do printf "$BOX_H"; done
    printf "${RESET}\n"
}

print_line() {
    printf "  ${BOLD}%-18s${RESET} %s\n" "$1:" "$2"
}

progress_bar() {
    local percent=$1
    local width=20
    local filled=$(( (percent * width) / 100 ))
    local empty=$(( width - filled ))
    
    printf "["
    for ((i=0; i<filled; i++)); do printf "█"; done
    for ((i=0; i<empty; i++)); do printf "░"; done
    printf "] %d%%" "$percent"
}

check_service() {
    local service="$1"
    local name="$2"
    if systemctl is-active --quiet "$service"; then
        local uptime=$(systemctl show "$service" --property=ActiveEnterTimestamp | cut -d= -f2 | awk '{print $1}')
        printf "  ${GREEN}●${RESET} %-19s ${GREEN}ACTIVE${RESET} ${DIM}(since $uptime)${RESET}\n" "$name"
    else
        if systemctl is-failed --quiet "$service"; then
            printf "  ${RED}●${RESET} %-19s ${RED}FAILED${RESET}\n" "$name"
        else
            printf "  ${YELLOW}●${RESET} %-19s ${YELLOW}INACTIVE${RESET}\n" "$name"
        fi
    fi
}

get_bitcoin_info() {
    BITCOIN_CLI="/usr/local/bin/bitcoin-cli"
    
    if [ ! -f "$BITCOIN_CLI" ]; then
        echo "  ${YELLOW}bitcoin-cli not found${RESET}"
        return
    fi
    
    if ! systemctl is-active --quiet bitcoind; then
        echo "  ${YELLOW}Bitcoind is not running${RESET}"
        return
    fi

    BTC_ARGS=""
    if [ "$EUID" -eq 0 ]; then
        REAL_USER=${SUDO_USER:-root}
        if [ "$REAL_USER" != "root" ]; then
             USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
             [ -d "$USER_HOME/.bitcoin" ] && BTC_ARGS="-datadir=$USER_HOME/.bitcoin"
        fi
    fi

    chain_info=$($BITCOIN_CLI $BTC_ARGS getblockchaininfo 2>/dev/null)
    network_info=$($BITCOIN_CLI $BTC_ARGS getnetworkinfo 2>/dev/null)
    peer_info=$($BITCOIN_CLI $BTC_ARGS getpeerinfo 2>/dev/null)
    
    if [ -n "$chain_info" ]; then
        blocks=$(echo "$chain_info" | grep '"blocks":' | awk '{print $2}' | tr -d ',')
        headers=$(echo "$chain_info" | grep '"headers":' | awk '{print $2}' | tr -d ',')
        progress=$(echo "$chain_info" | grep '"verificationprogress":' | awk '{print $2}' | tr -d ',')
        
        # Calculate percentage for progress bar
        percent_float=$(awk "BEGIN {print $progress * 100}")
        percent_int=${percent_float%.*}
        [ -z "$percent_int" ] && percent_int=0
        
        printf "  ${BOLD}%-18s${RESET} " "Sync Progress:"
        progress_bar "$percent_int"
        printf " ($blocks / $headers)\n"
        
        if [ -n "$network_info" ]; then
            version=$(echo "$network_info" | grep '"subversion":' | head -n 1 | awk -F': ' '{print $2}' | tr -d '",')
            print_line "Version" "$version"
            
            onion=$(echo "$network_info" | grep -A 10 '"localaddresses"' | grep -A 2 '"onion"' | grep '"address":' | awk '{print $2}' | tr -d '",')
            [ -z "$onion" ] && onion=$(echo "$network_info" | grep -oE '[a-z2-7]{56}\.onion' | head -n 1)
            i2p=$(echo "$network_info" | grep -oE '[a-z2-7]{52}\.b32\.i2p' | head -n 1)
            
            print_line "Tor Address" "${onion:-N/A}"
            print_line "I2P Address" "${i2p:-N/A}"
        fi

        if [ -n "$peer_info" ]; then
            inbound=$(echo "$peer_info" | grep '"inbound": true' | wc -l)
            outbound=$(echo "$peer_info" | grep '"inbound": false' | wc -l)
            total=$((inbound + outbound))
            print_line "Peers" "$total (In: $inbound / Out: $outbound)"
        fi
    else
        echo "  ${YELLOW}Failed to query Bitcoin Core${RESET}"
    fi
}

# ==========================================
# 🚀 DASHBOARD
# ==========================================
clear
echo ""
echo "${BLUE}${BOLD}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${RESET}"
echo "${BLUE}${BOLD}┃             BITCOIN NODE DASHBOARD                 ┃${RESET}"
echo "${BLUE}${BOLD}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${RESET}"
printf "  ${DIM}Last Updated: $(date '+%Y-%m-%d %H:%M:%S')${RESET}\n"

# 1. System Health
print_header "SYSTEM HEALTH"
uptime_val=$(uptime -p 2>/dev/null || uptime | awk -F'up ' '{print $2}' | cut -d, -f1)
load=$(uptime | awk -F'load average:' '{ print $2 }' | xargs)
mem_used=$(free -h | awk '/^Mem:/ {print $3 "/" $2}')
disk_info=$(df -h / | tail -n 1)
disk_used=$(echo "$disk_info" | awk '{print $5}')
disk_free=$(echo "$disk_info" | awk '{print $4}')

temp="N/A"
if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    t=$(cat /sys/class/thermal/thermal_zone0/temp)
    temp=$(awk "BEGIN {printf \"%.1f°C\", $t / 1000}")
fi

print_line "Uptime" "$uptime_val"
print_line "CPU Load" "$load"
print_line "CPU Temp" "$temp"
print_line "Memory" "$mem_used"
print_line "Disk Space" "$disk_free free ($disk_used used)"

# 2. Services
print_header "SERVICES STATUS"
check_service "bitcoind" "Bitcoin Core"
check_service "electrs" "Electrs"
check_service "tor" "Tor Network"
check_service "i2pd" "I2P Router"
check_service "btcrpcexplorer" "BTC RPC Explorer"

# 3. Bitcoin Details
print_header "BITCOIN NETWORK"
get_bitcoin_info

# 4. Network Info
print_header "LOCAL NETWORK"
hostname=$(hostname)
local_ip=$(hostname -I | awk '{print $1}' || echo "Unknown")
print_line "Hostname" "$hostname.local"
print_line "Local IP" "$local_ip"
print_line "Bitcoin RPC" "http://$local_ip:8332"
print_line "Electrs" "http://$local_ip:50001"
print_line "BTC Explorer" "http://$local_ip:3002"
print_line "Mempool" "http://$local_ip:8888"

# 5. Tor Hidden Services
if [ -d /var/lib/tor ]; then
    print_header "TOR HIDDEN SERVICES"
    for service in bitcoinrpc electrs mempool bitcoinexplorer; do
        if [ -f "/var/lib/tor/$service/hostname" ]; then
            addr=$(sudo cat "/var/lib/tor/$service/hostname" 2>/dev/null || echo "N/A")
            case "$service" in
                bitcoinrpc)      name="Bitcoin RPC   "; port=":8332" ;;
                electrs)         name="Electrs       "; port=":50001" ;;
                mempool)         name="Mempool       "; port=":8888" ;;
                bitcoinexplorer) name="BTC Explorer  "; port=":3002" ;;
                *)               name="$service"; port="" ;;
            esac
            printf "  ${CYAN}●${RESET} ${BOLD}%-16s${RESET} ${addr}${port}\n" "$name"
        fi
    done
fi

echo ""
printf "${BLUE}%52s${RESET}\n" | tr ' ' "$BOX_H"
echo "  ${BOLD}Tip:${RESET} Run ${BOLD}./check_status.sh${RESET} to refresh"
echo ""