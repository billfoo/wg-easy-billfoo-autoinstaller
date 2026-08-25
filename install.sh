#!/bin/bash
# ==============================================================================
# WG-Easy + Caddy Secure Auto-Installer for Ubuntu 26
# Version 7 - Ultimate Autonomous Edition (NAT Fix + Healthcheck + Autoheal)
# ==============================================================================
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: Please run this script as root (sudo $0 ...)${NC}"
  exit 1
fi

if [ "$#" -ne 2 ]; then
    echo -e "${BLUE}Usage:${NC} sudo $0 <VPN_HOST_DOMAIN> <ADMIN_PASSWORD>"
    exit 1
fi

DOMAIN=$1
PASSWORD=$2
INSTALL_DIR="/opt/wg-easy"

echo -e "${GREEN}[1/7] Updating system...${NC}"
apt update && apt install -y curl ufw sed grep

echo -e "${GREEN}[2/7] Enabling IP forwarding...${NC}"
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-wireguard.conf
echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.d/99-wireguard.conf
sysctl -p /etc/sysctl.d/99-wireguard.conf

echo -e "${GREEN}[3/7] Configuring firewall...${NC}"
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 51820/udp
ufw --force enable

echo -e "${GREEN}[4/7] Checking Docker...${NC}"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
fi

echo -e "${GREEN}[5/7] Generating Bcrypt hash...${NC}"
docker pull ghcr.io/wg-easy/wg-easy:latest
RAW_HASH=$(docker run --rm ghcr.io/wg-easy/wg-easy wgpw "$PASSWORD")

CLEAN_HASH=$(echo -e "$RAW_HASH" | grep -oE '\$2[abxy]\$[0-9]{2}\$[./A-Za-z0-9]{53}')

if [ -z "$CLEAN_HASH" ]; then
    echo -e "${RED}Error: Could not generate a valid hash!${NC}"
    exit 1
fi

ESCAPED_HASH=$(echo "$CLEAN_HASH" | sed 's/\$/\$\$/g')

echo -e "${GREEN}[6/7] Creating configuration...${NC}"
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

cat <<'EOF' > docker-compose.yml
services:
  wg-easy:
    image: ghcr.io/wg-easy/wg-easy
    container_name: wg-easy
    environment:
      - LANG=en
      - WG_HOST=__DOMAIN__
      - PASSWORD_HASH=__HASH__
      - PORT=51821
      - WG_PORT=51820
      # Maximum Security: Client-to-Client Isolation + Active NAT Routing
      - WG_POST_UP=iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE; iptables -I FORWARD -i wg0 -o wg0 -j REJECT
      - WG_POST_DOWN=iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE; iptables -D FORWARD -i wg0 -o wg0 -j REJECT
    volumes:
      - ./wireguard:/etc/wireguard
      - /lib/modules:/lib/modules:ro
    ports:
      - "51820:51820/udp"
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wg", "show", "wg0"]
      interval: 30s
      timeout: 10s
      retries: 3
    labels:
      - "autoheal=true"
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.src_valid_mark=1
    networks:
      - caddy_net

  caddy:
    image: caddy:alpine
    container_name: caddy-proxy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./caddy_data:/data
      - ./caddy_config:/config
    networks:
      - caddy_net
    depends_on:
      - wg-easy

  autoheal:
    image: willfarrell/autoheal
    container_name: autoheal
    restart: unless-stopped
    environment:
      - AUTOHEAL_CONTAINER_LABEL=autoheal
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock

networks:
  caddy_net:
    name: wg_caddy_network
EOF

sed -i "s|__DOMAIN__|$DOMAIN|g" docker-compose.yml
sed -i "s|__HASH__|$ESCAPED_HASH|g" docker-compose.yml

cat <<EOF > Caddyfile
$DOMAIN {
    reverse_proxy wg-easy:51821
}
EOF

echo -e "${GREEN}[7/7] Starting...${NC}"
docker compose up -d
echo -e "${GREEN}✓ DONE! Web-UI is available at https://$DOMAIN${NC}"
