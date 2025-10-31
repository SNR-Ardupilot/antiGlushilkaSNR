#!/bin/bash

# Скрипт мониторинга Docker сервисов

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        VLESS VPN - Мониторинг             ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
echo ""

# Переход в директорию проекта
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# Проверка статуса контейнеров
echo -e "${BLUE}📦 Статус контейнеров:${NC}"
docker-compose ps
echo ""

# Проверка health статуса
echo -e "${BLUE}🏥 Health Check:${NC}"
XRAY_HEALTH=$(docker inspect --format='{{.State.Health.Status}}' vless-xray 2>/dev/null || echo "N/A")
BOT_HEALTH=$(docker inspect --format='{{.State.Health.Status}}' vless-bot 2>/dev/null || echo "N/A")

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

# Использование ресурсов
echo -e "${BLUE}💾 Использование ресурсов:${NC}"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" vless-xray vless-bot 2>/dev/null || echo "  Контейнеры не запущены"
echo ""

# Логи (последние 10 строк)
echo -e "${BLUE}📋 Последние логи Xray:${NC}"
docker logs --tail 10 vless-xray 2>&1 | tail -5
echo ""

echo -e "${BLUE}📋 Последние логи Bot:${NC}"
docker logs --tail 10 vless-bot 2>&1 | tail -5
echo ""

# Количество подключений
echo -e "${BLUE}🔗 Активные подключения:${NC}"
CONNECTIONS=$(docker exec vless-xray sh -c 'netstat -an 2>/dev/null | grep :443 | grep ESTABLISHED | wc -l' 2>/dev/null || echo "0")
echo -e "  Подключений к порту 443: ${GREEN}$CONNECTIONS${NC}"
echo ""

# Uptime контейнеров
echo -e "${BLUE}⏰ Uptime:${NC}"
XRAY_UPTIME=$(docker inspect --format='{{.State.StartedAt}}' vless-xray 2>/dev/null)
BOT_UPTIME=$(docker inspect --format='{{.State.StartedAt}}' vless-bot 2>/dev/null)

if [ -n "$XRAY_UPTIME" ]; then
    echo -e "  Xray: Запущен с $XRAY_UPTIME"
fi

if [ -n "$BOT_UPTIME" ]; then
    echo -e "  Bot:  Запущен с $BOT_UPTIME"
fi
echo ""

# Размер логов
echo -e "${BLUE}📁 Размер томов:${NC}"
docker volume ls -q | grep vless | while read vol; do
    SIZE=$(docker run --rm -v $vol:/data alpine du -sh /data 2>/dev/null | cut -f1)
    echo -e "  $vol: $SIZE"
done
echo ""

# Быстрые команды
echo -e "${YELLOW}💡 Быстрые команды:${NC}"
echo -e "  ${GREEN}docker-compose logs -f xray${NC}      - Логи Xray в реальном времени"
echo -e "  ${GREEN}docker-compose logs -f telegram-bot${NC}  - Логи бота в реальном времени"
echo -e "  ${GREEN}docker-compose restart${NC}            - Перезапуск всех сервисов"
echo -e "  ${GREEN}docker exec -it vless-xray sh${NC}    - Войти в контейнер Xray"
echo -e "  ${GREEN}docker exec -it vless-bot sh${NC}     - Войти в контейнер бота"
echo ""
