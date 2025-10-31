#!/bin/bash

# Скрипт установки Telegram бота (TypeScript версия)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Установка Telegram бота (TypeScript) ===${NC}"

# Проверка root прав
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Этот скрипт должен быть запущен с правами root${NC}"
   exit 1
fi

# Установка Node.js 20.x
echo -e "${YELLOW}Установка Node.js...${NC}"
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Проверка установки
node --version
npm --version

# Создание директории для бота
BOT_DIR="/opt/vless-bot"
mkdir -p $BOT_DIR

# Копирование файлов бота
echo -e "${YELLOW}Копирование файлов бота...${NC}"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cp -r "$PROJECT_DIR/bot/"* $BOT_DIR/

cd $BOT_DIR

# Установка зависимостей
echo -e "${YELLOW}Установка зависимостей...${NC}"
npm install

# Компиляция TypeScript
echo -e "${YELLOW}Компиляция TypeScript...${NC}"
npm run build

# Создание файла конфигурации
echo -e "${YELLOW}Настройка конфигурации...${NC}"

# Запрос токена бота
read -p "Введите токен Telegram бота: " BOT_TOKEN
read -p "Введите Telegram ID администраторов (через запятую): " ADMIN_IDS

# Создание .env файла
cat > $BOT_DIR/.env <<EOF
TELEGRAM_BOT_TOKEN=$BOT_TOKEN
ADMIN_IDS=$ADMIN_IDS
DEBUG=false
EOF

# Создание systemd сервиса
echo -e "${YELLOW}Создание systemd сервиса...${NC}"
cat > /etc/systemd/system/vless-bot.service <<EOF
[Unit]
Description=VLESS Telegram Bot (TypeScript)
After=network.target xray.service

[Service]
Type=simple
User=root
WorkingDirectory=$BOT_DIR
EnvironmentFile=$BOT_DIR/.env
ExecStart=/usr/bin/node $BOT_DIR/dist/bot.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Создание скрипта запуска для разработки
cat > $BOT_DIR/start-dev.sh <<'EOF'
#!/bin/bash
cd /opt/vless-bot
source .env
npm run dev
EOF

chmod +x $BOT_DIR/start-dev.sh

# Создание скрипта продакшн запуска
cat > $BOT_DIR/start.sh <<'EOF'
#!/bin/bash
cd /opt/vless-bot
source .env
npm start
EOF

chmod +x $BOT_DIR/start.sh

# Включение и запуск сервиса
echo -e "${YELLOW}Запуск бота...${NC}"
systemctl daemon-reload
systemctl enable vless-bot
systemctl start vless-bot

# Ожидание запуска
sleep 3

# Проверка статуса
if systemctl is-active --quiet vless-bot; then
    echo -e "${GREEN}=== Установка завершена успешно! ===${NC}"
    echo -e "${GREEN}Бот запущен и работает${NC}"
else
    echo -e "${RED}=== Ошибка запуска бота! ===${NC}"
    echo -e "${YELLOW}Проверьте логи: journalctl -u vless-bot -n 50${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}=== Полезные команды ===${NC}"
echo -e "${GREEN}Проверка статуса:${NC} systemctl status vless-bot"
echo -e "${GREEN}Просмотр логов:${NC} journalctl -u vless-bot -f"
echo -e "${GREEN}Перезапуск:${NC} systemctl restart vless-bot"
echo -e "${GREEN}Остановка:${NC} systemctl stop vless-bot"
echo -e "${GREEN}Режим разработки:${NC} cd /opt/vless-bot && npm run dev"
