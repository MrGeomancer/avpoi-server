#!/bin/bash
set -e

echo "🔄 Обновление sysadmin scripts..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Сохраняем текущую ветку
CURRENT_BRANCH=$(git branch --show-current)

# Pull изменений
echo "📥 Загружаем изменения из репозитория..."
git pull origin "$CURRENT_BRANCH"

# Пересоздаем симлинки
echo "🔧 Обновляем симлинки..."
"$SCRIPT_DIR/install.sh"

echo "✅ Обновление завершено!"
