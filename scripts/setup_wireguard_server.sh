#!/bin/bash
# ============================================================
# Oracle Cloud Free VPS — WireGuard Server Setup Script
# Run this on each Oracle Cloud VM (Ubuntu 22.04+)
# ============================================================
# Usage:
#   scp setup_wireguard_server.sh ubuntu@YOUR_VM_IP:~/
#   ssh ubuntu@YOUR_VM_IP
#   chmod +x setup_wireguard_server.sh && sudo bash setup_wireguard_server.sh
#
# After running, it prints the client config values you need
# to paste into built_in_servers.json
# ============================================================

set -euo pipefail

# ---- Configuration ----
WG_PORT=51820
WG_INTERFACE="wg0"
CLIENT_ADDRESS="10.0.0.2/32"
SERVER_ADDRESS="10.0.0.1/24"
DNS="1.1.1.1, 1.0.0.1"

echo "============================================"
echo "   WireGuard Server Setup for Android VPN"
echo "============================================"
echo ""

# ---- 0. Check if running as root ----
if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] Please run with sudo: sudo bash setup_wireguard_server.sh"
    exit 1
fi

# ---- 0.5. Stop existing WireGuard if running ----
if systemctl is-active --quiet wg-quick@${WG_INTERFACE} 2>/dev/null; then
    echo "[*] Stopping existing WireGuard interface..."
    systemctl stop wg-quick@${WG_INTERFACE} || true
    systemctl disable wg-quick@${WG_INTERFACE} || true
fi

# ---- 1. Install WireGuard + iptables ----
echo "[1/7] Installing WireGuard and iptables..."
apt-get update -qq
apt-get install -y -qq wireguard wireguard-tools iptables qrencode curl

# Verify iptables is available
if ! command -v iptables &>/dev/null; then
    echo "[ERROR] iptables installation failed!"
    echo "  Try: apt-get install -y iptables"
    exit 1
fi
echo "    iptables version: $(iptables --version)"

# ---- 2. Enable IP forwarding ----
echo "[2/7] Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1
# Remove duplicates and ensure it's set persistently
grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p > /dev/null 2>&1

# ---- 3. Generate server keys ----
echo "[3/7] Generating server keys..."
umask 077
SERVER_PRIVATE_KEY=$(wg genkey)
SERVER_PUBLIC_KEY=$(echo "$SERVER_PRIVATE_KEY" | wg pubkey)
PRESHARED_KEY=$(wg genpsk)

# ---- 4. Generate client keys ----
echo "[4/7] Generating client keys..."
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)

# ---- 5. Detect network interface and public IP ----
echo "[5/7] Detecting network..."
DEFAULT_IFACE=$(ip -4 route show default | awk '{print $5}' | head -1)
if [ -z "$DEFAULT_IFACE" ]; then
    # Fallback: pick the first non-loopback interface
    DEFAULT_IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -1)
fi
echo "    Network interface: $DEFAULT_IFACE"

PUBLIC_IP=$(curl -s --max-time 10 https://api.ipify.org || \
            curl -s --max-time 10 https://ifconfig.me || \
            curl -s --max-time 10 https://icanhazip.com || \
            echo "COULD_NOT_DETECT")
PUBLIC_IP=$(echo "$PUBLIC_IP" | tr -d '[:space:]')
echo "    Public IP: $PUBLIC_IP"

if [ "$PUBLIC_IP" = "COULD_NOT_DETECT" ]; then
    echo "[WARNING] Could not auto-detect public IP."
    echo "  You'll need to manually replace it in the output below."
fi

# ---- 6. Create WireGuard config ----
echo "[6/7] Creating WireGuard configuration..."

cat > /etc/wireguard/${WG_INTERFACE}.conf << EOF
[Interface]
Address = ${SERVER_ADDRESS}
ListenPort = ${WG_PORT}
PrivateKey = ${SERVER_PRIVATE_KEY}
SaveConfig = false

# NAT masquerade — works with both iptables and nftables
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ${DEFAULT_IFACE} -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ${DEFAULT_IFACE} -j MASQUERADE

[Peer]
# Android VPN Client
PublicKey = ${CLIENT_PUBLIC_KEY}
PresharedKey = ${PRESHARED_KEY}
AllowedIPs = ${CLIENT_ADDRESS}
EOF

chmod 600 /etc/wireguard/${WG_INTERFACE}.conf
echo "    Config written to /etc/wireguard/${WG_INTERFACE}.conf"

# ---- 7. Open firewall + Start WireGuard ----
echo "[7/7] Opening firewall and starting WireGuard..."

# Open WireGuard port on VM firewall (Oracle Cloud iptables)
iptables -I INPUT -p udp --dport ${WG_PORT} -j ACCEPT
# Also allow established connections
iptables -I INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
# Save iptables rules if netfilter-persistent is available
if command -v netfilter-persistent &>/dev/null; then
    netfilter-persistent save 2>/dev/null || true
fi

# Enable and start WireGuard
systemctl enable wg-quick@${WG_INTERFACE}

if systemctl start wg-quick@${WG_INTERFACE}; then
    echo ""
    echo "============================================"
    echo "   ✅ SERVER SETUP COMPLETE!"
    echo "============================================"
else
    echo ""
    echo "============================================"
    echo "   ❌ WireGuard FAILED TO START"
    echo "============================================"
    echo ""
    echo "  Diagnostics:"
    echo "  ---"
    journalctl -u wg-quick@${WG_INTERFACE} --no-pager -n 20 2>/dev/null || true
    echo "  ---"
    echo ""
    echo "  Common fixes:"
    echo "  1. Check kernel module:  modprobe wireguard"
    echo "  2. Check iptables:       which iptables && iptables -L"
    echo "  3. Check config syntax:  wg-quick strip ${WG_INTERFACE}"
    echo "  4. Check interface:      ip link show ${DEFAULT_IFACE}"
    echo "  5. Manual start:         wg-quick up ${WG_INTERFACE}"
    echo ""
    echo "  After fixing, run:  systemctl start wg-quick@${WG_INTERFACE}"
    echo ""
fi

# ---- Show WireGuard status ----
echo ""
echo "  WireGuard status:"
wg show 2>/dev/null || echo "  (not running yet)"
echo ""

echo "============================================"
echo "  SERVER INFO"
echo "============================================"
echo ""
echo "  Server Public IP:     $PUBLIC_IP"
echo "  WireGuard Port:       $WG_PORT"
echo "  Server Public Key:    $SERVER_PUBLIC_KEY"
echo "  Client Private Key:   $CLIENT_PRIVATE_KEY"
echo "  Client Address:       ${CLIENT_ADDRESS%/*}"
echo "  Preshared Key:        $PRESHARED_KEY"
echo ""
echo "============================================"
echo "  📋 COPY-PASTE INTO built_in_servers.json:"
echo "============================================"
echo ""
cat << JSONBLOCK
{
  "id": "oracle-$(hostname -s)-1",
  "name": "Oracle $(hostname -s | tr '[:lower:]' '[:upper:]')",
  "serverAddress": "$PUBLIC_IP",
  "port": $WG_PORT,
  "publicKey": "$SERVER_PUBLIC_KEY",
  "clientPrivateKey": "$CLIENT_PRIVATE_KEY",
  "clientAddress": "${CLIENT_ADDRESS%/*}",
  "presharedKey": "$PRESHARED_KEY",
  "dns": "$DNS",
  "provider": "oracle",
  "country": "CHANGE_ME",
  "city": "CHANGE_ME",
  "isActive": true,
  "load": 0
}
JSONBLOCK
echo ""
echo "============================================"
echo "  🔥 ORACLE CLOUD CONSOLE — FIREWALL"
echo "============================================"
echo ""
echo "  1. Networking → Virtual Cloud Networks → Your VCN"
echo "  2. Security Lists → Default Security List"
echo "  3. Add Ingress Rule:"
echo "     Source CIDR:      0.0.0.0/0"
echo "     IP Protocol:      UDP"
echo "     Destination Port:  $WG_PORT"
echo ""
echo "  ⚠️  Without this rule, VPN won't connect!"
echo ""
echo "============================================"
echo "  🧪 VERIFY"
echo "============================================"
echo "  sudo wg show"
echo "  curl https://ifconfig.me   (should show $PUBLIC_IP)"
echo ""
