# Telegram бот для VLESS VPN

TypeScript Telegram бот для автоматической выдачи конфигураций VLESS VPN.

## Технологии

- **TypeScript** - типобезопасная разработка
- **Telegraf** - современный фреймворк для Telegram Bot API
- **Node.js** - runtime окружение
- **QRCode** - генерация QR кодов

## Разработка

### Локальная разработка

1. Установите зависимости:
```bash
npm install
```

2. Создайте файл `.env`:
```bash
cp .env.example .env
```

3. Отредактируйте `.env`:
```env
TELEGRAM_BOT_TOKEN=your_bot_token_here
ADMIN_IDS=your_telegram_id
DEBUG=true
```

4. Запустите в режиме разработки:
```bash
npm run dev
```

### Сборка для продакшена

```bash
npm run build
npm start
```

## Структура кода

```
src/
├── bot.ts           # Главный файл бота, обработчики команд и callback'ов
├── user-manager.ts  # Логика управления пользователями и Xray конфигом
└── logger.ts        # Простой модуль логирования
```

## Основные команды

- `/start` - Главное меню бота

## Callback кнопки

- `get_config` - Получение/создание конфигурации пользователя
- `help` - Инструкция по подключению
- `admin_panel` - Панель администратора (только для админов)
- `list_users` - Список всех пользователей
- `stats` - Статистика сервера
- `back_to_menu` - Возврат в главное меню

## UserManager API

### Методы

- `addUser(username, telegramId?)` - Добавление нового пользователя
- `removeUser(username)` - Удаление пользователя
- `getUser(username)` - Получение информации о пользователе
- `getUserByTelegramId(telegramId)` - Поиск по Telegram ID
- `listUsers()` - Список всех пользователей
- `getUserConfig(username)` - Получение VLESS ссылки

## Логи

Бот использует простую систему логирования через консоль. В продакшене логи доступны через systemd:

```bash
# Просмотр логов
journalctl -u vless-bot -f

# Последние 100 строк
journalctl -u vless-bot -n 100
```

## Особенности

### Автоматическое создание пользователей

При первом запросе конфигурации бот автоматически создает пользователя с username из Telegram.

### QR коды

Каждая конфигурация автоматически генерируется с QR кодом для простого импорта в клиентские приложения.

### Админ-панель

Пользователи с ID указанными в `ADMIN_IDS` получают доступ к:
- Списку всех пользователей
- Статистике сервера
- Дополнительным командам управления

## Безопасность

- Bot token хранится в `.env` файле (не коммитится в git)
- Только указанные admin ID имеют доступ к панели администратора
- Все операции с файловой системой логируются

## Тестирование

Для тестирования бота локально без доступа к серверу:

1. Закомментируйте вызовы `restartXray()` в `user-manager.ts`
2. Создайте тестовые файлы:
```bash
mkdir -p /tmp/test-vless
echo '{"inbounds":[{"settings":{"clients":[]}}]}' > /tmp/test-vless/config.json
echo '{"users":[]}' > /tmp/test-vless/users.json
```

3. Измените пути в конструкторе `UserManager`:
```typescript
new UserManager(
  '/tmp/test-vless/config.json',
  '/tmp/test-vless/users.json',
  '/tmp/test-vless/server_info.txt'
)
```

## Развертывание

См. основной README в корне проекта для инструкций по развертыванию на сервере.

## Troubleshooting

### Бот не отвечает

1. Проверьте статус: `systemctl status vless-bot`
2. Проверьте логи: `journalctl -u vless-bot -n 50`
3. Проверьте валидность токена в `.env`

### Ошибки при создании пользователя

1. Проверьте права доступа к `/usr/local/etc/xray/config.json`
2. Проверьте что Xray сервис запущен: `systemctl status xray`
3. Проверьте логи Xray: `tail -f /var/log/xray/error.log`

### TypeScript ошибки компиляции

```bash
# Очистка и пересборка
rm -rf dist node_modules
npm install
npm run build
```

## Лицензия

MIT
