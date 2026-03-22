# Debug spec: Caddy + forward_proxy

## Что должен делать Caddy (базово)

- Слушать на порту 443, терминировать TLS (сертификат Let's Encrypt)
- Отвечать `ok` на `GET /health`
- Передавать CONNECT-запросы в forward_proxy

## Что должен делать forward_proxy

- Принимать HTTP CONNECT запросы от аутентифицированных клиентов
- Для неаутентифицированных запросов → `407 Proxy Authentication Required`
- Для аутентифицированных → установить TCP-туннель к целевому хосту и порту из CONNECT
- После установки туннеля — прозрачно пересылать байты в обе стороны без вмешательства в содержимое

## Критерии проверки

### Проверка 1 — туннель работает
```
curl -v -x https://USER:PASS@PROXY_DOMAIN \
     https://api.anthropic.com/v1/models \
     -H "anthropic-version: 2023-06-01"
```
Ожидаемый результат: `401` от `api.anthropic.com` (не ошибка соединения).
Это означает: CONNECT принят, TCP-туннель до `api.anthropic.com:443` установлен, TLS до Anthropic прошёл, Anthropic вернул свой HTTP-ответ через туннель.

### Проверка 2 — аутентификация работает
```
curl -v -x https://PROXY_DOMAIN \
     https://api.anthropic.com/v1/models
```
Ожидаемый результат: `407` от прокси (без пароля — отказ).

### Проверка 3 — туннель прозрачен
В процессе работы туннеля `tcpdump -i any -n "host api.anthropic.com"` на сервере должен показывать трафик — то есть прокси физически устанавливает TCP-соединение к `api.anthropic.com:443`.

## Обратить внимание

- **`order forward_proxy before respond`** в глобальном блоке: проверить, что `forward_proxy` и `respond` — корректные имена директив для данной версии Caddy и плагина, и что такой `order` вообще имеет смысл
- **`basic_auth` внутри `forward_proxy`** в `Caddyfile.snippet`: проверить, что это правильный синтаксис для используемого плагина (у разных форков синтаксис может отличаться)
- **Генерация пароля** в `claude/server/README.md`: проверить, что `caddy hash-password --plaintext '...'` генерирует хеш в формате, который плагин умеет верифицировать

## Подтверждено тестами (2026-03-22)

- **Сеть ОК**: с сервера `curl https://api.anthropic.com/v1/models` возвращает `401` от Anthropic
- **TLS + reverse_proxy ОК**: `GET https://DOMAIN/probe` через клиент возвращает `401` от Anthropic — Caddy достигает api.anthropic.com, полный путь туда и обратно работает
- **Рабочий конфиг зафиксирован**: `server/caddy/Caddyfile.debug`

## Известные симптомы текущей проблемы

- CONNECT возвращает `200 OK` (даже без forward_proxy в конфиге — скорее всего Caddy сам обрабатывает CONNECT)
- После `200` туннель не работает: прокси возвращает HTTP-текст (`HTTP/...`) вместо TLS ServerHello от Anthropic
- `tcpdump` не показывает трафик к `api.anthropic.com` — соединение к бэкенду не устанавливается
- В debug-логах Caddy виден только TLS handshake, HTTP-запросы не логируются
