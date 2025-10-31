#!/bin/bash

# Скрипт автоматической установки VLESS + Reality сервера
# Для использования на Ubuntu/Debian VPS

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Установка VLESS + Reality VPN сервера ===${NC}"

# Проверка root прав
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Этот скрипт должен быть запущен с правами root${NC}"
   exit 1
fi

# Обновление системы
echo -e "${YELLOW}Обновление системы...${NC}"
apt update && apt upgrade -y
apt install -y curl wget unzip uuid-runtime jq

# Установка Xray-core
echo -e "${YELLOW}Установка Xray-core...${NC}"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# Создание директорий
mkdir -p /var/log/xray
mkdir -p /usr/local/etc/xray

# Генерация ключей Reality
echo -e "${YELLOW}Генерация ключей Reality...${NC}"
KEYS=$(/usr/local/bin/xray x25519)
PRIVATE_KEY=$(echo "$KEYS" | grep "Private key:" | awk '{print $3}')
PUBLIC_KEY=$(echo "$KEYS" | grep "Public key:" | awk '{print $3}')

echo -e "${GREEN}Private Key: ${PRIVATE_KEY}${NC}"
echo -e "${GREEN}Public Key: ${PUBLIC_KEY}${NC}"

# Генерация UUID для первого пользователя
USER_UUID=$(uuidgen)
echo -e "${GREEN}User UUID: ${USER_UUID}${NC}"

# Создание конфигурации
cat > /usr/local/etc/xray/config.json <<EOF
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
        "clients": [
          {
            "id": "${USER_UUID}",
            "flow": "xtls-rprx-vision",
            "email": "user1@example.com"
          }
        ],
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
            "mail.yandex.ru"
          ],
          "privateKey": "${PRIVATE_KEY}",
          "shortIds": [
            "",
            "0123456789abcdef"
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
      }
    ],
    "domainStrategy": "AsIs"
  }
}
EOF

# Настройка firewall
echo -e "${YELLOW}Настройка firewall...${NC}"
ufw allow 443/tcp
ufw allow 22/tcp
echo "y" | ufw enable

# Запуск Xray
echo -e "${YELLOW}Запуск Xray сервиса...${NC}"
systemctl enable xray
systemctl restart xray

# Получение IP сервера
SERVER_IP=$(curl -s ifconfig.me)

# Сохранение информации о сервере
cat > /root/server_info.txt <<EOF
=== Информация о VLESS сервере ===
IP сервера: ${SERVER_IP}
Порт: 443
UUID: ${USER_UUID}
Public Key: ${PUBLIC_KEY}
Private Key: ${PRIVATE_KEY}
SNI: yandex.ru
Flow: xtls-rprx-vision

=== Ссылка для клиента ===
vless://${USER_UUID}@${SERVER_IP}:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=yandex.ru&fp=chrome&pbk=${PUBLIC_KEY}&sid=0123456789abcdef&type=tcp&headerType=none#Yandex-VPN
EOF

echo -e "${GREEN}=== Установка завершена! ===${NC}"
echo -e "${GREEN}Информация о сервере сохранена в /root/server_info.txt${NC}"
echo ""
cat /root/server_info.txt
