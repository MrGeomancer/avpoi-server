#!/bin/bash
set -e

echo "🔧 Установка sysadmin scripts..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/bin"

# Создаем ~/bin если нет
mkdir -p "$BIN_DIR"

# Создаем симлинки
echo "📎 Создаем симлинки в ~/bin..."
ln -sf "$SCRIPT_DIR/bin/svcctl" "$BIN_DIR/svcctl"
ln -sf "$SCRIPT_DIR/bin/setup_project.sh" "$BIN_DIR/setup_project.sh"

# Делаем их исполняемыми
chmod +x "$BIN_DIR/svcctl" "$BIN_DIR/setup_project.sh"

# Проверяем, что ~/bin есть в PATH
if ! echo "$PATH" | grep -q "$HOME/bin"; then
    echo "⚠️  ~/bin не найден в PATH"
    echo "📝 Добавьте в ~/.bashrc или ~/.zshrc:"
    echo 'export PATH="$HOME/bin:$PATH"'
    
    # Автоматически добавляем
    echo "" >> ~/.zshrc
    echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
    echo "✅ Добавлено в ~/.zshrc"
    echo "🔄 Перезапустите терминал или выполните: source ~/.zshrc"
fi

echo "✅ Установка завершена!"
echo ""
echo "Доступные команды:"
echo "  - svcctl enable <project>"
echo "  - svcctl disable <project>"
echo "  - setup_project.sh <project> [branch]"
