# claude/server/

Подключает HTTP CONNECT прокси для Claude к уже работающему Caddy + gost.

**Предусловие:** `server/` настроен полностью — Caddy запущен, `curl https://$DOMAIN/health` возвращает `ok`, `gost-claude` запущен.

## Что здесь есть

| Файл | Назначение |
|---|---|
| `Caddyfile.snippet` | Блоки `/probe` и `reverse_proxy`, которые нужно вставить в `/etc/caddy/Caddyfile` |
| `.env.example` | Переменные с логином и паролем — уже должны быть в `/etc/gost/.env` |

## Архитектура

```
Клиент ──HTTPS CONNECT──► VPS:443 (Caddy, TLS) ──► localhost:8443 (gost, HTTP CONNECT + auth)
                                                  └► /health, /probe  (Caddy отвечает напрямую)
```

Caddy завершает TLS и пробрасывает всё через `reverse_proxy localhost:8443`.
gost обрабатывает HTTP CONNECT и проверяет Basic Auth (GOST_USER / GOST_PASS).

## Инструкция

### 1. Убедиться, что gost запущен с нужными учётными данными

```bash
cat /etc/gost/.env          # GOST_USER и GOST_PASS должны быть заполнены
systemctl status gost-claude
```

Если нужно изменить пароль — отредактируй `/etc/gost/.env` и перезапусти:

```bash
systemctl restart gost-claude
```

### 2. Вставить фрагмент в Caddyfile

Открой `/etc/caddy/Caddyfile` и замени содержимое блока `{$DOMAIN} { … }`
на то, что показано в `Caddyfile.snippet`:

```
{$DOMAIN} {
    tls {$ACME_EMAIL}

    respond /health "ok" 200

    # ← сюда вставить блоки handle /probe и reverse_proxy из Caddyfile.snippet

    respond 404   # эта строка станет недостижимой — можно убрать
}
```

### 3. Проверить конфиг и перезагрузить Caddy

```bash
set -a && source /etc/caddy/.env && set +a
caddy validate --config /etc/caddy/Caddyfile
systemctl reload caddy
journalctl -u caddy -f          # убедись, что нет ошибок
```

### 4. Smoke-тест с сервера

```bash
# Проверка /probe: исходящая сеть к Anthropic без прокси
# Ожидаем 401 от api.anthropic.com — значит сеть и TLS работают
curl https://$DOMAIN/probe

# Проверка HTTP CONNECT через gost
# Ожидаем 401 от api.anthropic.com — значит туннель работает
GOST_USER=... GOST_PASS=...
curl -v -x "http://${GOST_USER}:${GOST_PASS}@$DOMAIN:443" \
     https://api.anthropic.com/v1/models \
     -H "anthropic-version: 2023-06-01"
```

401 — ожидаемый результат: запрос дошёл до Anthropic, прокси туннелирует трафик корректно.

Если всё ок — переходи к `claude/client-mac/` или `claude/client-ubuntu/`.
