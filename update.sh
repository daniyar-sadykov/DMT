#!/bin/bash

# Скрипт для обновления DMT приложения на сервере
# Использование: bash update.sh

set -e

echo "🔄 Обновление DMT Document Generation System..."

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Проверка root
if [ "$EUID" -ne 0 ]; then 
    echo "Запустите от root: sudo bash update.sh"
    exit 1
fi

cd /var/www/dmt.expert

echo ""
echo "Шаг 1/5: Создание резервной копии..."
BACKUP_DIR="/backups"
mkdir -p $BACKUP_DIR
tar -czf $BACKUP_DIR/dmt-backup-$(date +%Y%m%d-%H%M%S).tar.gz /var/www/dmt.expert
success "Бэкап создан в $BACKUP_DIR"

echo ""
warning "ВНИМАНИЕ! Скопируйте обновленные файлы в /var/www/dmt.expert/"
warning "Или используйте git pull, если проект в git"
echo ""
read -p "Нажмите Enter после копирования файлов..."

echo ""
echo "Шаг 2/5: Обновление зависимостей..."
source venv/bin/activate
pip install -r requirements.txt --upgrade
success "Зависимости обновлены"

echo ""
echo "Шаг 3/5: Проверка конфигурации..."
if [ ! -f ".env" ]; then
    warning "Файл .env не найден! Создайте его вручную."
fi
success "Конфигурация проверена"

echo ""
echo "Шаг 4/5: Перезапуск службы..."
systemctl restart dmt
sleep 2
systemctl status dmt --no-pager
success "Служба перезапущена"

echo ""
echo "Шаг 5/5: Проверка Nginx..."
nginx -t
systemctl reload nginx
success "Nginx перезагружен"

echo ""
echo "🎉 Обновление завершено!"
echo ""
echo "Проверьте работу сайта: https://dmt.expert"
echo ""
echo "Просмотр логов:"
echo "  journalctl -u dmt -f"
echo "  tail -f /var/log/nginx/error.log"


