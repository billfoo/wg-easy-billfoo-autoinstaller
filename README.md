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
