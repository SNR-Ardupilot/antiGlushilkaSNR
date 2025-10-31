#!/bin/bash

# Скрипт установки Telegram бота

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Установка Telegram бота ===${NC}"

# Проверка root прав
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Этот скрипт должен быть запущен с правами root${NC}"
   exit 1
fi

# Установка Python и pip
echo -e "${YELLOW}Установка Python зависимостей...${NC}"
apt update
apt install -y python3 python3-pip python3-venv

# Создание директории для бота
BOT_DIR="/opt/vless-bot"
mkdir -p $BOT_DIR

# Копирование файлов бота
echo -e "${YELLOW}Копирование файлов бота...${NC}"
cp -r ../bot/* $BOT_DIR/

# Создание виртуального окружения
echo -e "${YELLOW}Создание виртуального окружения...${NC}"
cd $BOT_DIR
python3 -m venv venv
source venv/bin/activate

# Установка зависимостей
pip install --upgrade pip
pip install -r requirements.txt

# Создание файла конфигурации
echo -e "${YELLOW}Настройка конфигурации...${NC}"

# Запрос токена бота
read -p "Введите токен Telegram бота: " BOT_TOKEN
read -p "Введите Telegram ID администраторов (через запятую): " ADMIN_IDS

# Создание .env файла
cat > $BOT_DIR/.env <<EOF
TELEGRAM_BOT_TOKEN=$BOT_TOKEN
ADMIN_IDS=$ADMIN_IDS
EOF

# Создание systemd сервиса
echo -e "${YELLOW}Создание systemd сервиса...${NC}"
cat > /etc/systemd/system/vless-bot.service <<EOF
[Unit]
Description=VLESS Telegram Bot
After=network.target xray.service

[Service]
Type=simple
User=root
WorkingDirectory=$BOT_DIR
Environment="PATH=$BOT_DIR/venv/bin"
EnvironmentFile=$BOT_DIR/.env
ExecStart=$BOT_DIR/venv/bin/python3 $BOT_DIR/telegram_bot.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Создание скрипта запуска
cat > $BOT_DIR/start.sh <<'EOF'
#!/bin/bash
cd /opt/vless-bot
source venv/bin/activate
source .env
python3 telegram_bot.py
EOF

chmod +x $BOT_DIR/start.sh

# Включение и запуск сервиса
echo -e "${YELLOW}Запуск бота...${NC}"
systemctl daemon-reload
systemctl enable vless-bot
systemctl start vless-bot

echo -e "${GREEN}=== Установка завершена! ===${NC}"
echo -e "${GREEN}Бот запущен и работает${NC}"
echo -e "${YELLOW}Проверка статуса: systemctl status vless-bot${NC}"
echo -e "${YELLOW}Просмотр логов: journalctl -u vless-bot -f${NC}"
