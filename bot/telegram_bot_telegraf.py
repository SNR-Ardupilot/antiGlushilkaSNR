#!/usr/bin/env python3
"""
Telegram бот для выдачи VLESS конфигураций на основе Telegraf
"""

import os
import io
import logging
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    ApplicationBuilder,
    CommandHandler,
    CallbackQueryHandler,
    ContextTypes,
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


class VPNBot:
    """Класс Telegram бота для VPN"""

    def __init__(self, token: str, admin_ids: list):
        self.token = token
        self.admin_ids = admin_ids
        self.user_manager = VLESSUserManager()

    async def start_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Обработчик команды /start"""
        user_id = update.effective_user.id
        username = update.effective_user.username or f"user_{user_id}"

        keyboard = [
            [InlineKeyboardButton("🔑 Получить конфигурацию", callback_data='get_config')],
            [InlineKeyboardButton("📱 Инструкция", callback_data='help')],
        ]

        if user_id in self.admin_ids:
            keyboard.append([InlineKeyboardButton("👥 Админ-панель", callback_data='admin_panel')])

        reply_markup = InlineKeyboardMarkup(keyboard)

        welcome_message = (
            "👋 <b>Добро пожаловать в VLESS VPN бот!</b>\n\n"
            "🔐 Протокол: VLESS + Reality\n"
            "🎭 Маскировка: Yandex.ru\n"
            "🚀 Высокая скорость и безопасность\n\n"
            "📍 Выберите действие:"
        )

        await update.message.reply_text(
            welcome_message,
            reply_markup=reply_markup,
            parse_mode='HTML'
        )

    async def get_config_callback(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Получение конфигурации"""
        query = update.callback_query
        await query.answer()

        user_id = update.effective_user.id
        username = update.effective_user.username or f"user_{user_id}"

        # Получение или создание пользователя
        user_data = self.user_manager.get_user_by_telegram_id(user_id)

        if not user_data:
            user_data = self.user_manager.add_user(username, telegram_id=user_id)
            if not user_data:
                await query.edit_message_text("❌ Ошибка создания конфигурации. Попробуйте позже.")
                return
            message_prefix = "✅ <b>Конфигурация создана!</b>\n\n"
        else:
            message_prefix = "✅ <b>Ваша конфигурация:</b>\n\n"

        vless_link = user_data['vless_link']

        # Генерация QR кода
        qr = qrcode.QRCode(version=1, box_size=10, border=5)
        qr.add_data(vless_link)
        qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white")

        bio = io.BytesIO()
        img.save(bio, 'PNG')
        bio.seek(0)

        caption = (
            f"{message_prefix}"
            f"👤 <b>Пользователь:</b> <code>{user_data['username']}</code>\n"
            f"🆔 <b>UUID:</b> <code>{user_data['uuid'][:8]}...</code>\n"
            f"📅 <b>Создан:</b> {user_data['created_at'][:10]}\n\n"
            f"<b>🔗 VLESS ссылка:</b>\n"
            f"<code>{vless_link}</code>\n\n"
            f"📲 <b>Как подключиться:</b>\n"
            f"• Скачайте v2rayNG (Android) или Shadowrocket (iOS)\n"
            f"• Отсканируйте QR код или скопируйте ссылку\n"
            f"• Активируйте подключение\n\n"
            f"💡 Подробная инструкция: /help"
        )

        await query.message.reply_photo(
            photo=bio,
            caption=caption,
            parse_mode='HTML'
        )

        keyboard = [[InlineKeyboardButton("🔙 Главное меню", callback_data='back_to_menu')]]
        reply_markup = InlineKeyboardMarkup(keyboard)

        await query.edit_message_text(
            "✅ Конфигурация отправлена выше ⬆️",
            reply_markup=reply_markup
        )

    async def help_callback(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Инструкция по подключению"""
        query = update.callback_query
        await query.answer()

        help_text = (
            "📱 <b>Подробная инструкция по подключению</b>\n\n"
            "<b>📱 Android (v2rayNG):</b>\n"
            "1. Скачайте <a href='https://play.google.com/store/apps/details?id=com.v2ray.ang'>v2rayNG</a>\n"
            "2. Откройте приложение\n"
            "3. Нажмите '+' в правом верхнем углу\n"
            "4. Выберите 'Импорт из QR кода'\n"
            "5. Отсканируйте QR код из бота\n"
            "6. Нажмите на созданное подключение\n"
            "7. Нажмите кнопку подключения внизу\n\n"
            "<b>📱 iOS (Shadowrocket):</b>\n"
            "1. Скачайте Shadowrocket из App Store ($2.99)\n"
            "2. Откройте приложение\n"
            "3. Нажмите '+' в правом верхнем углу\n"
            "4. Выберите 'Type' → 'Scanner'\n"
            "5. Отсканируйте QR код\n"
            "6. Включите переключатель подключения\n\n"
            "<b>💻 Windows (v2rayN):</b>\n"
            "1. Скачайте <a href='https://github.com/2dust/v2rayN/releases'>v2rayN</a>\n"
            "2. Запустите программу\n"
            "3. Нажмите 'Серверы' → 'Импорт из буфера обмена'\n"
            "4. Скопируйте VLESS ссылку из бота\n"
            "5. Выберите сервер и нажмите Enter\n\n"
            "<b>🍎 macOS (v2rayU):</b>\n"
            "1. Скачайте <a href='https://github.com/yanue/V2rayU/releases'>v2rayU</a>\n"
            "2. Установите и запустите\n"
            "3. Нажмите '+' → 'Import from clipboard'\n"
            "4. Вставьте VLESS ссылку\n"
            "5. Выберите сервер для подключения\n\n"
            "❓ <b>Часто задаваемые вопросы:</b>\n\n"
            "<b>Q:</b> Не подключается?\n"
            "<b>A:</b> Проверьте правильность импорта конфига и наличие интернета\n\n"
            "<b>Q:</b> Медленная скорость?\n"
            "<b>A:</b> Попробуйте перезапустить подключение\n\n"
            "<b>Q:</b> Нужна помощь?\n"
            "<b>A:</b> Обратитесь к администратору"
        )

        keyboard = [[InlineKeyboardButton("🔙 Назад", callback_data='back_to_menu')]]
        reply_markup = InlineKeyboardMarkup(keyboard)

        await query.edit_message_text(
            help_text,
            reply_markup=reply_markup,
            parse_mode='HTML',
            disable_web_page_preview=True
        )

    async def admin_panel_callback(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Админ-панель"""
        query = update.callback_query
        await query.answer()

        user_id = update.effective_user.id

        if user_id not in self.admin_ids:
            await query.answer("❌ Нет доступа", show_alert=True)
            return

        users = self.user_manager.list_users()
        total_users = len(users)
        active_users = len([u for u in users if u.get('active', True)])

        admin_text = (
            f"👨‍💼 <b>Панель администратора</b>\n\n"
            f"📊 <b>Статистика:</b>\n"
            f"├ Всего пользователей: {total_users}\n"
            f"├ Активных: {active_users}\n"
            f"└ Заблокированных: {total_users - active_users}\n\n"
            f"🛠 Выберите действие:"
        )

        keyboard = [
            [InlineKeyboardButton("📋 Список пользователей", callback_data='list_users')],
            [InlineKeyboardButton("📊 Статистика", callback_data='stats')],
            [InlineKeyboardButton("🔙 Назад", callback_data='back_to_menu')]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)

        await query.edit_message_text(
            admin_text,
            reply_markup=reply_markup,
            parse_mode='HTML'
        )

    async def list_users_callback(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Список пользователей"""
        query = update.callback_query
        await query.answer()

        users = self.user_manager.list_users()

        if not users:
            text = "📋 Нет зарегистрированных пользователей"
        else:
            text = "📋 <b>Список пользователей:</b>\n\n"
            for i, user in enumerate(users[:20], 1):  # Ограничение 20 пользователей
                status = "✅" if user.get('active', True) else "❌"
                tg_id = user.get('telegram_id', 'N/A')
                created = user.get('created_at', 'N/A')[:10]
                text += f"{i}. {status} <code>{user['username']}</code>\n"
                text += f"   └ ID: {tg_id} | {created}\n"

            if len(users) > 20:
                text += f"\n... и еще {len(users) - 20} пользователей"

        keyboard = [[InlineKeyboardButton("🔙 Админ-панель", callback_data='admin_panel')]]
        reply_markup = InlineKeyboardMarkup(keyboard)

        await query.edit_message_text(
            text,
            reply_markup=reply_markup,
            parse_mode='HTML'
        )

    async def back_to_menu_callback(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Возврат в главное меню"""
        query = update.callback_query
        await query.answer()

        user_id = update.effective_user.id

        keyboard = [
            [InlineKeyboardButton("🔑 Получить конфигурацию", callback_data='get_config')],
            [InlineKeyboardButton("📱 Инструкция", callback_data='help')],
        ]

        if user_id in self.admin_ids:
            keyboard.append([InlineKeyboardButton("👥 Админ-панель", callback_data='admin_panel')])

        reply_markup = InlineKeyboardMarkup(keyboard)

        welcome_message = (
            "👋 <b>Главное меню</b>\n\n"
            "📍 Выберите действие:"
        )

        await query.edit_message_text(
            welcome_message,
            reply_markup=reply_markup,
            parse_mode='HTML'
        )

    def run(self):
        """Запуск бота"""
        if self.token == 'YOUR_BOT_TOKEN_HERE':
            logger.error("❌ Установите TELEGRAM_BOT_TOKEN!")
            return

        # Создание приложения
        app = ApplicationBuilder().token(self.token).build()

        # Регистрация обработчиков команд
        app.add_handler(CommandHandler("start", self.start_command))

        # Регистрация обработчиков callback
        app.add_handler(CallbackQueryHandler(self.get_config_callback, pattern='^get_config$'))
        app.add_handler(CallbackQueryHandler(self.help_callback, pattern='^help$'))
        app.add_handler(CallbackQueryHandler(self.admin_panel_callback, pattern='^admin_panel$'))
        app.add_handler(CallbackQueryHandler(self.list_users_callback, pattern='^list_users$'))
        app.add_handler(CallbackQueryHandler(self.back_to_menu_callback, pattern='^back_to_menu$'))

        # Запуск бота
        logger.info("🚀 Бот запущен и готов к работе!")
        logger.info(f"👥 Администраторы: {self.admin_ids}")

        app.run_polling(allowed_updates=Update.ALL_TYPES)


def main():
    """Точка входа"""
    bot = VPNBot(
        token=TELEGRAM_BOT_TOKEN,
        admin_ids=ADMIN_IDS
    )
    bot.run()


if __name__ == '__main__':
    main()
