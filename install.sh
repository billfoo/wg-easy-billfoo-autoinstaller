
#!/bin/bash
# ==============================================================================
# WG-Easy + Caddy Secure Auto-Installer for Ubuntu 26
# Version 11 - Forced Validation & Force Reload Update
# ==============================================================================
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'
INSTALL_DIR="/opt/wg-easy"

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: Please run this script as root (sudo $0)${NC}"
  exit 1
fi

VPN_HOST=""
SAME_UI="y"
UI_HOST=""
ADMIN_PASS=""
VPN_ONLY="y"
EXISTING_HASH=""

# --- Auto-Import existing configuration ---
if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
    echo -e "${BLUE}Existing installation found at $INSTALL_DIR!${NC}"
    read -p "Do you want to reconfigure/update the current setup? [Y/n]: " RECONFIGURE
    if [[ "$RECONFIGURE" =~ ^[Nn] ]]; then
        echo -e "${GREEN}Exiting without changes.${NC}"
        exit 0
    fi
    echo -e "${GREEN}Importing existing configuration...${NC}"
    
    OLD_VPN=$(grep "WG_HOST=" "$INSTALL_DIR/docker-compose.yml" | cut -d'=' -f2 | tr -d ' "\r')
    if [ -n "$OLD_VPN" ]; then VPN_HOST="$OLD_VPN"; fi
    
    EXISTING_HASH=$(grep "PASSWORD_HASH=" "$INSTALL_DIR/docker-compose.yml" | cut -d'=' -f2- | tr -d ' "\r')
    
    if [ -f "$INSTALL_DIR/Caddyfile" ]; then
        OLD_UI=$(head -n 1 "$INSTALL_DIR/Caddyfile" | awk '{print $1}')
        if [ -n "$OLD_UI" ]; then 
            UI_HOST="$OLD_UI"
            if [ "$UI_HOST" == "$VPN_HOST" ]; then SAME_UI="y"; else SAME_UI="n"; fi
        fi
        
        if grep -q "10.8.0.0/24" "$INSTALL_DIR/Caddyfile"; then 
            VPN_ONLY="y"
        else 
            VPN_ONLY="n"
        fi
    fi
fi

echo "------------------------------------------------------"
echo -e "${BLUE}--- WG-Easy Configuration Wizard ---${NC}"
echo "Tip: Press [Enter] to keep the value in the brackets."
echo "     Type 'b' and press [Enter] to go back a step."
echo "------------------------------------------------------"

STEP=1
while [ $STEP -le 6 ]; do
    case $STEP in
        1)
            read -p "1. Enter VPN host (Domain or IP) [$VPN_HOST]: " INPUT
            if [ "$INPUT" == "b" ]; then echo "Already at the first step."; continue; fi
            VPN_HOST=${INPUT:-$VPN_HOST}
            if [ -z "$VPN_HOST" ]; then echo -e "${RED}VPN host cannot be empty!${NC}"; continue; fi
            STEP=2
            ;;
        2)
            read -p "2. Is the Web-UI surface identical to the VPN host? (y/n) [$SAME_UI]: " INPUT
            if [ "$INPUT" == "b" ]; then STEP=1; continue; fi
            SAME_UI=${INPUT:-$SAME_UI}
            if [[ "$SAME_UI" =~ ^[Nn] ]]; then
                STEP=3
            else
                UI_HOST=$VPN_HOST
                STEP=4
            fi
            ;;
        3)
            read -p "   Enter the separate domain for the Web-UI [$UI_HOST]: " INPUT
            if [ "$INPUT" == "b" ]; then STEP=2; continue; fi
            UI_HOST=${INPUT:-$UI_HOST}
            if [ -z "$UI_HOST" ]; then echo -e "${RED}Web-UI domain cannot be empty!${NC}"; continue; fi
            STEP=4
            ;;
        4)
            if [ -n "$EXISTING_HASH" ]; then
                read -s -p "4. Enter NEW password for the Web-UI (Leave empty to keep current): " INPUT
            else
                read -s -p "4. Enter password for the Web-UI: " INPUT
            fi
            echo ""
            
            if [ "$INPUT" == "b" ]; then
                if [[ "$SAME_UI" =~ ^[Nn] ]]; then STEP=3; else STEP=2; fi
                continue
            fi
            
            if [ -z "$INPUT" ] && [ -n "$EXISTING_HASH" ]; then
                ADMIN_PASS="(kept existing)"
                ESCAPED_HASH="$EXISTING_HASH"
            else
                ADMIN_PASS=${INPUT:-$ADMIN_PASS}
                if [ -z "$ADMIN_PASS" ]; then 
                    echo -e "${RED}Password cannot be empty!${NC}"; continue; 
                fi
            fi
            STEP=5
            ;;
        5)
            read -p "5. Should the Web-UI be accessible ONLY within the VPN network? (y/n) [$VPN_ONLY]: " INPUT
            if [ "$INPUT" == "b" ]; then STEP=4; continue; fi
            VPN_ONLY=${INPUT:-$VPN_ONLY}
            if [[ "$VPN_ONLY" =~ ^[Nn] ]]; then
                ACCESS_TYPE="Public (Accessible from anywhere)"
                VPN_ONLY_FLAG=false
            else
                ACCESS_TYPE="Private (VPN & Docker network only)"
                VPN_ONLY_FLAG=true
            fi
            STEP=6
            ;;
        6)
            echo -e "\n${BLUE}--- Summary ---${NC}"
            echo -e "VPN Host:        ${GREEN}$VPN_HOST${NC}"
            echo -e "Web-UI Domain:   ${GREEN}$UI_HOST${NC}"
            echo -e "Web-UI Access:   ${GREEN}$ACCESS_TYPE${NC}"
            
            if [ "$ADMIN_PASS" == "(kept existing)" ]; then
                echo -e "Admin Password:  ${GREEN}(kept existing password)${NC}"
            else
                echo -e "Admin Password:  ${GREEN}********${NC}"
            fi
            echo ""
            
            # Zwingende Validierung (Pflichtfeld)
            while true; do
                read -p "Are these settings correct? (y=Yes, n=Restart, b=Back, q=Quit): " CONFIRM
                if [[ "$CONFIRM" =~ ^[Yy] ]]; then
                    break 2 # Bricht diese Schleife UND die aeussere Wizard-Schleife ab (geht zur Installation)
                elif [[ "$CONFIRM" == "b" ]]; then
                    STEP=5
                    break # Bricht nur diese Validierungs-Schleife ab und geht zu Schritt 5
                elif [[ "$CONFIRM" =~ ^[Nn] ]]; then
                    STEP=1
                    break # Geht komplett zurueck zu Schritt 1
                elif [[ "$CONFIRM" =~ ^[Qq] ]]; then
                    echo -e "${RED}Installation aborted by user.${NC}"
                    exit 0
                else
                    echo -e "${RED}Invalid input. Please explicitly choose y, n, b, or q.${NC}"
                fi
            done
            ;;
    esac
done

echo -e "\n${GREEN}[1/7] Updating system...${NC}"
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
if [ "$ADMIN_PASS" != "(kept existing)" ]; then
    docker pull ghcr.io/wg-easy/wg-easy:latest
    RAW_HASH=$(docker run --rm ghcr.io/wg-easy/wg-easy wgpw "$ADMIN_PASS")
    CLEAN_HASH=$(echo -e "$RAW_HASH" | grep -oE '\$2[abxy]\$[0-9]{2}\$[./A-Za-z0-9]{53}')
    if [ -z "$CLEAN_HASH" ]; then
        echo -e "${RED}Error: Could not generate a valid hash!${NC}"
        exit 1
    fi
    ESCAPED_HASH=$(echo "$CLEAN_HASH" | sed 's/\$/\$\$/g')
else
    echo "Keeping existing password hash."
fi

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
      - WG_HOST=__VPN_HOST__
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

sed -i "s|__VPN_HOST__|$VPN_HOST|g" docker-compose.yml
sed -i "s|__HASH__|$ESCAPED_HASH|g" docker-compose.yml

if [ "$VPN_ONLY_FLAG" = true ]; then
    cat <<EOF > Caddyfile
$UI_HOST {
    @allowed_ips remote_ip 10.8.0.0/24 172.16.0.0/12

    handle @allowed_ips {
        reverse_proxy wg-easy:51821
    }

    handle {
        abort
    }
}
EOF
else
    cat <<EOF > Caddyfile
$UI_HOST {
    reverse_proxy wg-easy:51821
}
EOF
fi

echo -e "${GREEN}[7/7] Starting...${NC}"
docker compose up -d

# Erzwungener Caddy-Neustart, damit Aenderungen am Caddyfile sofort greifen
docker compose restart caddy

echo -e "${GREEN}✓ DONE! Web-UI is available at https://$UI_HOST${NC}"
