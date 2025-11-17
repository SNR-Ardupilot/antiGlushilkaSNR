#!/bin/sh
set -e

# Инициализация config.json если не существует (shared с xray)
if [ ! -f /data/config.json ]; then
  echo "[INFO] Создание начального config.json в /data/ (будет использоваться Xray)"
  cat > /data/config.json <<'EOF'
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "tag": "vless-reality",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "yandex.ru:443",
          "xver": 0,
          "serverNames": [
            "yandex.ru",
            "www.yandex.ru",
            "ya.ru",
            "passport.yandex.ru",
            "mail.yandex.ru",
            "disk.yandex.ru",
            "music.yandex.ru",
            "market.yandex.ru"
          ],
          "privateKey": "PLACEHOLDER_PRIVATE_KEY",
          "shortIds": [
            "",
            "0123456789abcdef",
            "2d8c6b"
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct",
      "settings": {
        "domainStrategy": "UseIPv4"
      }
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "block"
      },
      {
        "type": "field",
        "protocol": [
          "bittorrent"
        ],
        "outboundTag": "block"
      }
    ],
    "domainStrategy": "AsIs"
  }
}
EOF
  # Замена PLACEHOLDER на реальный приватный ключ
  if [ -n "$PRIVATE_KEY" ]; then
    sed -i "s/PLACEHOLDER_PRIVATE_KEY/$PRIVATE_KEY/g" /data/config.json
    echo "[INFO] Приватный ключ установлен в config.json"
  fi
fi

# Инициализация users.json если не существует
if [ ! -f /data/users.json ]; then
  echo "[INFO] Создание начальной базы users.json"
  echo '{"users":[]}' > /data/users.json
fi

# Инициализация server_info.txt если не существует
if [ ! -f /data/server_info.txt ]; then
  echo "[INFO] Создание server_info.txt"
  cat > /data/server_info.txt <<EOF
Server IP: ${SERVER_IP:-127.0.0.1}
Public Key: ${PUBLIC_KEY:-test_public_key}
Private Key: ${PRIVATE_KEY:-test_private_key}
Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF
fi

echo "[INFO] Запуск Telegram бота..."
exec node dist/bot.js
