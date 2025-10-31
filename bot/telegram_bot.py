#!/usr/bin/env python3
"""
Telegram бот для выдачи VLESS конфигураций
"""

import os
import io
import logging
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    Application,
    CommandHandler,
    CallbackQueryHandler,
    ContextTypes,
    MessageHandler,
    filters
)
import qrcode

from user_manager import VLESSUserManager

# Настройка логирования
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# Конфигурация
TELEGRAM_BOT_TOKEN = os.getenv('TELEGRAM_BOT_TOKEN', 'YOUR_BOT_TOKEN_HERE')
ADMIN_IDS = list(map(int, os.getenv('ADMIN_IDS', '').split(','))) if os.getenv('ADMIN_IDS') else []

# Инициализация менеджера пользователей
user_manager = VLESSUserManager()


async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Обработчик команды /start"""
    user_id = update.effective_user.id
    username = update.effective_user.username or f"user_{user_id}"

    keyboard = [
        [InlineKeyboardButton("🔑 Получить конфигурацию", callback_data='get_config')],
        [InlineKeyboardButton("📱 Инструкция по подключению", callback_data='help')],
    ]

    # Кнопки для администраторов
    if user_id in ADMIN_IDS:
        keyboard.append([InlineKeyboardButton("👥 Управление пользователями", callback_data='admin_panel')])

    reply_markup = InlineKeyboardMarkup(keyboard)

    welcome_message = (
        "👋 Добро пожаловать в VLESS VPN бот!\n\n"
        "🔐 Этот бот предоставляет доступ к защищенному VPN на базе протокола VLESS с маскировкой под Yandex.\n\n"
        "📍 Выберите действие:"
    )

    await update.message.reply_text(welcome_message, reply_markup=reply_markup)


async def get_config(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Получение конфигурации для пользователя"""
    query = update.callback_query
    await query.answer()

    user_id = update.effective_user.id
    username = update.effective_user.username or f"user_{user_id}"

    # Проверка существования пользователя
    user_data = user_manager.get_user_by_telegram_id(user_id)

    if not user_data:
        # Создание нового пользователя
        user_data = user_manager.add_user(username, telegram_id=user_id)
        if not user_data:
            await query.edit_message_text("❌ Ошибка при создании конфигурации. Попробуйте позже.")
            return

    vless_link = user_data['vless_link']

    # Генерация QR кода
    qr = qrcode.QRCode(version=1, box_size=10, border=5)
    qr.add_data(vless_link)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")

    # Сохранение QR кода в BytesIO
    bio = io.BytesIO()
    img.save(bio, 'PNG')
    bio.seek(0)

    message = (
        f"✅ Ваша конфигурация готова!\n\n"
        f"👤 Пользователь: {user_data['username']}\n"
        f"📅 Создан: {user_data['created_at'][:10]}\n\n"
        f"📲 Для подключения:\n"
        f"1️⃣ Скачайте приложение v2rayNG (Android) или Shadowrocket (iOS)\n"
        f"2️⃣ Отсканируйте QR код ниже или скопируйте ссылку\n"
        f"3️⃣ Подключитесь к VPN\n\n"
        f"🔗 VLESS ссылка:\n"
        f"<code>{vless_link}</code>"
    )

    await query.message.reply_photo(photo=bio, caption=message, parse_mode='HTML')

    keyboard = [[InlineKeyboardButton("🔙 Назад", callback_data='back_to_menu')]]
    reply_markup = InlineKeyboardMarkup(keyboard)
    await query.edit_message_text("✅ Конфигурация отправлена!", reply_markup=reply_markup)


async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Инструкция по подключению"""
    query = update.callback_query
    await query.answer()

    help_text = (
        "📱 <b>Инструкция по подключению</b>\n\n"
        "<b>Для Android:</b>\n"
        "1️⃣ Установите v2rayNG из Google Play\n"
        "2️⃣ Нажмите '+' → 'Сканировать QR код'\n"
        "3️⃣ Отсканируйте QR код из бота\n"
        "4️⃣ Нажмите на подключение для активации\n\n"
        "<b>Для iOS:</b>\n"
        "1️⃣ Установите Shadowrocket из App Store\n"
        "2️⃣ Нажмите '+' → 'Тип' → 'Сканировать'\n"
        "3️⃣ Отсканируйте QR код из бота\n"
        "4️⃣ Включите переключатель для подключения\n\n"
        "<b>Для Windows/Mac/Linux:</b>\n"
        "1️⃣ Установите v2rayN (Windows) или v2rayU (Mac)\n"
        "2️⃣ Импортируйте конфигурацию через VLESS ссылку\n"
        "3️⃣ Подключитесь к серверу\n\n"
        "❓ При проблемах обратитесь к администратору"
    )

    keyboard = [[InlineKeyboardButton("🔙 Назад", callback_data='back_to_menu')]]
    reply_markup = InlineKeyboardMarkup(keyboard)

    await query.edit_message_text(help_text, reply_markup=reply_markup, parse_mode='HTML')


async def admin_panel(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Панель администратора"""
    query = update.callback_query
    await query.answer()

    user_id = update.effective_user.id

    if user_id not in ADMIN_IDS:
        await query.edit_message_text("❌ У вас нет прав администратора")
        return

    users = user_manager.list_users()
    total_users = len(users)
    active_users = len([u for u in users if u.get('active', True)])

    admin_text = (
        f"👨‍💼 <b>Панель администратора</b>\n\n"
        f"👥 Всего пользователей: {total_users}\n"
        f"✅ Активных: {active_users}\n"
        f"❌ Заблокированных: {total_users - active_users}\n\n"
        f"Выберите действие:"
    )

    keyboard = [
        [InlineKeyboardButton("📋 Список пользователей", callback_data='list_users')],
        [InlineKeyboardButton("➕ Добавить пользователя", callback_data='add_user')],
        [InlineKeyboardButton("➖ Удалить пользователя", callback_data='remove_user')],
        [InlineKeyboardButton("🔙 Назад", callback_data='back_to_menu')]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)

    await query.edit_message_text(admin_text, reply_markup=reply_markup, parse_mode='HTML')


async def list_users(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Список всех пользователей"""
    query = update.callback_query
    await query.answer()

    users = user_manager.list_users()

    if not users:
        text = "📋 Нет зарегистрированных пользователей"
    else:
        text = "📋 <b>Список пользователей:</b>\n\n"
        for i, user in enumerate(users, 1):
            status = "✅" if user.get('active', True) else "❌"
            text += f"{i}. {status} {user['username']} (ID: {user.get('telegram_id', 'N/A')})\n"

    keyboard = [[InlineKeyboardButton("🔙 Назад", callback_data='admin_panel')]]
    reply_markup = InlineKeyboardMarkup(keyboard)

    await query.edit_message_text(text, reply_markup=reply_markup, parse_mode='HTML')


async def back_to_menu(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Возврат в главное меню"""
    query = update.callback_query
    await query.answer()

    keyboard = [
        [InlineKeyboardButton("🔑 Получить конфигурацию", callback_data='get_config')],
        [InlineKeyboardButton("📱 Инструкция по подключению", callback_data='help')],
    ]

    user_id = update.effective_user.id
    if user_id in ADMIN_IDS:
        keyboard.append([InlineKeyboardButton("👥 Управление пользователями", callback_data='admin_panel')])

    reply_markup = InlineKeyboardMarkup(keyboard)

    welcome_message = (
        "👋 Главное меню\n\n"
        "📍 Выберите действие:"
    )

    await query.edit_message_text(welcome_message, reply_markup=reply_markup)


async def button_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Обработчик нажатий на кнопки"""
    query = update.callback_query
    data = query.data

    handlers = {
        'get_config': get_config,
        'help': help_command,
        'admin_panel': admin_panel,
        'list_users': list_users,
        'back_to_menu': back_to_menu,
    }

    handler = handlers.get(data)
    if handler:
        await handler(update, context)


def main():
    """Запуск бота"""
    if TELEGRAM_BOT_TOKEN == 'YOUR_BOT_TOKEN_HERE':
        logger.error("❌ Установите TELEGRAM_BOT_TOKEN в переменных окружения!")
        return

    # Создание приложения
    application = Application.builder().token(TELEGRAM_BOT_TOKEN).build()

    # Регистрация обработчиков
    application.add_handler(CommandHandler("start", start))
    application.add_handler(CallbackQueryHandler(button_handler))

    # Запуск бота
    logger.info("🚀 Бот запущен!")
    application.run_polling(allowed_updates=Update.ALL_TYPES)


if __name__ == '__main__':
    main()
