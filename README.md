# 🛡️ WG-Easy Billfoo Auto-Installer

![Ubuntu](https://img.shields.io/badge/Ubuntu-26-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![WireGuard](https://img.shields.io/badge/WireGuard-Fast-881798?style=for-the-badge&logo=wireguard&logoColor=white)
![Security](https://img.shields.io/badge/Security-Hardened-success?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)

A bulletproof, highly automated, and interactive deployment script to install **WG-Easy** (WireGuard + Web GUI) proxied by **Caddy** on Ubuntu. 

This setup goes far beyond a standard installation. It is designed for administrators who require maximum security, zero-maintenance operations, and a strict Zero-Trust environment. It fully automates SSL certificates, enforces Client-to-Client Isolation, hardens the server firewall, and implements a Self-Healing Docker Architecture.

---

## 📋 What You Need Before Starting

Before you run the script, ensure you have the following information and prerequisites ready:

1.  **A Fresh Ubuntu Server:** You must be logged in as `root`. The script explicitly requires and enforces root privileges to modify kernel routing and firewall rules.
2.  **Server IP Address:** The public IPv4 address of your server.
3.  **A Registered Domain Name:** You need at least one domain or subdomain (e.g., `vpn.yourdomain.com`). 
4.  **Configured DNS Records:** You must create an **A-Record** in your domain registrar's DNS settings pointing your chosen domain to your server's public IP address.
5.  **Cloudflare Users (Crucial):** If you manage your DNS via Cloudflare, the A-Record for your Web-UI must be set to **"DNS Only" (Grey Cloud)**. If it is proxied (Orange Cloud), Cloudflare masks your real IP, breaking the script's internal Zero-Trust IP whitelisting.
6.  **Cloud Provider Firewall:** If you are hosted on IONOS, AWS, Azure, or Hetzner, you must log into their web console and explicitly allow incoming **UDP traffic on Port 51820**.

---

## 🚀 Installation & Updates (One-Click)

To initially deploy the server, reconfigure settings, or apply updates, **always use this exact same command**. It safely handles the download (using `wget` as a fallback) and launches the interactive wizard:

```bash
sh <(curl -sSL https://raw.githubusercontent.com/billfoo/wg-easy-billfoo-autoinstaller/main/install.sh || wget -O - https://raw.githubusercontent.com/billfoo/wg-easy-billfoo-autoinstaller/main/install.sh)
```

### The Configuration Wizard
The script utilizes a smart state-machine to guide you through the setup. You can type `b` and press Enter at any time to go back to a previous question.
1.  **VPN Host:** Enter the main domain (or IP) your WireGuard clients will connect to.
2.  **Web-UI Domain:** You can use the exact same domain for the Web-UI, or specify a separate one (e.g., `admin.yourdomain.com`).
3.  **Admin Password:** Set a strong password for the Web-UI. 
4.  **Access Control:** Choose whether the web panel should be publicly accessible from anywhere, or strictly limited to the internal VPN network (Zero-Trust).

---

## 🔄 Re-Running the Script (Smart Auto-Import)

This script is designed to be completely idempotent and upgrade-safe. If you need to change your domain, update your password, or switch your Web-UI from "Public" to "VPN-Only", simply run the installation command again.

**What happens when you execute the script on an existing setup?**
1.  **Detection:** The script checks if `/opt/wg-easy/docker-compose.yml` exists. If it does, it enters "Update Mode".
2.  **Configuration Extraction:** It silently reads your existing `docker-compose.yml` and `Caddyfile`. It extracts your current VPN Host, UI Host, and the complex bcrypt password hash.
3.  **Default Overrides:** During the interactive wizard, your current settings are displayed in brackets `[...]`. If you just press `Enter`, the script keeps your existing configuration.
4.  **Password Retention:** You do not need to re-enter your password. You can leave the password prompt empty to automatically retain your existing securely hashed password.
5.  **Seamless Application:** After finishing the wizard, the script regenerates the configuration files and executes `docker compose up -d` followed by `docker compose restart caddy`. Docker only recreates the containers that actually changed. Your VPN clients, QR codes, and keys (stored in the persistent `/opt/wg-easy/wireguard` volume) remain untouched and will never be deleted.

---

## ⚙️ What the Script Exactly Does (Under the Hood)

When you execute the script, it performs the following system-level operations autonomously:

1.  **Dependency Resolution:** Updates the `apt` package index and installs necessary utilities (`curl`, `ufw`, `sed`, `grep`).
2.  **Kernel IP Forwarding:** Creates `/etc/sysctl.d/99-wireguard.conf` and injects `net.ipv4.ip_forward=1` and `net.ipv6.conf.all.forwarding=1`. It reloads `sysctl` to allow the Linux kernel to route network traffic (acting as a router for your VPN clients).
3.  **UFW Firewall Automation:** Resets the Uncomplicated Firewall (UFW) to a strict *Default Deny* policy for incoming traffic. It exclusively opens port `22/tcp` (SSH), `80/tcp` & `443/tcp` (Caddy/HTTPS), and `51820/udp` (WireGuard), then forcibly enables the firewall.
4.  **Docker Provisioning:** Checks for the Docker daemon. If missing, it fetches and executes the official Docker convenience installation script.
5.  **Native Bcrypt Hashing:** Pulls the WG-Easy image and utilizes its internal `wgpw` tool to generate a secure bcrypt hash of your chosen password. It uses `sed` to escape `$` characters to `$$` to prevent Docker Compose variable expansion errors.
6.  **Stack Generation:** Creates the `/opt/wg-easy` directory and writes a custom `docker-compose.yml` orchestrating WG-Easy, Caddy, and Autoheal.
7.  **Dynamic Proxy Rules:** Generates the `Caddyfile`. If "VPN-Only" was selected, it calculates the Docker internal NAT ranges and injects them into the Caddy remote IP whitelist.

---

## 🏗️ Architecture & Security Deep Dive

| Feature | Execution | Security Benefit |
| :--- | :--- | :--- |
| **Invisible Caddy Proxy** | Caddy handles Let's Encrypt challenges internally. If "VPN-Only" is chosen, external IPs trying to load the UI receive a hard `abort` connection drop. | No login page is loaded, and no HTTP error codes are thrown to external IPs, making the server invisible to bot scanners. |
| **Docker NAT Resolution** | The script whitelists `172.16.0.0/12` in Caddy. This is necessary because traffic from the WG container to Caddy is NAT-masqueraded by the Docker Bridge. | Prevents administrators from locking themselves out of the VPN-only UI due to Docker's internal routing. |
| **Client Isolation** | Injects `iptables -I FORWARD -i wg0 -o wg0 -j REJECT` during the tunnel boot via `WG_POST_UP`. | Absolute Client-to-Client isolation. Connected clients have internet access but cannot ping or scan each other. |
| **Self-Healing** | The `wg0` interface is probed every 30s. If it fails 3 times, the container is gracefully restarted. | Zero-maintenance operations for hanging kernel modules. |

---

## ❓ Frequently Asked Questions (FAQ) & Troubleshooting

**Q: I connected to the VPN, but I have no internet access (0 Bytes received).**
**A:** This is almost always a firewall issue outside of the server itself. Ensure that your hosting provider's cloud panel (IONOS, AWS, Hetzner, etc.) explicitly allows incoming **UDP traffic on port 51820**. WireGuard does not use TCP.

**Q: I selected "VPN-Only" access, but I get `ERR_HTTP2_PROTOCOL_ERROR` when trying to reach the UI.**
**A:** This means Caddy is actively blocking you. Ensure your WireGuard tunnel is currently active on your device. Also, ensure your Web-UI domain is not proxied through Cloudflare (Orange Cloud), as Cloudflare replaces your VPN IP with their own server IPs, causing Caddy to reject the connection.

**Q: The Web-UI shows a 502 Bad Gateway error.**
**A:** This usually happens immediately after installation while Caddy is fetching the SSL certificate from Let's Encrypt. Wait 30 seconds and refresh. If it persists, check the container logs: `sudo docker logs wg-easy` and `sudo docker logs caddy-proxy`.

**Q: The Android App shows "Unknown Section" when scanning the QR code.**
**A:** Ensure your desktop browser isn't automatically translating the WG-Easy Web-UI (e.g., translating `[Interface]` to another language). The UI must remain in English for the QR code to contain valid WireGuard syntax.

**Q: Can I change my domain or password later?**
**A:** Yes. Simply run the installation command again. The script will detect your setup, import your current settings, and allow you to override anything. Your VPN clients will not be deleted.

**Q: How do I completely uninstall and remove everything?**
**A:** To completely wipe the installation, run these commands:
```bash
cd /opt/wg-easy && sudo docker compose down -v
sudo rm -rf /opt/wg-easy
```
*(Warning: This deletes all client profiles and keys permanently!)*

---

## 💾 Backup Strategy

All critical data (client configurations, cryptographic keypairs, and QR codes) are stored inside the persistent volume at `/opt/wg-easy/wireguard`. 

To back up your VPN infrastructure, simply copy this directory to a secure location. If your server crashes or you migrate to a new machine, restore this folder to the exact same path, run the installation script again, and all clients will instantly reconnect without needing to update their local WireGuard profiles.

---

## 📜 License

This project is open-source and available under the MIT License. Feel free to fork, modify, and use it for your own infrastructure setups.
