# claude/server/

Добавляет HTTP CONNECT прокси для Claude в уже работающий Caddy.

**Предусловие:** `server/caddy/` настроен, `curl https://$DOMAIN/health` возвращает `ok`.

## Что здесь есть

| Файл | Назначение |
|---|---|
| `Caddyfile.snippet` | Блок `forward_proxy`, который нужно вставить в `/etc/caddy/Caddyfile` |
| `.env.example` | Переменные с логином и хешем пароля — добавить в `/etc/caddy/.env` |

## Инструкция

### 1. Сгенерировать хеш пароля

На сервере:

```bash
caddy hash-password --plaintext 'придумай-пароль'
```

Скопируй вывод — он понадобится на следующем шаге.

### 2. Дополнить /etc/caddy/.env

```bash
# Добавь в /etc/caddy/.env (образец в .env.example):
CLAUDE_PROXY_USER=имя-пользователя
CLAUDE_PROXY_PASS_HASH='<вывод команды выше>'   # одинарные кавычки обязательны — хеш содержит $
```

### 3. Вставить фрагмент в Caddyfile

Открой `/etc/caddy/Caddyfile` и вставь содержимое `Caddyfile.snippet`
внутрь блока `{$DOMAIN} { … }`, **перед строкой `respond 404`**:

```
{$DOMAIN} {
    tls {$ACME_EMAIL}

    respond /health "ok" 200

    # ← сюда вставить блоки basic_auth и forward_proxy из Caddyfile.snippet

    respond 404
}
```

После правки файл должен выглядеть как в `Caddyfile.snippet`.

### 4. Проверить конфиг и перезагрузить

```bash
set -a && source /etc/caddy/.env && set +a
caddy validate --config /etc/caddy/Caddyfile
systemctl reload caddy
journalctl -u caddy -f          # убедись, что нет ошибок
```

### 5. Smoke-тест с сервера

```bash
# Должен вернуть 401 от api.anthropic.com (не ошибку соединения) — значит туннель работает
curl -v -x https://$CLAUDE_PROXY_USER:$PLAIN_PASS@$DOMAIN \
     https://api.anthropic.com/v1/models \
     -H "anthropic-version: 2023-06-01"
```

401 — ожидаемый результат: запрос дошёл до Anthropic, прокси туннелирует трафик корректно.

Если всё ок — переходи к `claude/client-mac/` или `claude/client-ubuntu/`.
