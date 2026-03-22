# server/

VPS-side setup. Start here before touching anything in `claude/` or `spotify/`.

## What lives here

| Path | Purpose |
|---|---|
| `caddy/install.sh` | Installs Caddy from the official apt repository, creates config dirs |
| `caddy/ufw-setup.sh` | Sets UFW rules (22, 80, 443 open; everything else denied) |
| `caddy/Caddyfile` | Base Caddy config — TLS termination and `/health` only |
| `caddy/.env.example` | Template for `/etc/caddy/.env` — copy and fill in on the server |
| `gost/install.sh` | Downloads gost v3, installs systemd service (`gost-claude`) |
| `gost/.env.example` | Template for `/etc/gost/.env` — proxy credentials |

## First-boot checklist

```
# 1. Firewall (as root)
bash server/caddy/ufw-setup.sh

# 2. Install Caddy (as root)
bash server/caddy/install.sh

# 3. Drop Caddy env file on the server
cp server/caddy/.env.example /etc/caddy/.env
$EDITOR /etc/caddy/.env          # set DOMAIN and ACME_EMAIL

# 4. Drop Caddyfile on the server
cp server/caddy/Caddyfile /etc/caddy/Caddyfile

# 5. (Optional) Uncomment acme_ca in Caddyfile to use Let's Encrypt staging
#    while you verify DNS and port 80 are working — staging has no rate limits.
$EDITOR /etc/caddy/Caddyfile

# 6. Start Caddy
systemctl start caddy
journalctl -u caddy -f           # watch for TLS cert issuance

# 7. Smoke test
curl https://$DOMAIN/health      # should return "ok"

# 8. If you used staging: comment acme_ca back out, clear cert cache, restart
# $EDITOR /etc/caddy/Caddyfile
# rm -rf /var/lib/caddy/.local/share/caddy/certificates/
# systemctl restart caddy

# 9. Install gost (as root)
bash server/gost/install.sh

# 10. Set gost credentials
$EDITOR /etc/gost/.env           # set GOST_USER and GOST_PASS

# 11. Start gost
systemctl start gost-claude
journalctl -u gost-claude -f     # confirm it started cleanly
```

## After base setup

Once `curl https://$DOMAIN/health` returns `ok` and `gost-claude` is running,
continue with `claude/server/` to wire Caddy to gost and add the proxy route.
