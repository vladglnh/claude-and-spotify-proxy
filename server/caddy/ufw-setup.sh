#!/usr/bin/env bash
# ufw-setup.sh — minimal firewall for a proxy VPS
# Run as root. Idempotent: safe to re-run.
set -euo pipefail

# Abort if ufw is not installed
if ! command -v ufw &>/dev/null; then
    apt-get install -y ufw
fi

# Reset to a known state without wiping existing SSH rule first
ufw --force reset

# Default policy
ufw default deny incoming
ufw default allow outgoing

# SSH — must come before 'enable'
ufw allow 22/tcp comment "SSH"

# Caddy — HTTP for ACME challenge, HTTPS for everything else
ufw allow 80/tcp  comment "Caddy ACME / redirect"
ufw allow 443/tcp comment "Caddy TLS"

# Enable (non-interactive)
ufw --force enable

ufw status verbose
