# ⚡ Быстрый деплой - Шпаргалка

## 🚀 За 5 минут

### На вашем VPS сервере:

```bash
# 1. Подключитесь к серверу
ssh root@YOUR_SERVER_IP

# 2. Обновите систему
apt update && apt upgrade -y && apt install -y git

# 3. Клонируйте проект (если в GitHub)
git clone https://github.com/YOUR_USERNAME/yandex-vless-vpn.git
cd yandex-vless-vpn

# ИЛИ загрузите с Mac:
# На Mac: cd ~/yandex-vless-vpn && tar czf vpn.tar.gz --exclude='node_modules' --exclude='.git' .
# На Mac: scp vpn.tar.gz root@YOUR_SERVER_IP:/root/
# На VPS: mkdir yandex-vless-vpn && cd yandex-vless-vpn && tar xzf ../vpn.tar.gz

# 4. Запустите автодеплой
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

**Введите когда попросит:**
- Bot Token (от @BotFather)
- Ваш Telegram ID (от @userinfobot)

**Готово!** Через 5-10 минут все запустится.

---

## ✅ Проверка

```bash
# Статус
docker-compose ps

# Логи
docker-compose logs -f

# Мониторинг
./scripts/monitor.sh
```

---

## 🔧 Полезные команды

```bash
# Перезапуск
docker-compose restart

# Остановка
docker-compose down

# Запуск
docker-compose up -d

# Логи Xray
docker-compose logs -f xray

# Логи бота
docker-compose logs -f telegram-bot

# Ресурсы
docker stats
```

---

## 📱 Подключение клиента

1. Откройте бота в Telegram
2. Отправьте `/start`
3. Нажмите "🔑 Получить конфигурацию"
4. Сканируйте QR код в приложении (v2rayNG/Shadowrocket)

**Проверка:** Откройте 2ip.ru - должен показать IP вашего VPS

---

## 🆘 Если что-то не так

```bash
# Пересоздать контейнеры
docker-compose down && docker-compose up -d --force-recreate

# Проверить порт 443
netstat -tulpn | grep 443

# Проверить firewall
ufw status

# Открыть порт 443
ufw allow 443/tcp

# Полные логи
docker logs vless-xray
docker logs vless-bot
```

---

## 📖 Подробная инструкция

См. `DEPLOYMENT_INSTRUCTIONS.md` для полной документации.
