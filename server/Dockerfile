# Multi-stage build для Xray сервера
FROM alpine:3.19 AS builder

# Установка зависимостей для сборки
RUN apk add --no-cache curl unzip

# Скачивание Xray-core
ARG XRAY_VERSION=1.8.7
RUN curl -L "https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-64.zip" -o /tmp/xray.zip && \
    unzip /tmp/xray.zip -d /tmp/xray && \
    chmod +x /tmp/xray/xray

# Production образ
FROM alpine:3.19

LABEL maintainer="VLESS VPN Project"
LABEL description="Xray-core server with Reality protocol"

# Создание пользователя xray
RUN addgroup -g 10000 xray && \
    adduser -D -u 10000 -G xray xray

# Установка runtime зависимостей
RUN apk add --no-cache ca-certificates tzdata

# Копирование бинарника из builder
COPY --from=builder /tmp/xray/xray /usr/local/bin/xray
COPY --from=builder /tmp/xray/geoip.dat /usr/local/share/xray/
COPY --from=builder /tmp/xray/geosite.dat /usr/local/share/xray/

# Создание необходимых директорий
RUN mkdir -p /etc/xray /var/log/xray && \
    chown -R xray:xray /etc/xray /var/log/xray

# Копирование конфигурации
COPY config.json /etc/xray/config.json

# Установка прав
RUN chown xray:xray /etc/xray/config.json

# Переключение на непривилегированного пользователя
USER xray

# Открытие портов
EXPOSE 443

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD ps aux | grep xray | grep -v grep || exit 1

# Запуск Xray
ENTRYPOINT ["/usr/local/bin/xray"]
CMD ["run", "-config", "/etc/xray/config.json"]
