#!/usr/bin/env python3
"""
Модуль управления пользователями VLESS сервера
"""

import json
import uuid
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Optional, Dict, List
import requests


class VLESSUserManager:
    """Менеджер пользователей VLESS сервера"""

    def __init__(self, config_path: str = "/usr/local/etc/xray/config.json",
                 users_db_path: str = "/root/users.json",
                 server_info_path: str = "/root/server_info.txt"):
        self.config_path = Path(config_path)
        self.users_db_path = Path(users_db_path)
        self.server_info_path = Path(server_info_path)

        # Инициализация базы данных пользователей
        if not self.users_db_path.exists():
            self.users_db_path.write_text(json.dumps({"users": []}, indent=2))

    def get_server_ip(self) -> str:
        """Получение внешнего IP сервера"""
        try:
            response = requests.get('https://ifconfig.me', timeout=5)
            return response.text.strip()
        except:
            return "YOUR_SERVER_IP"

    def get_public_key(self) -> str:
        """Получение публичного ключа Reality"""
        try:
            with open(self.server_info_path, 'r') as f:
                for line in f:
                    if "Public Key:" in line:
                        return line.split("Public Key:")[-1].strip()
        except:
            pass
        return ""

    def load_config(self) -> Dict:
        """Загрузка конфигурации Xray"""
        with open(self.config_path, 'r') as f:
            return json.load(f)

    def save_config(self, config: Dict):
        """Сохранение конфигурации Xray"""
        with open(self.config_path, 'w') as f:
            json.dump(config, f, indent=2)

    def load_users_db(self) -> Dict:
        """Загрузка базы данных пользователей"""
        with open(self.users_db_path, 'r') as f:
            return json.load(f)

    def save_users_db(self, db: Dict):
        """Сохранение базы данных пользователей"""
        with open(self.users_db_path, 'w') as f:
            json.dump(db, f, indent=2)

    def restart_xray(self) -> bool:
        """Перезапуск сервиса Xray"""
        try:
            subprocess.run(['systemctl', 'restart', 'xray'], check=True)
            return True
        except subprocess.CalledProcessError:
            return False

    def add_user(self, username: str, telegram_id: Optional[int] = None) -> Optional[Dict]:
        """
        Добавление нового пользователя

        Args:
            username: Имя пользователя
            telegram_id: ID пользователя в Telegram (опционально)

        Returns:
            Словарь с данными пользователя или None в случае ошибки
        """
        # Проверка существования пользователя
        users_db = self.load_users_db()
        if any(u['username'] == username for u in users_db['users']):
            return None

        # Генерация UUID
        user_uuid = str(uuid.uuid4())
        email = f"{username}@vpn.local"

        # Обновление конфигурации Xray
        config = self.load_config()
        new_client = {
            "id": user_uuid,
            "flow": "xtls-rprx-vision",
            "email": email
        }
        config['inbounds'][0]['settings']['clients'].append(new_client)
        self.save_config(config)

        # Создание VLESS ссылки
        server_ip = self.get_server_ip()
        public_key = self.get_public_key()
        vless_link = (
            f"vless://{user_uuid}@{server_ip}:443?"
            f"encryption=none&flow=xtls-rprx-vision&security=reality&"
            f"sni=yandex.ru&fp=chrome&pbk={public_key}&"
            f"sid=0123456789abcdef&type=tcp&headerType=none#{username}"
        )

        # Сохранение в базу данных
        user_data = {
            "username": username,
            "uuid": user_uuid,
            "email": email,
            "telegram_id": telegram_id,
            "vless_link": vless_link,
            "created_at": datetime.utcnow().isoformat() + "Z",
            "active": True,
            "traffic_used": 0
        }

        users_db['users'].append(user_data)
        self.save_users_db(users_db)

        # Перезапуск Xray
        self.restart_xray()

        return user_data

    def remove_user(self, username: str) -> bool:
        """
        Удаление пользователя

        Args:
            username: Имя пользователя

        Returns:
            True в случае успеха, False при ошибке
        """
        users_db = self.load_users_db()

        # Поиск пользователя
        user = next((u for u in users_db['users'] if u['username'] == username), None)
        if not user:
            return False

        user_uuid = user['uuid']

        # Удаление из конфигурации Xray
        config = self.load_config()
        config['inbounds'][0]['settings']['clients'] = [
            c for c in config['inbounds'][0]['settings']['clients']
            if c['id'] != user_uuid
        ]
        self.save_config(config)

        # Удаление из базы данных
        users_db['users'] = [u for u in users_db['users'] if u['username'] != username]
        self.save_users_db(users_db)

        # Перезапуск Xray
        self.restart_xray()

        return True

    def get_user(self, username: str) -> Optional[Dict]:
        """Получение информации о пользователе"""
        users_db = self.load_users_db()
        return next((u for u in users_db['users'] if u['username'] == username), None)

    def get_user_by_telegram_id(self, telegram_id: int) -> Optional[Dict]:
        """Получение пользователя по Telegram ID"""
        users_db = self.load_users_db()
        return next((u for u in users_db['users'] if u.get('telegram_id') == telegram_id), None)

    def list_users(self) -> List[Dict]:
        """Получение списка всех пользователей"""
        users_db = self.load_users_db()
        return users_db['users']

    def get_user_config(self, username: str) -> Optional[str]:
        """Получение VLESS ссылки пользователя"""
        user = self.get_user(username)
        return user['vless_link'] if user else None


if __name__ == "__main__":
    # Пример использования
    manager = VLESSUserManager()

    # Добавление пользователя
    user = manager.add_user("test_user", telegram_id=123456789)
    if user:
        print(f"Пользователь создан: {user['username']}")
        print(f"VLESS ссылка: {user['vless_link']}")

    # Список пользователей
    users = manager.list_users()
    print(f"\nВсего пользователей: {len(users)}")
