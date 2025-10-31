#!/bin/bash

# Скрипт для быстрого локального тестирования

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   VLESS VPN - Локальное тестирование     ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
echo ""

# Переход в директорию проекта
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# Проверка Docker
echo -e "${BLUE}🔍 Проверка Docker...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker не установлен!${NC}"
    echo -e "${YELLOW}Установите Docker Desktop: https://www.docker.com/products/docker-desktop/${NC}"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo -e "${RED}❌ Docker не запущен!${NC}"
    echo -e "${YELLOW}Запустите Docker Desktop и попробуйте снова${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker установлен и запущен${NC}"

# Проверка docker-compose
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}❌ docker-compose не установлен!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ docker-compose доступен${NC}"
echo ""

# Генерация Reality ключей
echo -e "${BLUE}🔑 Генерация Reality ключей...${NC}"
KEYS_OUTPUT=$(docker run --rm alpine:3.19 sh -c '
  apk add --no-cache curl unzip > /dev/null 2>&1
  curl -sL https://github.com/XTLS/Xray-core/releases/download/v1.8.7/Xray-linux-64.zip -o /tmp/xray.zip
  unzip -q /tmp/xray.zip -d /tmp
  /tmp/xray x25519
' 2>/dev/null)

PRIVATE_KEY=$(echo "$KEYS_OUTPUT" | grep "Private key:" | awk '{print $3}')
PUBLIC_KEY=$(echo "$KEYS_OUTPUT" | grep "Public key:" | awk '{print $3}')

if [ -z "$PRIVATE_KEY" ] || [ -z "$PUBLIC_KEY" ]; then
    echo -e "${RED}❌ Ошибка генерации ключей${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Private Key: ${PRIVATE_KEY}${NC}"
echo -e "${GREEN}✅ Public Key: ${PUBLIC_KEY}${NC}"
echo ""

# Запрос данных Telegram бота
echo -e "${BLUE}📱 Настройка Telegram бота${NC}"
echo ""
echo -e "${YELLOW}Для получения Bot Token:${NC}"
echo -e "  1. Откройте @BotFather в Telegram"
echo -e "  2. Отправьте /newbot"
echo -e "  3. Следуйте инструкциям"
echo -e "  4. Скопируйте полученный токен"
echo ""
read -p "Введите Telegram Bot Token: " BOT_TOKEN

echo ""
echo -e "${YELLOW}Для получения вашего Telegram ID:${NC}"
echo -e "  1. Откройте @userinfobot в Telegram"
echo -e "  2. Отправьте /start"
echo -e "  3. Скопируйте ваш ID"
echo ""
read -p "Введите ваш Telegram ID: " ADMIN_ID

# Создание .env файла
echo ""
echo -e "${BLUE}📝 Создание .env файла...${NC}"
cat > .env <<EOF
# Telegram Bot Configuration
TELEGRAM_BOT_TOKEN=${BOT_TOKEN}
ADMIN_IDS=${ADMIN_ID}

# Debug mode
DEBUG=true

# Server Configuration
SERVER_IP=127.0.0.1
PUBLIC_KEY=${PUBLIC_KEY}
PRIVATE_KEY=${PRIVATE_KEY}
EOF

chmod 600 .env
echo -e "${GREEN}✅ .env файл создан${NC}"

# Обновление конфигурации сервера
echo -e "${BLUE}📝 Обновление server/config.json...${NC}"

# Для macOS нужен другой синтаксис sed
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|\"privateKey\": \"\"|\"privateKey\": \"${PRIVATE_KEY}\"|" server/config.json
else
    sed -i "s|\"privateKey\": \"\"|\"privateKey\": \"${PRIVATE_KEY}\"|" server/config.json
fi

echo -e "${GREEN}✅ Конфигурация обновлена${NC}"
echo ""

# Остановка старых контейнеров
echo -e "${BLUE}🛑 Остановка старых контейнеров...${NC}"
docker-compose down 2>/dev/null || true

# Сборка образов
echo -e "${BLUE}🏗️  Сборка Docker образов...${NC}"
echo -e "${YELLOW}Это может занять несколько минут при первом запуске...${NC}"
docker-compose build

# Запуск контейнеров
echo ""
echo -e "${BLUE}🚀 Запуск контейнеров...${NC}"
docker-compose up -d

# Ожидание запуска
echo -e "${YELLOW}⏳ Ожидание запуска сервисов (30 секунд)...${NC}"
sleep 30

# Проверка статуса
echo ""
echo -e "${BLUE}📊 Статус сервисов:${NC}"
docker-compose ps

echo ""

# Проверка health статуса
XRAY_HEALTH=$(docker inspect --format='{{.State.Health.Status}}' vless-xray 2>/dev/null || echo "N/A")
BOT_HEALTH=$(docker inspect --format='{{.State.Health.Status}}' vless-bot 2>/dev/null || echo "N/A")

echo -e "${BLUE}🏥 Health Check:${NC}"
if [ "$XRAY_HEALTH" = "healthy" ]; then
    echo -e "  Xray:  ${GREEN}✅ Healthy${NC}"
else
    echo -e "  Xray:  ${RED}❌ $XRAY_HEALTH${NC}"
fi

if [ "$BOT_HEALTH" = "healthy" ]; then
    echo -e "  Bot:   ${GREEN}✅ Healthy${NC}"
else
    echo -e "  Bot:   ${RED}❌ $BOT_HEALTH${NC}"
fi

echo ""

# Проверка успешности
if [ "$XRAY_HEALTH" = "healthy" ] && [ "$BOT_HEALTH" = "healthy" ]; then
    echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         ✅ Запуск успешен!                ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}📱 Следующие шаги:${NC}"
    echo -e "  1. Откройте Telegram"
    echo -e "  2. Найдите вашего бота"
    echo -e "  3. Отправьте команду: ${GREEN}/start${NC}"
    echo -e "  4. Нажмите кнопку '${GREEN}🔑 Получить конфигурацию${NC}'"
    echo ""
    echo -e "${BLUE}💡 Полезные команды:${NC}"
    echo -e "  ${GREEN}docker-compose logs -f${NC}          - Просмотр логов"
    echo -e "  ${GREEN}docker-compose ps${NC}               - Статус сервисов"
    echo -e "  ${GREEN}docker-compose restart${NC}          - Перезапуск"
    echo -e "  ${GREEN}docker-compose down${NC}             - Остановка"
    echo -e "  ${GREEN}./scripts/monitor.sh${NC}            - Мониторинг"
    echo ""
    echo -e "${YELLOW}🔍 Просмотр логов в реальном времени:${NC}"
    echo -e "  docker-compose logs -f"
    echo ""
else
    echo -e "${RED}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${RED}║         ❌ Ошибка запуска                 ║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Проверьте логи:${NC}"
    echo -e "  docker-compose logs xray"
    echo -e "  docker-compose logs telegram-bot"
    exit 1
fi
