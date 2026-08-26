# 🛡️ WG-Easy Secure Auto-Installer (Ultimate Autonomous Edition)

![Ubuntu](https://img.shields.io/badge/Ubuntu-26-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![WireGuard](https://img.shields.io/badge/WireGuard-Fast-881798?style=for-the-badge&logo=wireguard&logoColor=white)
![Security](https://img.shields.io/badge/Security-Hardened-success?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)

A bulletproof, zero-maintenance deployment script to install **WG-Easy** (WireGuard + Web GUI) on Ubuntu 26.XX. This script goes far beyond a standard installation: it hardens the server, proxies the Admin UI via **Caddy**, enforces **Client-to-Client Isolation**, and implements a **Self-Healing Docker Architecture**.

---

## ✨ Enterprise Features

*   🚀 **One-Click Deployment:** Installs Docker, configures IP forwarding, sets up UFW, and spins up the entire stack autonomously.
*   🔒 **Caddy Reverse Proxy:** The WG-Easy Web UI is hidden from the public internet and safely routed through HTTPS with automatic Let's Encrypt certificates.
*   🛡️ **Client Isolation & NAT Routing:** Custom `iptables` chains (`MASQUERADE` + `REJECT`) ensure a Zero-Trust environment. Clients can access the internet, but cannot see or ping each other.
*   🤖 **Autoheal & Healthchecks:** WG-Easy is actively monitored. If the WireGuard kernel interface (`wg0`) hangs or crashes, a dedicated `autoheal` container instantly restarts the service—resulting in zero manual maintenance.
*   🔑 **Bulletproof Bcrypt Hashing:** Uses precise RegEx to safely extract and escape the 60-character bcrypt password hash, preventing standard syntax crash errors.
*   🧱 **UFW Firewall Hardening:** Locks down the server to only allow SSH (22), HTTP/HTTPS (80/443), and the WireGuard UDP port (51820).

---

## 📋 Prerequisites

1.  **Fresh Ubuntu 26.XX Server:** Logged in as `root` or a user with `sudo` privileges.
2.  **A Registered Domain:** A subdomain (e.g., `vpn.example.com`) pointing via A-Record to your server's IP address.
3.  **Cloud Firewall (Optional):** If you are using a provider like IONOS, AWS, or Hetzner, ensure you open **UDP Port 51820** in their external web-based firewall panel.

---

## 🚀 Quick Start (The One-Liner)

You can deploy the entire infrastructure directly from GitHub. 
Replace `vpn.yourdomain.com` and `YourSecurePassword` with your actual details.

> ⚠️ **Note:** Do not use special characters like `$` or `!` in the password via the command line to prevent bash expansion issues. Stick to alphanumeric characters.

```bash
bash <(curl -sSL https://raw.githubusercontent.com/billfoo/wg-easy-billfoo-autoinstaller/main/install.sh || wget -qO - https://raw.githubusercontent.com/billfoo/wg-easy-billfoo-autoinstaller/main/install.sh)
```

### 🐢 Alternative: Manual Execution

If you prefer to review the code before running it:

```bash
# 1. Download the script
wget -O install.sh https://raw.githubusercontent.com/billfoo/wg-easy-billfoo-autoinstaller/main/install.sh

# 2. Make it executable
chmod +x install.sh

# 3. Run it
sudo ./install.sh vpn.yourdomain.com YourSecurePassword
```

---

## 🏗️ Architecture & Security

By default, WG-Easy exposes the Web UI port and allows connected VPN clients to communicate with each other. This setup hardens the environment:

| Component | Improvement | Result |
| :--- | :--- | :--- |
| **Web UI** | Internal network only. | The UI is only accessible via the internal `caddy_net` Docker network. |
| **Resilience** | Docker Healthchecks + Autoheal. | The `wg0` interface is probed every 30s. If it fails 3 times, the container is gracefully restarted. |
| **Network** | Advanced `WG_POST_UP` Rules. | Combines standard `MASQUERADE` for internet access with `REJECT` rules for internal client drops. |

---

## ❓ Troubleshooting

*   **Clients have no internet / 0 Bytes received:**
    Ensure your Cloud Provider (IONOS, Hetzner, AWS) allows incoming **UDP** traffic on port `51820`. If you use Cloudflare for your domain, ensure the DNS record is set to "DNS Only" (Grey Cloud), as the proxy blocks UDP traffic.
*   **Error 502 (Bad Gateway) on the Web UI:**
    This usually means the password hash generated an error. Check the container logs with `sudo docker logs wg-easy`.
*   **Android App shows "Unknown Section" on QR scan:**
    Ensure your PC browser is not automatically translating the WG-Easy Web UI (e.g., translating `[Interface]` to German). The UI must be in English to generate a valid QR code.

---

## 💾 Backup Strategy

All client configurations and QR codes are stored inside `/opt/wg-easy/wireguard`. To back up your VPN, simply back up this directory. If your server crashes, restore this folder, run `docker compose up -d`, and all clients will reconnect instantly without changing their local profiles.

---

## 📜 License

This project is open-source and available under the MIT License. Feel free to fork, modify, and use it for your own infrastructure setups.
