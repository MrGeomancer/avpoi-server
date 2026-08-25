#!/bin/bash
set -e

echo "🔧 Установка sysadmin scripts..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/bin"

# 1. Создаем ~/bin если нет
mkdir -p "$BIN_DIR"

# 2. Создаем симлинки на утилиты
echo "📎 Создаем симлинки в ~/bin..."
ln -sf "$SCRIPT_DIR/bin/svcctl" "$BIN_DIR/svcctl"
ln -sf "$SCRIPT_DIR/bin/setup_project.sh" "$BIN_DIR/setup_project.sh"

# Делаем их исполняемыми
chmod +x "$BIN_DIR/svcctl" "$BIN_DIR/setup_project.sh"

# 3. Перенос и настройка MOTD
if [ -f "$SCRIPT_DIR/motd/99-custom" ]; then
    echo "📋 Устанавливаем custom MOTD..."
    sudo mkdir -p /etc/update-motd.d
    sudo cp "$SCRIPT_DIR/motd/99-custom" /etc/update-motd.d/99-custom
    sudo chmod +x /etc/update-motd.d/99-custom
    echo "✅ MOTD успешно установлен в /etc/update-motd.d/99-custom"
fi

# 4. Проверяем, что ~/bin есть в PATH
if ! echo "$PATH" | grep -q "$HOME/bin"; then
    echo "⚠️  ~/bin не найден в PATH"
    
    # Автоматически добавляем в зависимости от shell
    SHELL_CONFIG="$HOME/.bashrc"
    [ -n "$ZSH_VERSION" ] || [ -f "$HOME/.zshrc" ] && SHELL_CONFIG="$HOME/.zshrc"
    
    echo "" >> "$SHELL_CONFIG"
    echo 'export PATH="$HOME/bin:$PATH"' >> "$SHELL_CONFIG"
    echo "✅ Добавлено в $SHELL_CONFIG"
    echo "🔄 Перезапустите терминал или выполните: source $SHELL_CONFIG"
fi

echo "✅ Установка завершена!"
