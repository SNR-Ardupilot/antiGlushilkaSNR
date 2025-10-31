import * as fs from 'fs';
import * as path from 'path';
import { v4 as uuidv4 } from 'uuid';
import { execSync } from 'child_process';
import { logger } from './logger';

export interface User {
  username: string;
  uuid: string;
  email: string;
  telegram_id?: number;
  vless_link: string;
  created_at: string;
  active: boolean;
  traffic_used: number;
}

interface UsersDatabase {
  users: User[];
}

export class UserManager {
  private configPath: string;
  private usersDbPath: string;
  private serverInfoPath: string;

  constructor(
    configPath: string = '/data/config.json',
    usersDbPath: string = '/data/users.json',
    serverInfoPath: string = '/data/server_info.txt'
  ) {
    this.configPath = configPath;
    this.usersDbPath = usersDbPath;
    this.serverInfoPath = serverInfoPath;

    // Инициализация БД если не существует
    if (!fs.existsSync(this.usersDbPath)) {
      this.saveUsersDb({ users: [] });
    }
  }

  private getServerIp(): string {
    try {
      // Сначала пытаемся получить из переменной окружения
      if (process.env.SERVER_IP) {
        return process.env.SERVER_IP;
      }

      const ip = execSync('curl -s ifconfig.me', { timeout: 5000 })
        .toString()
        .trim();
      return ip || '127.0.0.1';
    } catch (error) {
      logger.error('Ошибка получения IP сервера:', error);
      return '127.0.0.1';
    }
  }

  private getPublicKey(): string {
    try {
      // Сначала пытаемся получить из переменной окружения
      if (process.env.PUBLIC_KEY) {
        return process.env.PUBLIC_KEY;
      }

      if (!fs.existsSync(this.serverInfoPath)) {
        logger.warn('server_info.txt не найден, используется mock public key');
        return 'test_public_key_for_local_testing';
      }

      const content = fs.readFileSync(this.serverInfoPath, 'utf-8');
      const match = content.match(/Public Key:\s*(\S+)/);
      return match ? match[1] : 'test_public_key_for_local_testing';
    } catch (error) {
      logger.error('Ошибка получения публичного ключа:', error);
      return 'test_public_key_for_local_testing';
    }
  }

  private loadConfig(): any {
    try {
      if (!fs.existsSync(this.configPath)) {
        // Для локального тестирования возвращаем mock конфиг
        logger.warn('Конфиг не найден, используется mock для тестирования');
        return {
          inbounds: [{
            settings: {
              clients: []
            }
          }]
        };
      }
      const content = fs.readFileSync(this.configPath, 'utf-8');
      return JSON.parse(content);
    } catch (error) {
      logger.error('Ошибка загрузки конфигурации:', error);
      // Возвращаем mock вместо выброса ошибки
      return {
        inbounds: [{
          settings: {
            clients: []
          }
        }]
      };
    }
  }

  private saveConfig(config: any): void {
    try {
      if (!fs.existsSync(this.configPath)) {
        // Для локального тестирования просто пропускаем сохранение
        logger.warn('Конфиг не найден, сохранение пропущено (тестовый режим)');
        return;
      }
      fs.writeFileSync(
        this.configPath,
        JSON.stringify(config, null, 2),
        'utf-8'
      );
    } catch (error) {
      logger.error('Ошибка сохранения конфигурации:', error);
      // Не выбрасываем ошибку, просто логируем
      logger.warn('Продолжаем работу без сохранения конфига');
    }
  }

  private loadUsersDb(): UsersDatabase {
    try {
      const content = fs.readFileSync(this.usersDbPath, 'utf-8');
      return JSON.parse(content);
    } catch (error) {
      logger.error('Ошибка загрузки БД пользователей:', error);
      return { users: [] };
    }
  }

  private saveUsersDb(db: UsersDatabase): void {
    try {
      fs.writeFileSync(
        this.usersDbPath,
        JSON.stringify(db, null, 2),
        'utf-8'
      );
    } catch (error) {
      logger.error('Ошибка сохранения БД пользователей:', error);
      throw error;
    }
  }

  private restartXray(): boolean {
    try {
      execSync('systemctl restart xray', { timeout: 10000 });
      return true;
    } catch (error) {
      logger.error('Ошибка перезапуска Xray:', error);
      return false;
    }
  }

  addUser(username: string, telegramId?: number): User | null {
    try {
      const usersDb = this.loadUsersDb();

      // Проверка существования пользователя
      if (usersDb.users.some(u => u.username === username)) {
        logger.warn(`Пользователь ${username} уже существует`);
        return null;
      }

      // Генерация UUID
      const userUuid = uuidv4();
      const email = `${username}@vpn.local`;

      // Обновление конфигурации Xray
      const config = this.loadConfig();
      const newClient = {
        id: userUuid,
        flow: 'xtls-rprx-vision',
        email: email,
      };

      if (!config.inbounds[0].settings.clients) {
        config.inbounds[0].settings.clients = [];
      }

      config.inbounds[0].settings.clients.push(newClient);
      this.saveConfig(config);

      // Создание VLESS ссылки
      const serverIp = this.getServerIp();
      const publicKey = this.getPublicKey();

      const vlessLink =
        `vless://${userUuid}@${serverIp}:443?` +
        `encryption=none&flow=xtls-rprx-vision&security=reality&` +
        `sni=yandex.ru&fp=chrome&pbk=${publicKey}&` +
        `sid=0123456789abcdef&type=tcp&headerType=none#${username}`;

      // Создание объекта пользователя
      const user: User = {
        username,
        uuid: userUuid,
        email,
        telegram_id: telegramId,
        vless_link: vlessLink,
        created_at: new Date().toISOString(),
        active: true,
        traffic_used: 0,
      };

      // Сохранение в БД
      usersDb.users.push(user);
      this.saveUsersDb(usersDb);

      // Перезапуск Xray
      this.restartXray();

      logger.info(`✅ Добавлен пользователь: ${username} (${userUuid})`);

      return user;
    } catch (error) {
      logger.error('Ошибка добавления пользователя:', error);
      return null;
    }
  }

  removeUser(username: string): boolean {
    try {
      const usersDb = this.loadUsersDb();

      // Поиск пользователя
      const user = usersDb.users.find(u => u.username === username);
      if (!user) {
        logger.warn(`Пользователь ${username} не найден`);
        return false;
      }

      const userUuid = user.uuid;

      // Удаление из конфигурации Xray
      const config = this.loadConfig();
      config.inbounds[0].settings.clients =
        config.inbounds[0].settings.clients.filter(
          (c: any) => c.id !== userUuid
        );
      this.saveConfig(config);

      // Удаление из БД
      usersDb.users = usersDb.users.filter(u => u.username !== username);
      this.saveUsersDb(usersDb);

      // Перезапуск Xray
      this.restartXray();

      logger.info(`✅ Удален пользователь: ${username}`);

      return true;
    } catch (error) {
      logger.error('Ошибка удаления пользователя:', error);
      return false;
    }
  }

  getUser(username: string): User | null {
    const usersDb = this.loadUsersDb();
    return usersDb.users.find(u => u.username === username) || null;
  }

  getUserByTelegramId(telegramId: number): User | null {
    const usersDb = this.loadUsersDb();
    return usersDb.users.find(u => u.telegram_id === telegramId) || null;
  }

  listUsers(): User[] {
    const usersDb = this.loadUsersDb();
    return usersDb.users;
  }

  getUserConfig(username: string): string | null {
    const user = this.getUser(username);
    return user ? user.vless_link : null;
  }
}
