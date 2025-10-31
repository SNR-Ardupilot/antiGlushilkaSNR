# Multi-stage build для Telegram бота
FROM node:20-alpine AS builder

LABEL maintainer="VLESS VPN Project"
LABEL description="Telegram bot for VLESS VPN configuration distribution"

# Установка зависимостей для сборки
RUN apk add --no-cache python3 make g++

WORKDIR /app

# Копирование package files
COPY package*.json ./
COPY tsconfig.json ./

# Установка зависимостей
RUN npm ci --only=production && \
    npm install -D typescript @types/node

# Копирование исходников
COPY src/ ./src/

# Компиляция TypeScript
RUN npm run build

# Production образ
FROM node:20-alpine

# Используем существующего пользователя node (уже есть в базовом образе)

# Установка runtime зависимостей
RUN apk add --no-cache curl ca-certificates tzdata

# Создание директории для данных с правами node
RUN mkdir -p /data && chown -R node:node /data

WORKDIR /app

# Копирование только необходимых файлов
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist

# Установка прав
RUN chown -R node:node /app

# Переключение на непривилегированного пользователя
USER node

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD pgrep -f "node.*bot.js" || exit 1

# Запуск бота
CMD ["node", "dist/bot.js"]
