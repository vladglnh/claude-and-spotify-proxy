# server/

VPS-side setup. Start here before touching anything in `claude/` or `spotify/`.

## What lives here

| Path | Purpose |
|---|---|
| `caddy/install.sh` | Builds Caddy with required plugins, creates system user, installs systemd unit |
| `caddy/ufw-setup.sh` | Sets UFW rules (22, 80, 443 open; everything else denied) |
| `caddy/Caddyfile` | Base Caddy config — TLS only, no proxy routes yet |
| `caddy/.env.example` | Template for `/etc/caddy/.env` — copy and fill in on the server |

## First-boot checklist

```
# 1. Firewall (as root)
bash server/caddy/ufw-setup.sh

# 2. Build and install Caddy (as root)
bash server/caddy/install.sh

# 3. Drop env file on the server
cp server/caddy/.env.example /etc/caddy/.env
$EDITOR /etc/caddy/.env          # set DOMAIN and ACME_EMAIL

# 4. Drop Caddyfile on the server
cp server/caddy/Caddyfile /etc/caddy/Caddyfile

# 5. (Optional) Uncomment acme_ca in Caddyfile to use Let's Encrypt staging
#    while you verify DNS and port 80 are working — staging has no rate limits.
#    Browser will show NET::ERR_CERT_AUTHORITY_INVALID; that is expected.
$EDITOR /etc/caddy/Caddyfile

# 6. Start
systemctl start caddy
journalctl -u caddy -f           # watch for TLS cert issuance

# 7. Smoke test
curl https://$DOMAIN/health      # should return "ok"

# 8. If you used staging: comment acme_ca back out, clear cert cache, restart
#    to obtain a real certificate from prod Let's Encrypt.
# $EDITOR /etc/caddy/Caddyfile
# rm -rf /var/lib/caddy/.local/share/caddy/certificates/
# systemctl restart caddy
```

## After base setup

Once `curl https://$DOMAIN/health` returns `ok`, the TLS layer is working.
Continue with `claude/server/` to add the HTTP CONNECT proxy route.
