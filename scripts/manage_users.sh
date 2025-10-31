#!/bin/bash

# Скрипт управления пользователями VLESS сервера

CONFIG_FILE="/usr/local/etc/xray/config.json"
USERS_DB="/root/users.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Инициализация базы данных пользователей если не существует
if [ ! -f "$USERS_DB" ]; then
    echo '{"users": []}' > "$USERS_DB"
fi

# Получение Public Key из конфига
get_public_key() {
    grep "publicKey" /root/server_info.txt | awk '{print $3}' || echo ""
}

# Добавление пользователя
add_user() {
    local username=$1
    local email="${username}@vpn.local"

    # Генерация UUID
    local uuid=$(uuidgen)

    # Проверка существования пользователя
    if jq -e ".users[] | select(.username==\"$username\")" "$USERS_DB" > /dev/null 2>&1; then
        echo -e "${RED}Пользователь $username уже существует${NC}"
        return 1
    fi

    # Добавление в конфиг Xray
    local temp_config=$(jq ".inbounds[0].settings.clients += [{\"id\": \"$uuid\", \"flow\": \"xtls-rprx-vision\", \"email\": \"$email\"}]" "$CONFIG_FILE")
    echo "$temp_config" > "$CONFIG_FILE"

    # Сохранение в базу данных
    local server_ip=$(curl -s ifconfig.me)
    local public_key=$(get_public_key)
    local vless_link="vless://${uuid}@${server_ip}:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=yandex.ru&fp=chrome&pbk=${public_key}&sid=0123456789abcdef&type=tcp&headerType=none#${username}"

    local user_data=$(jq -n \
        --arg username "$username" \
        --arg uuid "$uuid" \
        --arg email "$email" \
        --arg link "$vless_link" \
        --arg created "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{username: $username, uuid: $uuid, email: $email, vless_link: $link, created_at: $created, active: true}')

    jq ".users += [$user_data]" "$USERS_DB" > "${USERS_DB}.tmp" && mv "${USERS_DB}.tmp" "$USERS_DB"

    # Перезапуск Xray
    systemctl restart xray

    echo -e "${GREEN}Пользователь $username успешно добавлен${NC}"
    echo -e "${GREEN}UUID: $uuid${NC}"
    echo -e "${GREEN}VLESS ссылка:${NC}"
    echo "$vless_link"

    return 0
}

# Удаление пользователя
remove_user() {
    local username=$1

    # Получение UUID пользователя
    local uuid=$(jq -r ".users[] | select(.username==\"$username\") | .uuid" "$USERS_DB")

    if [ -z "$uuid" ] || [ "$uuid" == "null" ]; then
        echo -e "${RED}Пользователь $username не найден${NC}"
        return 1
    fi

    # Удаление из конфига Xray
    local temp_config=$(jq "del(.inbounds[0].settings.clients[] | select(.id==\"$uuid\"))" "$CONFIG_FILE")
    echo "$temp_config" > "$CONFIG_FILE"

    # Удаление из базы данных
    jq "del(.users[] | select(.username==\"$username\"))" "$USERS_DB" > "${USERS_DB}.tmp" && mv "${USERS_DB}.tmp" "$USERS_DB"

    # Перезапуск Xray
    systemctl restart xray

    echo -e "${GREEN}Пользователь $username успешно удален${NC}"
    return 0
}

# Список пользователей
list_users() {
    echo -e "${YELLOW}=== Список пользователей ===${NC}"
    jq -r '.users[] | "\(.username) | UUID: \(.uuid) | Создан: \(.created_at) | Активен: \(.active)"' "$USERS_DB"
}

# Получение конфига пользователя
get_user_config() {
    local username=$1
    local vless_link=$(jq -r ".users[] | select(.username==\"$username\") | .vless_link" "$USERS_DB")

    if [ -z "$vless_link" ] || [ "$vless_link" == "null" ]; then
        echo -e "${RED}Пользователь $username не найден${NC}"
        return 1
    fi

    echo -e "${GREEN}VLESS ссылка для $username:${NC}"
    echo "$vless_link"

    # Создание QR кода (опционально)
    if command -v qrencode &> /dev/null; then
        echo -e "${YELLOW}QR код:${NC}"
        qrencode -t ANSIUTF8 "$vless_link"
    fi

    return 0
}

# Меню
show_menu() {
    echo -e "${GREEN}=== Управление пользователями VLESS ===${NC}"
    echo "1) Добавить пользователя"
    echo "2) Удалить пользователя"
    echo "3) Список пользователей"
    echo "4) Получить конфиг пользователя"
    echo "5) Выход"
    echo -n "Выберите действие: "
}

# Основной цикл
if [ "$1" == "add" ] && [ -n "$2" ]; then
    add_user "$2"
elif [ "$1" == "remove" ] && [ -n "$2" ]; then
    remove_user "$2"
elif [ "$1" == "list" ]; then
    list_users
elif [ "$1" == "get" ] && [ -n "$2" ]; then
    get_user_config "$2"
else
    while true; do
        show_menu
        read choice
        case $choice in
            1)
                echo -n "Введите имя пользователя: "
                read username
                add_user "$username"
                ;;
            2)
                echo -n "Введите имя пользователя: "
                read username
                remove_user "$username"
                ;;
            3)
                list_users
                ;;
            4)
                echo -n "Введите имя пользователя: "
                read username
                get_user_config "$username"
                ;;
            5)
                exit 0
                ;;
            *)
                echo -e "${RED}Неверный выбор${NC}"
                ;;
        esac
        echo ""
    done
fi
