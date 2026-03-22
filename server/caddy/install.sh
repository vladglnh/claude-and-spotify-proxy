#!/usr/bin/env bash
# install.sh — install Caddy from the official apt repository on Ubuntu
# Run as root or via sudo.
set -euo pipefail

# ---------- 1. Caddy from official apt repo ----------
echo ">>> Installing Caddy from official apt repository..."
apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl

curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
    | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg

curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    | tee /etc/apt/sources.list.d/caddy-stable.list

apt-get update
apt-get install -y caddy

echo ">>> Caddy version: $(caddy version)"

# ---------- 2. Directories ----------
mkdir -p /etc/caddy /var/lib/caddy /var/log/caddy

# The apt package already creates the caddy system user and installs the systemd
# unit with EnvironmentFile=/etc/caddy/.env support. No further setup needed.

echo ""
echo ">>> Done. Next steps:"
echo "    1. Copy .env.example to /etc/caddy/.env and fill in values"
echo "    2. Copy Caddyfile to /etc/caddy/Caddyfile"
echo "    3. systemctl start caddy"
echo "    4. journalctl -u caddy -f   # watch logs"
