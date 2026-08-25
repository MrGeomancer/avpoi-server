#!/bin/bash

# Использование:
# ./setup_project.sh <project_name> [branch]
#
# project_name = имя проекта на GitHub и папки
# branch       = ветка для git pull (по умолчанию release)

if [ $# -lt 1 ]; then
    echo "Использование: $0 <project_name> [branch]"
    exit 1
fi

PROJECT_NAME=$1
BRANCH=${2:-release}   # если ветка не указана → release
GITHUB_USER="MrGeomancer"
SERVICE_FILE="/etc/systemd/system/$PROJECT_NAME.service"

echo "=== Создаём проект $PROJECT_NAME (ветка: $BRANCH) ==="

# 1. Клонирование репозитория
cd ~ || exit
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

# 3. Установка зависимостей
echo "--> Устанавливаем зависимости"
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
deactivate

# 4. Папка для логов
mkdir -p logs

# 5. Создание systemd unit
if [ ! -f "$SERVICE_FILE" ]; then
    echo "--> Создаём systemd unit: $SERVICE_FILE"
    sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=Service for $PROJECT_NAME project
After=network-online.target
Wants=network-online.target
# OnFailure=send-alert@%n.service  # ЗАКОММЕНТИРОВАНО: вызывает ошибки DNS

[Service]
User=$USER
Group=$USER
WorkingDirectory=/home/$USER/$PROJECT_NAME

# Минус (-) перед командой означает: "если команда упадет, не прерывать запуск сервиса"
-ExecStartPre=/usr/bin/git -C /home/$USER/$PROJECT_NAME fetch origin $BRANCH
-ExecStartPre=/usr/bin/git -C /home/$USER/$PROJECT_NAME reset --hard origin/$BRANCH
-ExecStartPre=/home/$USER/$PROJECT_NAME/venv/bin/pip install -q -r /home/$USER/$PROJECT_NAME/requirements.txt

ExecStart=/home/$USER/$PROJECT_NAME/venv/bin/python3 /home/$USER/$PROJECT_NAME/main.py
Environment="UNIT_NAME=$PROJECT_NAME.service"
StandardOutput=null
StandardError=append:/home/$USER/$PROJECT_NAME/logs/service_errors.log

# Защита от бесконечного цикла падений: макс 3 перезапуска за 5 минут, потом стоп
Restart=on-failure
RestartSec=15s
StartLimitBurst=3
StartLimitIntervalSec=300

[Install]
WantedBy=multi-user.target
EOL
else
    echo "--> Unit уже существует: $SERVICE_FILE"
fi
# 6. Подключаем таймер ежедневного рестарта
if systemctl list-unit-files | grep -q "botrestart@.timer"; then
    echo "--> Включаем ежедневный рестарт для $PROJECT_NAME"
    sudo systemctl enable --now "botrestart@${PROJECT_NAME}.timer"
else
    echo "!!! Шаблон botrestart@.timer не найден, пропускаем настройку ежедневного рестарта"
fi

# 7. Добавляем проект в MOTD для авто-отображения статуса
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

