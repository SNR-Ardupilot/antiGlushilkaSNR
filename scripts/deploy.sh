#!/bin/bash

# Скрипт безопасного деплоя VLESS VPN через Docker

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   VLESS + Reality VPN Secure Deploy      ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
echo ""

# Проверка root прав
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ Этот скрипт должен быть запущен с правами root${NC}"
   exit 1
fi

# Проверка Docker
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}📦 Установка Docker...${NC}"
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
fi

# Проверка Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo -e "${YELLOW}📦 Установка Docker Compose...${NC}"
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# Переход в директорию проекта
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

echo -e "${BLUE}📂 Рабочая директория: $PROJECT_DIR${NC}"
echo ""

# Проверка существования .env
if [ ! -f .env ]; then
    echo -e "${YELLOW}⚙️  Настройка переменных окружения...${NC}"

    # Получение IP сервера
    SERVER_IP=$(curl -s ifconfig.me)
    echo -e "${GREEN}🌐 IP сервера: $SERVER_IP${NC}"

    # Генерация Reality ключей
    echo -e "${YELLOW}🔑 Генерация Reality ключей...${NC}"

    # Временный контейнер для генерации ключей
    docker run --rm alpine:3.19 sh -c "
        apk add --no-cache curl unzip > /dev/null 2>&1 && \
        curl -sL https://github.com/XTLS/Xray-core/releases/download/v1.8.7/Xray-linux-64.zip -o /tmp/xray.zip && \
        unzip -q /tmp/xray.zip -d /tmp && \
        /tmp/xray x25519
    " > /tmp/reality_keys.txt

    PRIVATE_KEY=$(grep "Private key:" /tmp/reality_keys.txt | awk '{print $3}')
    PUBLIC_KEY=$(grep "Public key:" /tmp/reality_keys.txt | awk '{print $3}')

    rm -f /tmp/reality_keys.txt

    echo -e "${GREEN}✅ Private Key: $PRIVATE_KEY${NC}"
    echo -e "${GREEN}✅ Public Key: $PUBLIC_KEY${NC}"

    # Запрос Telegram данных
    echo ""
    read -p "Введите Telegram Bot Token: " BOT_TOKEN
    read -p "Введите Telegram ID администраторов (через запятую): " ADMIN_IDS

    # Создание .env файла
    cat > .env <<EOF
# Telegram Bot Configuration
TELEGRAM_BOT_TOKEN=$BOT_TOKEN
ADMIN_IDS=$ADMIN_IDS

# Debug mode
DEBUG=false

# Server Configuration
SERVER_IP=$SERVER_IP
PUBLIC_KEY=$PUBLIC_KEY
PRIVATE_KEY=$PRIVATE_KEY
EOF

    chmod 600 .env
    echo -e "${GREEN}✅ Файл .env создан и защищен${NC}"
else
    echo -e "${GREEN}✅ Файл .env уже существует${NC}"
    source .env
fi

# Обновление конфигурации сервера
echo -e "${YELLOW}📝 Обновление конфигурации Xray...${NC}"

cat > server/config.json <<EOF
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

chmod 644 server/config.json

# Настройка firewall
echo -e "${YELLOW}🔒 Настройка firewall...${NC}"
if command -v ufw &> /dev/null; then
    ufw allow 443/tcp
    ufw allow 22/tcp
    echo "y" | ufw enable || true
fi

# Остановка старых контейнеров
echo -e "${YELLOW}🛑 Остановка старых контейнеров...${NC}"
docker-compose down 2>/dev/null || true

# Сборка образов
echo -e "${YELLOW}🏗️  Сборка Docker образов...${NC}"
docker-compose build --no-cache

# Запуск сервисов
echo -e "${YELLOW}🚀 Запуск сервисов...${NC}"
docker-compose up -d

# Ожидание запуска
echo -e "${YELLOW}⏳ Ожидание запуска сервисов...${NC}"
sleep 10

# Проверка статуса
echo ""
echo -e "${BLUE}📊 Статус сервисов:${NC}"
docker-compose ps

echo ""
if docker-compose ps | grep -q "Up"; then
    echo -e "${GREEN}✅ Деплой завершен успешно!${NC}"
else
    echo -e "${RED}❌ Ошибка запуска сервисов${NC}"
    echo -e "${YELLOW}Проверьте логи: docker-compose logs${NC}"
    exit 1
fi

# Вывод информации
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Информация о развертывании        ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}🌐 IP сервера:${NC} $SERVER_IP"
echo -e "${BLUE}🔑 Public Key:${NC} $PUBLIC_KEY"
echo -e "${BLUE}🔐 Private Key:${NC} $PRIVATE_KEY"
echo ""
echo -e "${YELLOW}📱 Telegram бот запущен и готов к работе${NC}"
echo ""
echo -e "${BLUE}Полезные команды:${NC}"
echo -e "  ${GREEN}docker-compose ps${NC}        - Статус сервисов"
echo -e "  ${GREEN}docker-compose logs -f${NC}   - Просмотр логов"
echo -e "  ${GREEN}docker-compose restart${NC}   - Перезапуск"
echo -e "  ${GREEN}docker-compose down${NC}      - Остановка"
echo ""
echo -e "${BLUE}Мониторинг:${NC}"
echo -e "  ${GREEN}./scripts/monitor.sh${NC}     - Статус и метрики"
echo ""
