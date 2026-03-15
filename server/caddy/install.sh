#!/usr/bin/env bash
# install.sh — build and install Caddy with required plugins on Ubuntu
# Run as root or via sudo.
set -euo pipefail

CADDY_BIN=/usr/local/bin/caddy
CADDY_DIR=/etc/caddy
CADDY_DATA=/var/lib/caddy
CADDY_LOG=/var/log/caddy
CADDY_USER=caddy

# ---------- 1. Go (required by xcaddy) ----------
GO_VERSION=1.22.4
if ! command -v go &>/dev/null; then
    echo ">>> Installing Go ${GO_VERSION}..."
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -o /tmp/go.tar.gz
    rm -rf /usr/local/go
    tar -C /usr/local -xzf /tmp/go.tar.gz
    rm /tmp/go.tar.gz
    export PATH=$PATH:/usr/local/go/bin
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile.d/go.sh
else
    echo ">>> Go already installed: $(go version)"
fi
export PATH=$PATH:/usr/local/go/bin

# ---------- 2. xcaddy ----------
if ! command -v xcaddy &>/dev/null; then
    echo ">>> Installing xcaddy..."
    GOPATH=/root/go go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
    cp /root/go/bin/xcaddy /usr/local/bin/xcaddy
fi

# ---------- 3. Build Caddy with plugins ----------
echo ">>> Building Caddy with plugins..."
GOPATH=/root/go xcaddy build \
    --with github.com/caddyserver/forwardproxy@caddy2 \
    --output /tmp/caddy-custom

install -m 0755 /tmp/caddy-custom "${CADDY_BIN}"
rm /tmp/caddy-custom

echo ">>> Caddy version: $("${CADDY_BIN}" version)"

# ---------- 4. System user ----------
if ! id "${CADDY_USER}" &>/dev/null; then
    useradd --system --home "${CADDY_DATA}" --shell /usr/sbin/nologin "${CADDY_USER}"
fi

# ---------- 5. Directories ----------
mkdir -p "${CADDY_DIR}" "${CADDY_DATA}" "${CADDY_LOG}"
chown -R "${CADDY_USER}:${CADDY_USER}" "${CADDY_DATA}" "${CADDY_LOG}"

# ---------- 6. Capability: bind ports < 1024 without root ----------
setcap cap_net_bind_service=+ep "${CADDY_BIN}"

# ---------- 7. systemd unit ----------
cat > /etc/systemd/system/caddy.service <<'EOF'
[Unit]
Description=Caddy web server
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=caddy
Group=caddy
ExecStart=/usr/local/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/local/bin/caddy reload --config /etc/caddy/Caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE
EnvironmentFile=-/etc/caddy/.env

[Install]
WantedBy=multi-user.target
EOF

systemd-analyze verify /etc/systemd/system/caddy.service 2>/dev/null || true
systemctl daemon-reload
systemctl enable caddy

echo ""
echo ">>> Done. Next steps:"
echo "    1. Copy .env.example to /etc/caddy/.env and fill in values"
echo "    2. Copy Caddyfile to /etc/caddy/Caddyfile"
echo "    3. systemctl start caddy"
echo "    4. journalctl -u caddy -f   # watch logs"
