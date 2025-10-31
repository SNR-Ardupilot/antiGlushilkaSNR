import { Telegraf, Markup, Context } from 'telegraf';
import { message } from 'telegraf/filters';
import * as dotenv from 'dotenv';
import * as QRCode from 'qrcode';
import { UserManager } from './user-manager';
import { logger } from './logger';

dotenv.config();

// Конфигурация
const BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN || '';
const ADMIN_IDS = process.env.ADMIN_IDS?.split(',').map(id => parseInt(id.trim())) || [];

if (!BOT_TOKEN) {
  logger.error('❌ TELEGRAM_BOT_TOKEN не установлен!');
  process.exit(1);
}

// Инициализация
const bot = new Telegraf(BOT_TOKEN);
const userManager = new UserManager();

// Проверка является ли пользователь администратором
function isAdmin(userId: number): boolean {
  return ADMIN_IDS.includes(userId);
}

// Главное меню
function getMainMenu(userId: number) {
  const keyboard = [
    [Markup.button.callback('🔑 Получить конфигурацию', 'get_config')],
    [Markup.button.callback('📱 Инструкция', 'help')],
  ];

  if (isAdmin(userId)) {
    keyboard.push([Markup.button.callback('👥 Админ-панель', 'admin_panel')]);
  }

  return Markup.inlineKeyboard(keyboard);
}

// Команда /start
bot.command('start', async (ctx) => {
  const userId = ctx.from.id;
  const username = ctx.from.username || `user_${userId}`;

  const welcomeMessage = `👋 <b>Добро пожаловать в VLESS VPN бот!</b>

🔐 Протокол: VLESS + Reality
🎭 Маскировка: Yandex.ru
🚀 Высокая скорость и безопасность

📍 Выберите действие:`;

  await ctx.reply(welcomeMessage, {
    parse_mode: 'HTML',
    ...getMainMenu(userId)
  });
});

// Получение конфигурации
bot.action('get_config', async (ctx) => {
  await ctx.answerCbQuery();

  const userId = ctx.from.id;
  const username = ctx.from.username || `user_${userId}`;

  try {
    // Получение или создание пользователя
    let userData = userManager.getUserByTelegramId(userId);

    let isNewUser = false;
    if (!userData) {
      userData = userManager.addUser(username, userId);
      isNewUser = true;
      logger.info(`✅ Создан новый пользователь: ${username} (${userId})`);
    }

    if (!userData) {
      await ctx.editMessageText('❌ Ошибка создания конфигурации. Попробуйте позже.');
      return;
    }

    const vlessLink = userData.vless_link;

    // Генерация QR кода
    const qrCodeBuffer = await QRCode.toBuffer(vlessLink, {
      width: 512,
      margin: 2,
      errorCorrectionLevel: 'M',
    });

    const messagePrefix = isNewUser
      ? '✅ <b>Конфигурация создана!</b>\n\n'
      : '✅ <b>Ваша конфигурация:</b>\n\n';

    const caption = `${messagePrefix}👤 <b>Пользователь:</b> <code>${userData.username}</code>
🆔 <b>UUID:</b> <code>${userData.uuid.substring(0, 8)}...</code>
📅 <b>Создан:</b> ${new Date(userData.created_at).toLocaleDateString('ru-RU')}

<b>🔗 VLESS ссылка:</b>
<code>${vlessLink}</code>

📲 <b>Как подключиться:</b>
• Скачайте v2rayNG (Android) или Shadowrocket (iOS)
• Отсканируйте QR код или скопируйте ссылку
• Активируйте подключение

💡 Подробная инструкция: нажмите "📱 Инструкция"`;

    await ctx.replyWithPhoto(
      { source: qrCodeBuffer },
      {
        caption,
        parse_mode: 'HTML'
      }
    );

    await ctx.editMessageText('✅ Конфигурация отправлена выше ⬆️', {
      ...Markup.inlineKeyboard([
        [Markup.button.callback('🔙 Главное меню', 'back_to_menu')]
      ])
    });

  } catch (error) {
    logger.error('Ошибка при создании конфигурации:', error);
    await ctx.editMessageText('❌ Произошла ошибка. Попробуйте позже.');
  }
});

// Инструкция
bot.action('help', async (ctx) => {
  await ctx.answerCbQuery();

  const helpText = `📱 <b>Подробная инструкция по подключению</b>

<b>📱 Android (v2rayNG):</b>
1. Скачайте v2rayNG из Google Play
2. Откройте приложение
3. Нажмите '+' в правом верхнем углу
4. Выберите 'Импорт из QR кода'
5. Отсканируйте QR код из бота
6. Нажмите на созданное подключение
7. Нажмите кнопку подключения внизу

<b>📱 iOS (Shadowrocket):</b>
1. Скачайте Shadowrocket из App Store ($2.99)
2. Откройте приложение
3. Нажмите '+' в правом верхнем углу
4. Выберите 'Type' → 'Scanner'
5. Отсканируйте QR код
6. Включите переключатель подключения

<b>💻 Windows (v2rayN):</b>
1. Скачайте v2rayN с GitHub
2. Запустите программу
3. Нажмите 'Серверы' → 'Импорт из буфера обмена'
4. Скопируйте VLESS ссылку из бота
5. Выберите сервер и нажмите Enter

<b>🍎 macOS (v2rayU):</b>
1. Скачайте v2rayU с GitHub
2. Установите и запустите
3. Нажмите '+' → 'Import from clipboard'
4. Вставьте VLESS ссылку
5. Выберите сервер для подключения

<b>❓ Часто задаваемые вопросы:</b>

<b>Q:</b> Не подключается?
<b>A:</b> Проверьте правильность импорта конфига и наличие интернета

<b>Q:</b> Медленная скорость?
<b>A:</b> Попробуйте перезапустить подключение

<b>Q:</b> Нужна помощь?
<b>A:</b> Обратитесь к администратору`;

  await ctx.editMessageText(helpText, {
    parse_mode: 'HTML',
    ...Markup.inlineKeyboard([
      [Markup.button.callback('🔙 Назад', 'back_to_menu')]
    ])
  });
});

// Админ-панель
bot.action('admin_panel', async (ctx) => {
  await ctx.answerCbQuery();

  const userId = ctx.from.id;

  if (!isAdmin(userId)) {
    await ctx.answerCbQuery('❌ Нет доступа', { show_alert: true });
    return;
  }

  const users = userManager.listUsers();
  const totalUsers = users.length;
  const activeUsers = users.filter(u => u.active).length;

  const adminText = `👨‍💼 <b>Панель администратора</b>

📊 <b>Статистика:</b>
├ Всего пользователей: ${totalUsers}
├ Активных: ${activeUsers}
└ Заблокированных: ${totalUsers - activeUsers}

🛠 Выберите действие:`;

  await ctx.editMessageText(adminText, {
    parse_mode: 'HTML',
    ...Markup.inlineKeyboard([
      [Markup.button.callback('📋 Список пользователей', 'list_users')],
      [Markup.button.callback('📊 Статистика', 'stats')],
      [Markup.button.callback('🔙 Назад', 'back_to_menu')]
    ])
  });
});

// Список пользователей
bot.action('list_users', async (ctx) => {
  await ctx.answerCbQuery();

  const users = userManager.listUsers();

  if (users.length === 0) {
    await ctx.editMessageText('📋 Нет зарегистрированных пользователей', {
      ...Markup.inlineKeyboard([
        [Markup.button.callback('🔙 Админ-панель', 'admin_panel')]
      ])
    });
    return;
  }

  let text = '📋 <b>Список пользователей:</b>\n\n';

  const displayUsers = users.slice(0, 20); // Ограничение 20 пользователей

  displayUsers.forEach((user, index) => {
    const status = user.active ? '✅' : '❌';
    const tgId = user.telegram_id || 'N/A';
    const created = new Date(user.created_at).toLocaleDateString('ru-RU');
    text += `${index + 1}. ${status} <code>${user.username}</code>\n`;
    text += `   └ ID: ${tgId} | ${created}\n`;
  });

  if (users.length > 20) {
    text += `\n... и еще ${users.length - 20} пользователей`;
  }

  await ctx.editMessageText(text, {
    parse_mode: 'HTML',
    ...Markup.inlineKeyboard([
      [Markup.button.callback('🔙 Админ-панель', 'admin_panel')]
    ])
  });
});

// Статистика
bot.action('stats', async (ctx) => {
  await ctx.answerCbQuery();

  const users = userManager.listUsers();
  const totalUsers = users.length;
  const activeUsers = users.filter(u => u.active).length;

  // Подсчет пользователей по датам
  const today = new Date();
  const todayUsers = users.filter(u => {
    const created = new Date(u.created_at);
    return created.toDateString() === today.toDateString();
  }).length;

  const weekAgo = new Date(today.getTime() - 7 * 24 * 60 * 60 * 1000);
  const weekUsers = users.filter(u => {
    const created = new Date(u.created_at);
    return created >= weekAgo;
  }).length;

  const statsText = `📊 <b>Детальная статистика</b>

👥 <b>Пользователи:</b>
├ Всего: ${totalUsers}
├ Активных: ${activeUsers}
├ Заблокированных: ${totalUsers - activeUsers}
├ Новых сегодня: ${todayUsers}
└ Новых за неделю: ${weekUsers}

⏰ <b>Время работы:</b>
Бот активен и работает

💾 <b>База данных:</b>
Пользователей в БД: ${totalUsers}`;

  await ctx.editMessageText(statsText, {
    parse_mode: 'HTML',
    ...Markup.inlineKeyboard([
      [Markup.button.callback('🔙 Админ-панель', 'admin_panel')]
    ])
  });
});

// Возврат в главное меню
bot.action('back_to_menu', async (ctx) => {
  await ctx.answerCbQuery();

  const userId = ctx.from.id;

  const welcomeMessage = `👋 <b>Главное меню</b>

📍 Выберите действие:`;

  await ctx.editMessageText(welcomeMessage, {
    parse_mode: 'HTML',
    ...getMainMenu(userId)
  });
});

// Обработка ошибок
bot.catch((err, ctx) => {
  logger.error(`Ошибка для ${ctx.updateType}:`, err);
});

// Запуск бота
bot.launch()
  .then(() => {
    logger.info('🚀 Бот запущен и готов к работе!');
    logger.info(`👥 Администраторы: ${ADMIN_IDS.join(', ')}`);
  })
  .catch((error) => {
    logger.error('❌ Ошибка запуска бота:', error);
    process.exit(1);
  });

// Graceful stop
process.once('SIGINT', () => {
  logger.info('Остановка бота (SIGINT)...');
  bot.stop('SIGINT');
});

process.once('SIGTERM', () => {
  logger.info('Остановка бота (SIGTERM)...');
  bot.stop('SIGTERM');
});
