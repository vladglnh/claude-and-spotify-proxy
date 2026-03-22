# Почему не Caddy forwardproxy — и что вместо него

## Проблема

Оригинальный план: Caddy с плагином `caddyserver/forwardproxy` обрабатывает HTTP CONNECT-туннели для Claude и SOCKS5 для Spotify.

Плагин не работает с Caddy v2.8+. Симптомы:
- CONNECT возвращает `200 OK` — плагин принимает запрос
- Туннель не устанавливается — `tcpdump` не показывает исходящих соединений к бэкенду
- После `200` клиент получает HTTP-байты вместо TLS ServerHello от Anthropic → `SSL wrong version number`

**Корневая причина:** Caddy v2.8 изменил внутреннюю обёртку `ResponseWriter`. Плагин пытается захватить соединение через `http.Hijacker` (чтобы перейти в raw TCP-режим после `200`), но интерфейс недоступен через новую обёртку. Плагин отправляет `200`, не получает управление соединением, Caddy продолжает обрабатывать его как HTTP.

Проверено:
- `caddyserver/forwardproxy@caddy2` (февраль 2024) — не работает
- `caddyserver/forwardproxy@master` (март 2026) — не работает
- `klzgrad/forwardproxy@master` (январь 2025) — не работает

## Решение: Caddy + gost

**Caddy остаётся** — только для того, в чём он надёжен:
- TLS-сертификаты Let's Encrypt (автообновление)
- Health endpoint (`/health`)
- Опционально: debug/probe эндпоинты

**gost берёт на себя proxy-слой:**
- HTTP CONNECT over TLS → для Claude (клиент подключается через gost)
- SOCKS5 → для Spotify (Firefox или gost на клиенте)
- Поддерживает несколько listeners одновременно
- Активно поддерживается, работает с современными Go-версиями

## Предлагаемая архитектура

```
Клиент
  └── gost (localhost) ──HTTPS CONNECT──► VPS:443 (gost, TLS от Caddy)
  └── Firefox (SOCKS5) ──────────────────► VPS:1080 (gost, plain или TLS)

VPS
  ├── Caddy :443 — TLS termination, /health, Let's Encrypt
  │     └── reverse_proxy → gost :8443 (HTTP CONNECT handler)
  └── gost :1080 — SOCKS5 для Spotify
```

Либо проще — gost слушает напрямую на нестандартном порту, используя сертификаты выданные Caddy (из `/var/lib/caddy/...`).

## Что нужно переписать

- `server/caddy/Caddyfile` — убрать `order forward_proxy`, добавить проброс или оставить как есть
- `claude/server/` — заменить инструкции по forwardproxy на инструкции по gost
- `spotify/server/` — написать с нуля под gost SOCKS5
- `claude.md` — обновить описание стека (Server proxy: gost вместо Caddy для proxy-слоя)
