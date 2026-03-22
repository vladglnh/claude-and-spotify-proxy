#!/usr/bin/env bash
# install.sh — install gost v3 and configure it as a systemd service
# Run as root or via sudo.
set -euo pipefail

GOST_VERSION=3.0.0
GOST_BIN=/usr/local/bin/gost
GOST_DIR=/etc/gost

# ---------- 1. Download gost binary ----------
ARCH=amd64
ARCHIVE="gost_${GOST_VERSION}_linux_${ARCH}.tar.gz"
URL="https://github.com/go-gost/gost/releases/download/v${GOST_VERSION}/${ARCHIVE}"

echo ">>> Downloading gost v${GOST_VERSION}..."
curl -fsSL "${URL}" -o /tmp/gost.tar.gz
tar -C /tmp -xzf /tmp/gost.tar.gz gost
install -m 0755 /tmp/gost "${GOST_BIN}"
rm /tmp/gost.tar.gz /tmp/gost

echo ">>> gost version: $("${GOST_BIN}" -V 2>&1 | head -1)"

# ---------- 2. Config directory ----------
mkdir -p "${GOST_DIR}"
chmod 750 "${GOST_DIR}"

# ---------- 3. .env template (only if not already present) ----------
if [ ! -f "${GOST_DIR}/.env" ]; then
    cp "$(dirname "$0")/.env.example" "${GOST_DIR}/.env"
    chmod 640 "${GOST_DIR}/.env"
    echo ">>> Created ${GOST_DIR}/.env — fill in GOST_USER and GOST_PASS before starting"
else
    echo ">>> ${GOST_DIR}/.env already exists, skipping"
fi

# ---------- 4. systemd unit ----------
cat > /etc/systemd/system/gost-claude.service <<'EOF'
[Unit]
Description=gost HTTP CONNECT proxy for Claude
After=network.target

[Service]
EnvironmentFile=/etc/gost/.env
ExecStart=/usr/local/bin/gost -L "http://${GOST_USER}:${GOST_PASS}@127.0.0.1:8443"
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable gost-claude

echo ""
echo ">>> Done. Next steps:"
echo "    1. Fill in /etc/gost/.env  (GOST_USER and GOST_PASS)"
echo "    2. systemctl start gost-claude"
echo "    3. journalctl -u gost-claude -f   # watch logs"
