#!/bin/bash

# Использование:
# ./setup_project.sh <project_name> [branch] [description]
#
# project_name = имя проекта на GitHub и папки
# branch       = ветка для git pull (по умолчанию release)
# description  = описание сервиса для systemd (по умолчанию "Service for <project_name>")

if [ $# -lt 1 ]; then
    echo "Использование: $0 <project_name> [branch] [description]"
    exit 1
fi

PROJECT_NAME=$1
BRANCH=${2:-release}
DESCRIPTION=${3:-"Service for $PROJECT_NAME project"}

GITHUB_USER="MrGeomancer"
SERVICE_FILE="/etc/systemd/system/$PROJECT_NAME.service"

# Определяем реального пользователя и его домашний каталог (даже при запуске через sudo)
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

echo "=== Создаём/обновляем проект $PROJECT_NAME (ветка: $BRANCH) ==="
echo "--> Описание: $DESCRIPTION"

# 1. Клонирование репозитория
cd "$TARGET_HOME" || exit
if [ ! -d "$PROJECT_NAME" ]; then
    echo "--> Клонируем git@github.com:$GITHUB_USER/$PROJECT_NAME.git"
    git clone "git@github.com:$GITHUB_USER/$PROJECT_NAME.git"
else
    echo "--> Папка $PROJECT_NAME уже существует, пропускаем git clone"
fi

cd "$PROJECT_NAME" || exit

# 2. Виртуальное окружение
if [ ! -d "venv" ]; then
    echo "--> Создаём виртуальное окружение"
    python3 -m venv venv
fi

# 3. Первичная установка зависимостей
echo "--> Устанавливаем зависимости"
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
deactivate

# 4. Папка для логов
mkdir -p logs

# 5. Создание/обновление systemd unit
echo "--> Генерируем systemd unit: $SERVICE_FILE"
sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=$DESCRIPTION
After=network-online.target
Wants=network-online.target

[Service]
User=$TARGET_USER
Group=$TARGET_USER
WorkingDirectory=$TARGET_HOME/$PROJECT_NAME

# Если нет сети или упал git, запуск продолжится с текущим кодом
-ExecStartPre=/usr/bin/git -C $TARGET_HOME/$PROJECT_NAME fetch origin $BRANCH
-ExecStartPre=/usr/bin/git -C $TARGET_HOME/$PROJECT_NAME reset --hard origin/$BRANCH

# pip install без '-'! Если упадет сборка пакетов, systemd покажет внятную ошибку
ExecStartPre=$TARGET_HOME/$PROJECT_NAME/venv/bin/pip install -q -r $TARGET_HOME/$PROJECT_NAME/requirements.txt

ExecStart=$TARGET_HOME/$PROJECT_NAME/venv/bin/python3 $TARGET_HOME/$PROJECT_NAME/main.py
Environment="UNIT_NAME=$PROJECT_NAME.service"

StandardOutput=journal
StandardError=append:$TARGET_HOME/$PROJECT_NAME/logs/service_errors.log

Restart=on-failure
RestartSec=15s
StartLimitBurst=3
StartLimitIntervalSec=300

[Install]
WantedBy=multi-user.target
EOL

# 6. Подключаем таймер ежедневного рестарта
if systemctl list-unit-files | grep -q "botrestart@.timer"; then
    echo "--> Включаем ежедневный рестарт для $PROJECT_NAME"
    sudo systemctl enable --now "botrestart@${PROJECT_NAME}.timer"
else
    echo "!!! Шаблон botrestart@.timer не найден, пропускаем настройку ежедневного рестарта"
fi

# 7. Добавляем проект в MOTD
MOTD_FILE="/etc/update-motd.d/99-custom"
if [ -f "$MOTD_FILE" ]; then
    if ! grep -q "$PROJECT_NAME" "$MOTD_FILE"; then
        echo "--> Добавляем $PROJECT_NAME в MOTD"
        sudo sed -i "/^for service in / s/\$/ $PROJECT_NAME/" "$MOTD_FILE"
    else
        echo "--> $PROJECT_NAME уже есть в MOTD"
    fi
else
    echo "!!! Файл $MOTD_FILE не найден, пропускаем обновление MOTD"
fi

# 8. Перезапуск systemd
echo "--> Перезапускаем systemd и включаем сервис"
sudo systemctl daemon-reload
sudo systemctl enable "$PROJECT_NAME"
sudo systemctl restart "$PROJECT_NAME"
sudo systemctl status "$PROJECT_NAME" --no-pager

echo "=== Готово! Сервис $PROJECT_NAME работает ==="
