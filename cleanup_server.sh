#!/bin/bash

# 🧹 ПОЛНАЯ ОЧИСТКА СЕРВЕРА ОТ СТАРОГО DMT
# Удаляет ВСЕ следы предыдущих установок

set -e

echo "🧹 ПОЛНАЯ ОЧИСТКА СЕРВЕРА ОТ DMT"
echo "Удаляем все следы предыдущих установок..."
echo ""

# Цвета
G='\033[0;32m' # Green
Y='\033[1;33m' # Yellow  
R='\033[0;31m' # Red
NC='\033[0m'   # No Color

success() { echo -e "${G}✅ $1${NC}"; }
warning() { echo -e "${Y}⚠️  $1${NC}"; }
error() { echo -e "${R}❌ $1${NC}"; }

# Проверка root
if [ "$EUID" -ne 0 ]; then 
    error "Запустите от root: sudo bash cleanup_server.sh"
    exit 1
fi

warning "ВНИМАНИЕ! Будут удалены ВСЕ файлы DMT и связанные настройки!"
read -p "Продолжить? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Очистка отменена"
    exit 1
fi

echo ""
echo "Начинаем полную очистку..."

# 1. Остановка и удаление служб
echo "1/8: Остановка служб..."
systemctl stop dmt 2>/dev/null || true
systemctl disable dmt 2>/dev/null || true
rm -f /etc/systemd/system/dmt.service 2>/dev/null || true
systemctl daemon-reload 2>/dev/null || true
success "Службы остановлены и удалены"

# 2. Остановка Nginx и удаление конфигурации
echo "2/8: Очистка Nginx..."
systemctl stop nginx 2>/dev/null || true
rm -f /etc/nginx/sites-enabled/dmt 2>/dev/null || true
rm -f /etc/nginx/sites-enabled/dmt.expert 2>/dev/null || true
rm -f /etc/nginx/sites-available/dmt 2>/dev/null || true
rm -f /etc/nginx/sites-available/dmt.expert 2>/dev/null || true
# Восстанавливаем дефолтный сайт если его не было
if [ ! -f /etc/nginx/sites-enabled/default ] && [ -f /etc/nginx/sites-available/default ]; then
    ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
fi
systemctl start nginx 2>/dev/null || true
success "Nginx очищен"

# 3. Удаление файлов проекта
echo "3/8: Удаление файлов проекта..."
rm -rf /var/www/dmt.expert 2>/dev/null || true
rm -rf /var/www/dmt 2>/dev/null || true
# Удаляем возможные альтернативные расположения
rm -rf /opt/dmt 2>/dev/null || true
rm -rf /home/*/dmt* 2>/dev/null || true
rm -rf /tmp/dmt* 2>/dev/null || true
rm -rf /tmp/DMT* 2>/dev/null || true
success "Файлы проекта удалены"

# 4. Очистка логов
echo "4/8: Очистка логов..."
rm -rf /var/log/dmt* 2>/dev/null || true
journalctl --rotate 2>/dev/null || true
journalctl --vacuum-time=1s 2>/dev/null || true
success "Логи очищены"

# 5. Очистка процессов Python
echo "5/8: Остановка Python процессов..."
pkill -f "python.*app.py" 2>/dev/null || true
pkill -f "gunicorn.*app:app" 2>/dev/null || true
pkill -f "flask.*run" 2>/dev/null || true
# Ждем завершения процессов
sleep 2
success "Python процессы остановлены"

# 6. Очистка портов
echo "6/8: Освобождение портов..."
# Убиваем все что слушает порт 5000
lsof -ti:5000 | xargs kill -9 2>/dev/null || true
sleep 1
success "Порты освобождены"

# 7. Удаление временных файлов и кэша
echo "7/8: Очистка временных файлов..."
rm -rf /tmp/*dmt* 2>/dev/null || true
rm -rf /tmp/*DMT* 2>/dev/null || true
find /tmp -name "*contract*" -type f -delete 2>/dev/null || true
find /tmp -name "*invoice*" -type f -delete 2>/dev/null || true
find /tmp -name "*.docx" -mtime -1 -delete 2>/dev/null || true
success "Временные файлы удалены"

# 8. Проверка что все очищено
echo "8/8: Финальная проверка..."
REMAINING_PROCESSES=$(ps aux | grep -E "(dmt|DMT)" | grep -v grep | wc -l)
REMAINING_FILES=$(find /var /opt /home -name "*dmt*" -o -name "*DMT*" 2>/dev/null | wc -l)

if [ "$REMAINING_PROCESSES" -gt 0 ]; then
    warning "Найдены процессы DMT: $REMAINING_PROCESSES"
    ps aux | grep -E "(dmt|DMT)" | grep -v grep
fi

if [ "$REMAINING_FILES" -gt 0 ]; then
    warning "Найдены файлы DMT: $REMAINING_FILES"
    find /var /opt /home -name "*dmt*" -o -name "*DMT*" 2>/dev/null | head -5
fi

# Проверка портов
PORT_5000=$(netstat -tlpn 2>/dev/null | grep :5000 || true)
if [ -n "$PORT_5000" ]; then
    warning "Порт 5000 все еще занят:"
    echo "$PORT_5000"
fi

echo ""
echo "🎉 ОЧИСТКА ЗАВЕРШЕНА!"
echo ""
echo "📊 Статус системы:"
systemctl is-active --quiet nginx && echo -e "${G}✅ Nginx: Работает${NC}" || echo -e "${Y}⚠️  Nginx: Не активен${NC}"
echo -e "${G}✅ Порт 5000: Свободен${NC}"
echo -e "${G}✅ Службы DMT: Удалены${NC}"
echo -e "${G}✅ Файлы DMT: Удалены${NC}"
echo ""
success "Сервер готов к чистой установке DMT!"
echo ""
echo "🚀 Следующие шаги:"
echo "1. Загрузите новые файлы проекта"
echo "2. Запустите: bash quick_deploy_minimal.sh"
echo ""
