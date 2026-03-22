# claude/server/

Добавляет `/probe` эндпоинт в Caddy и настраивает gost для HTTP CONNECT прокси.

**Предусловие:** `server/` настроен полностью — Caddy запущен, `curl https://$DOMAIN/health` возвращает `ok`, gost установлен.

## Что здесь есть

| Файл | Назначение |
|---|---|
| `Caddyfile.snippet` | Блок `/probe` для вставки в `/etc/caddy/Caddyfile` |
| `.env.example` | Переменные с логином и паролем — добавить в `/etc/gost/.env` |

## Архитектура

```
Клиент ──HTTPS CONNECT──► VPS:8443 (gost, TLS + auth) ──► api.anthropic.com
                              ↑
                    TLS-сертификат от Caddy

VPS:443 (Caddy) — только /health и /probe, не участвует в CONNECT
```

Caddy's `reverse_proxy` не умеет релеить raw TCP после `200 Connection Established`,
поэтому gost слушает напрямую на порту 8443, используя TLS-сертификат выданный Caddy.

## Инструкция

### 1. Найти путь к сертификатам Caddy

```bash
ls /var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/
# Должна быть папка с именем домена, например: your.domain.example/
```

### 2. Заполнить /etc/gost/.env

```bash
# Все четыре переменные обязательны:
GOST_USER=claude-user
GOST_PASS=your-strong-password
GOST_CERT=/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/your.domain.example/your.domain.example.crt
GOST_KEY=/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/your.domain.example/your.domain.example.key
```

### 3. Убедиться, что порт 8443 открыт

```bash
ufw status | grep 8443
# Если нет — открыть:
ufw allow 8443/tcp comment "gost Claude proxy"
```

### 4. Запустить gost

```bash
systemctl start gost-claude
journalctl -u gost-claude -f    # убедись, что нет ошибок с сертификатами
```

### 5. Вставить /probe в Caddyfile

Открой `/etc/caddy/Caddyfile` и вставь содержимое `Caddyfile.snippet`
внутрь блока `{$DOMAIN} { … }`, **перед строкой `respond 404`**:

```
{$DOMAIN} {
    tls {$ACME_EMAIL}

    respond /health "ok" 200

    # ← сюда вставить блок handle /probe из Caddyfile.snippet

    respond 404
}
```

Перезагрузить Caddy:

```bash
set -a && source /etc/caddy/.env && set +a
caddy validate --config /etc/caddy/Caddyfile
systemctl reload caddy
```

### 6. Smoke-тест

```bash
# /probe — исходящая сеть через Caddy к Anthropic (без gost)
# Ожидаем 401 от Anthropic
curl https://$DOMAIN/probe

# HTTP CONNECT через gost на порту 8443
# Ожидаем 401 от Anthropic (прокси туннелирует трафик корректно)
source /etc/gost/.env
curl -v -x "https://${GOST_USER}:${GOST_PASS}@${DOMAIN}:8443" \
     https://api.anthropic.com/v1/models \
     -H "anthropic-version: 2023-06-01"
```

401 — ожидаемый результат.

### Обновление сертификата

Caddy обновляет сертификат автоматически каждые ~60 дней. gost читает файл при старте и не перечитывает его в рантайме. После обновления сертификата нужно перезапустить gost:

```bash
systemctl restart gost-claude
```

Для автоматизации можно добавить месячный cron или systemd-таймер.

Если всё ок — переходи к `claude/client-mac/` или `claude/client-ubuntu/`.
