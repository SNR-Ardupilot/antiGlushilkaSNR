# Docker Deployment Guide

Полное руководство по развертыванию VLESS VPN с помощью Docker.

## 🎯 Преимущества Docker деплоя

- ✅ **Изоляция** - каждый сервис в отдельном контейнере
- ✅ **Безопасность** - минимальные привилегии, read-only файловые системы
- ✅ **Простота** - один скрипт для полного развертывания
- ✅ **Портативность** - работает на любой ОС с Docker
- ✅ **Мониторинг** - встроенные health checks
- ✅ **Масштабируемость** - легко добавлять новые сервисы

## 📋 Требования

- VPS с Ubuntu 20.04+ / Debian 11+ / CentOS 8+
- Минимум 1GB RAM (рекомендуется 2GB)
- 10GB свободного места
- Root доступ
- Открытый порт 443

## 🚀 Быстрый старт

### Шаг 1: Клонирование репозитория

```bash
ssh root@your_server_ip

git clone https://github.com/yourusername/yandex-vless-vpn.git
cd yandex-vless-vpn
```

### Шаг 2: Запуск автоматического деплоя

```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

Скрипт автоматически:
1. Установит Docker и Docker Compose (если не установлены)
2. Сгенерирует Reality ключи
3. Создаст конфигурации
4. Соберет Docker образы
5. Запустит сервисы

### Шаг 3: Проверка

```bash
# Проверка статуса
docker-compose ps

# Просмотр логов
docker-compose logs -f

# Мониторинг
./scripts/monitor.sh
```

## 🏗️ Архитектура

```
┌─────────────────────────────────────────┐
│          Internet (Port 443)            │
└────────────────┬────────────────────────┘
                 │
         ┌───────▼────────┐
         │   Xray Server  │ ◄── VLESS + Reality
         │   (Container)  │     Маскировка под Yandex
         └───────┬────────┘
                 │
         ┌───────▼────────┐
         │  Shared Volume │ ◄── users.json, configs
         │    (/data)     │
         └───────┬────────┘
                 │
         ┌───────▼────────┐
         │ Telegram Bot   │ ◄── TypeScript Bot
         │  (Container)   │     Выдача конфигов
         └────────────────┘
```

## 🔒 Безопасность

### Встроенные меры безопасности

1. **Непривилегированные пользователи**
   - Контейнеры запускаются от пользователей `xray` и `bot`
   - Нет root доступа внутри контейнеров

2. **Read-only файловые системы**
   - Основная FS доступна только на чтение
   - Запись только в `/tmp` (tmpfs в памяти)

3. **Минимальные capabilities**
   ```yaml
   cap_drop:
     - ALL
   cap_add:
     - NET_BIND_SERVICE  # Только для Xray
   ```

4. **Network isolation**
   - Изолированная сеть `vpn-network`
   - Контейнеры не имеют прямого доступа к хосту

5. **Secrets management**
   - Все секреты в `.env` файле с правами 600
   - Не коммитятся в Git

### Рекомендации

```bash
# Ограничение ресурсов в docker-compose.yml
services:
  xray:
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
```

## 📊 Мониторинг

### Просмотр статуса

```bash
# Статус контейнеров
docker-compose ps

# Health check статус
docker inspect --format='{{.State.Health.Status}}' vless-xray
docker inspect --format='{{.State.Health.Status}}' vless-bot

# Использование ресурсов
docker stats vless-xray vless-bot
```

### Логи

```bash
# Все логи
docker-compose logs -f

# Только Xray
docker-compose logs -f xray

# Только Bot
docker-compose logs -f telegram-bot

# Последние 100 строк
docker-compose logs --tail=100

# Логи с метками времени
docker-compose logs -f --timestamps
```

### Автоматический мониторинг

```bash
# Запуск скрипта мониторинга
./scripts/monitor.sh

# Настройка cron для регулярных проверок
crontab -e

# Добавьте строку (каждые 5 минут):
*/5 * * * * /path/to/yandex-vless-vpn/scripts/monitor.sh >> /var/log/vless-monitor.log 2>&1
```

## 🔧 Управление

### Основные команды

```bash
# Запуск
docker-compose up -d

# Остановка
docker-compose down

# Перезапуск
docker-compose restart

# Перезапуск конкретного сервиса
docker-compose restart xray
docker-compose restart telegram-bot

# Пересборка образов
docker-compose build --no-cache

# Обновление и перезапуск
docker-compose pull
docker-compose up -d
```

### Обновление конфигурации

```bash
# 1. Отредактируйте конфигурацию
vim server/config.json

# 2. Перезапустите Xray
docker-compose restart xray

# 3. Проверьте логи
docker-compose logs -f xray
```

### Бэкап

```bash
# Создание бэкапа
mkdir -p ~/backups
docker-compose exec xray cat /etc/xray/config.json > ~/backups/config.json
docker run --rm -v yandex-vless-vpn_shared-data:/data -v ~/backups:/backup alpine tar czf /backup/data.tar.gz -C /data .

# Восстановление
docker run --rm -v yandex-vless-vpn_shared-data:/data -v ~/backups:/backup alpine tar xzf /backup/data.tar.gz -C /data
```

## 🐛 Troubleshooting

### Проблема: Контейнер не запускается

```bash
# Проверьте логи
docker-compose logs xray
docker-compose logs telegram-bot

# Проверьте health статус
docker inspect vless-xray
docker inspect vless-bot

# Пересоздайте контейнеры
docker-compose down
docker-compose up -d --force-recreate
```

### Проблема: Порт 443 занят

```bash
# Найдите процесс
sudo lsof -i :443

# Или
sudo netstat -tulpn | grep :443

# Остановите конфликтующий сервис
sudo systemctl stop nginx  # Пример
```

### Проблема: Ошибка health check

```bash
# Проверьте внутренние процессы
docker exec vless-xray ps aux
docker exec vless-bot ps aux

# Запустите команду health check вручную
docker exec vless-xray sh -c "ps aux | grep xray | grep -v grep"
```

### Проблема: Нет подключения к VPN

```bash
# 1. Проверьте firewall
sudo ufw status
sudo ufw allow 443/tcp

# 2. Проверьте что Xray слушает порт
docker exec vless-xray netstat -tulpn | grep 443

# 3. Проверьте логи на ошибки
docker-compose logs xray | grep -i error
```

## 📈 Производительность

### Оптимизация для production

1. **Ограничение логов**
```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

2. **Автоматический перезапуск**
```yaml
restart: unless-stopped
```

3. **Использование tmpfs для /tmp**
```yaml
tmpfs:
  - /tmp
  - /run
```

### Мониторинг производительности

```bash
# CPU и Memory usage
docker stats --no-stream

# Disk I/O
docker stats --format "table {{.Container}}\t{{.BlockIO}}"

# Network I/O
docker stats --format "table {{.Container}}\t{{.NetIO}}"
```

## 🔄 CI/CD Integration

### GitHub Actions Example

```yaml
name: Deploy VPN

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Deploy to VPS
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.VPS_HOST }}
          username: root
          key: ${{ secrets.SSH_KEY }}
          script: |
            cd /opt/yandex-vless-vpn
            git pull
            docker-compose build
            docker-compose up -d
```

## 📝 Переменные окружения

| Переменная | Описание | Обязательная |
|-----------|----------|--------------|
| `TELEGRAM_BOT_TOKEN` | Токен Telegram бота | Да |
| `ADMIN_IDS` | ID администраторов | Да |
| `DEBUG` | Режим отладки | Нет |
| `SERVER_IP` | IP сервера | Автоматически |
| `PUBLIC_KEY` | Reality public key | Автоматически |
| `PRIVATE_KEY` | Reality private key | Автоматически |

## 🎓 Best Practices

1. **Всегда используйте .env для секретов**
2. **Регулярно делайте бэкапы**
3. **Мониторьте логи на ошибки**
4. **Обновляйте образы регулярно**
5. **Используйте конкретные версии образов** (не `latest`)
6. **Настройте автоматические обновления безопасности**
7. **Используйте Docker secrets в production**

## 📚 Дополнительные ресурсы

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Xray Documentation](https://xtls.github.io/)

## 🆘 Поддержка

При возникновении проблем:
1. Проверьте логи: `docker-compose logs`
2. Проверьте health статус: `./scripts/monitor.sh`
3. Создайте issue в репозитории с логами

---

**Важно**: Этот проект создан в образовательных целях. Используйте ответственно и в соответствии с законодательством.
