# proxy-setup

Personal VPS proxy infrastructure for accessing Claude and Spotify through a corporate VPN environment.

## What this repo does

Sets up a self-hosted proxy server on a Ubuntu VPS using Caddy as the server-side proxy layer and gost as the client-side tunnel agent. Designed to work alongside an existing corporate OpenVPN without conflicts.

## Stack

| Layer | Tool | Role |
|---|---|---|
| Server proxy | Caddy | TLS termination, HTTP CONNECT proxy, SOCKS5 |
| Client tunnel | gost | Local proxy agent on macOS / Ubuntu client |
| Spotify access | Firefox profile | Browser with SOCKS5 pointed at VPS |

## Repo structure

```
/
├── CLAUDE.md               ← you are here
├── server/
│   ├── caddy/              ← Caddy config and setup on Ubuntu VPS
│   └── README.md
├── claude/
│   ├── server/             ← server-side Caddy config specific to Claude proxying
│   ├── client-mac/         ← gost setup + alias on macOS
│   ├── client-ubuntu/      ← gost setup + alias on Ubuntu
│   └── README.md
└── spotify/
    ├── server/             ← server-side Caddy/SOCKS5 config for Spotify
    ├── client-mac/         ← Firefox profile setup on macOS
    ├── client-ubuntu/      ← Firefox profile setup on Ubuntu
    └── README.md
```

## Setup order

The instructions in each folder are written to be self-contained, but the intended setup sequence is:

1. `server/caddy/` — base Caddy install and TLS on the VPS (do this first, everything else depends on it)
2. `claude/server/` — add Claude proxy route to Caddy
3. `claude/client-mac/` or `claude/client-ubuntu/` — set up gost on the client
4. `spotify/server/` — add SOCKS5 listener to Caddy config
5. `spotify/client-mac/` or `spotify/client-ubuntu/` — configure Firefox profile

## Design principles

**One Caddy instance on the server handles everything.** Claude and Spotify use different ports or virtual hosts on the same Caddy process. Adding a new service means adding a block to the Caddyfile, not spinning up a new process.

**gost on the client connects to Caddy over port 443.** Corporate firewalls rarely block 443. The connection looks like standard HTTPS to the VPN gateway — the destination domain (your VPS IP) is not in any blocklist.

**No conflict with corporate OpenVPN.** gost binds to localhost only. The VPN tunnel and the gost tunnel use different network interfaces and routing table entries. If the corporate VPN runs in full-tunnel mode, a static bypass route for your VPS IP is added before the VPN interface comes up — this is documented in each client guide.

**Auth is required.** The proxy is not open. Caddy enforces basic auth (or mutual TLS if you prefer) on all proxy endpoints. Credentials are stored locally in a `.env` file that is gitignored.

## What is NOT in this repo

- API keys or credentials of any kind
- VPS provider setup (DigitalOcean, Hetzner, etc.) — assumed to already exist
- Domain/DNS configuration — assumed to already point to the VPS

## Security notes

- Keep your VPS firewall tight: only ports 22, 80, 443 open externally
- Caddy auto-renews TLS via Let's Encrypt — requires a real domain pointed at the VPS
- Do not reuse proxy credentials across services
- The `.env` file with credentials is in `.gitignore` — never commit it

## Language

- Пиши инструкции преимущественно на русском языке
- Если инструкция написана на английском языке, продолжай писать её на английском языке