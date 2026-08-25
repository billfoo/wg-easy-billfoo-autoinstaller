# 🛡️ WG-Easy Secure Auto-Installer (with Caddy & Client Isolation)

![Ubuntu](https://img.shields.io/badge/Ubuntu-26-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![WireGuard](https://img.shields.io/badge/WireGuard-Fast-881798?style=for-the-badge&logo=wireguard&logoColor=white)
![Security](https://img.shields.io/badge/Security-Hardened-success?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)

A bulletproof, one-click deployment script to install **WG-Easy** (WireGuard + Web GUI) on Ubuntu 26. This script doesn't just install the VPN; it hardens the server, hides the Admin UI behind a **Caddy Reverse Proxy** (with automatic Let's Encrypt SSL), and enforces strict **Client-to-Client Isolation**.

---

## ✨ Features

*   🚀 **One-Click Deployment:** Install Docker, configure the firewall, and spin up the containers in under 2 minutes.
*   🔒 **Caddy Reverse Proxy:** The WG-Easy Web UI is completely hidden from the public internet and safely routed through HTTPS (`https://vpn.yourdomain.com`).
*   🛡️ **Client-to-Client Isolation:** Built-in `iptables REJECT` rules ensure a Zero-Trust environment. VPN clients can access the internet and the server, but cannot see or ping each other.
*   🔑 **Bulletproof Bcrypt Hashing:** Automatically safely extracts and escapes the 60-character bcrypt password hash for the `docker-compose.yml`, preventing common syntax crash errors.
*   🛠️ **Kernel Module Fix:** Automatically mounts `/lib/modules` as read-only to prevent WireGuard `iptables` crashes on minimal Ubuntu VPS images.
*   🧱 **UFW Firewall Configuration:** Locks down the server to only allow SSH (22), HTTP/HTTPS (80/443), and the WireGuard UDP port (51820).

---

## 📋 Prerequisites

Before running the script, ensure you have the following:

1.  **Fresh Ubuntu 26 Server:** Logged in as a user with `sudo` privileges (or `root`).
2.  **A Registered Domain:** You need a subdomain (e.g., `vpn.example.com`).
3.  **DNS A-Record:** Point the subdomain to the public IP address of your Ubuntu server.

---

## 🚀 Quick Start (The One-Liner)

You can run the entire installation directly from GitHub using `curl`. 
Replace `vpn.yourdomain.com` and `YourSecurePassword` with your actual details.

> ⚠️ **Note:** Do not use special characters like `$` or `!` in the password via the command line to prevent bash expansion issues. Stick to alphanumeric characters.

```bash
curl -sSL [https://raw.githubusercontent.com/billfoo/wg-easy-billfoo-autoinstaller/main/install.sh](https://raw.githubusercontent.com/billfoo/wg-easy-billfoo-autoinstaller/main/install.sh) | sudo bash -s -- vpn.yourdomain.com YourSecurePassword
```

### 🐢 Alternative: Manual Download & Execute

If you prefer to review the script before running it:

```bash
# 1. Download the script
wget -O install.sh [https://raw.githubusercontent.com/billfoo/wg-easy-billfoo-autoinstaller/main/install.sh](https://raw.githubusercontent.com/billfoo/wg-easy-billfoo-autoinstaller/main/install.sh)

# 2. Make it executable
chmod +x install.sh

# 3. Run it
sudo ./install.sh vpn.yourdomain.com YourSecurePassword
```

---

## 🏗️ Under the Hood: What does the script do?

When you execute the script, it performs the following steps sequentially:

1.  **Updates the System:** Runs `apt update && apt upgrade`.
2.  **Enables IP Forwarding:** Writes the required routing rules into `/etc/sysctl.d/99-wireguard.conf` and reloads the kernel parameters.
3.  **Hardens the Firewall (UFW):** Blocks all incoming traffic by default and opens only ports `22`, `80`, `443`, and `51820/udp`.
4.  **Installs Docker:** Checks for Docker and installs it via the official setup script if missing.
5.  **Generates the Hash:** Pulls the WG-Easy image to generate a secure `bcrypt` hash of your password using a precise RegEx filter.
6.  **Creates Configurations:** Generates a highly customized `docker-compose.yml` and a `Caddyfile` in `/opt/wg-easy`.
7.  **Spins up the Stack:** Runs `docker compose up -d` and sets up the internal Docker network.

---

## 🔒 Security Architecture

By default, WG-Easy exposes port `51821` for the Web UI and allows connected VPN clients to communicate with each other. This setup changes that to an enterprise-grade architecture:

| Component | Improvement | Result |
| :--- | :--- | :--- |
| **Web UI** | Removed external port mapping. | The UI is only accessible via the internal `caddy_net` Docker network. |
| **SSL/TLS** | Proxied through Caddy. | Automatic, auto-renewing Let's Encrypt certificates. |
| **Network** | `WG_POST_UP` / `WG_POST_DOWN` | Applies `iptables` rules inside the container to drop client-to-client packets. |

---

## ❓ Troubleshooting

### ❌ Error 502 (Bad Gateway) when visiting the domain
This means Caddy is working and has secured the SSL certificate, but WG-Easy is crashing.
**Fix:** Check the container logs with `sudo docker logs wg-easy`. It is usually caused by an invalid password hash (e.g., if you used unescaped special characters in the terminal). 

### ❌ Clients have no internet access
Ensure that your VPS provider hasn't blocked IP forwarding on a hypervisor level. If you are on a Cloud provider (like AWS, Hetzner, or AWS), make sure to open UDP Port `51820` in their external web-based firewall as well.

---

## 📜 License

This project is open-source and available under the MIT License. Feel free to fork, modify, and use it for your own infrastructure setups.
