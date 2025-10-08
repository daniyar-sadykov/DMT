#!/bin/bash

# 🚀 МИНИМАЛЬНЫЙ СКРИПТ РАЗВЕРТЫВАНИЯ DMT
# Только самое необходимое для production

set -e

echo "🚀 DMT Production Deployment"
echo "Минимальная установка за 3 минуты"
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
    error "Запустите от root: sudo bash quick_deploy_minimal.sh"
    exit 1
fi

# Шаг 1: Установка базовых пакетов
echo "1/6: Установка пакетов..."
apt update > /dev/null 2>&1
apt install -y python3 python3-pip python3-venv nginx gunicorn > /dev/null 2>&1
success "Пакеты установлены"

# Шаг 2: Создание структуры
echo "2/6: Создание структуры..."
mkdir -p /var/www/dmt.expert/{logs,created_docx}
chmod 755 /var/www/dmt.expert/{logs,created_docx}
success "Структура создана"

# Шаг 3: Python окружение
echo "3/6: Python окружение..."
cd /var/www/dmt.expert
python3 -m venv venv > /dev/null 2>&1
source venv/bin/activate
pip install -r requirements.txt > /dev/null 2>&1
success "Python готов"

# Шаг 4: Systemd служба
echo "4/6: Служба systemd..."
cat > /etc/systemd/system/dmt.service << 'EOF'
[Unit]
Description=DMT Production Service
After=network.target

[Service]
User=root
WorkingDirectory=/var/www/dmt.expert
Environment="PATH=/var/www/dmt.expert/venv/bin"
Environment="FLASK_ENV=production"
ExecStart=/var/www/dmt.expert/venv/bin/gunicorn --workers 2 --bind 127.0.0.1:5000 --timeout 300 app:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload > /dev/null 2>&1
systemctl enable dmt > /dev/null 2>&1
systemctl start dmt > /dev/null 2>&1
success "Служба запущена"

# Шаг 5: Nginx
echo "5/6: Nginx конфигурация..."
cat > /etc/nginx/sites-available/dmt << 'EOF'
server {
    listen 80;
    server_name _;
    client_max_body_size 50M;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
    }
}
EOF

ln -sf /etc/nginx/sites-available/dmt /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t > /dev/null 2>&1 && systemctl restart nginx > /dev/null 2>&1
success "Nginx настроен"

# Шаг 6: Проверка
echo "6/6: Проверка..."
sleep 2
if systemctl is-active --quiet dmt && systemctl is-active --quiet nginx; then
    success "Все службы работают"
else
    error "Проблемы с службами"
    systemctl status dmt --no-pager -l
    exit 1
fi

echo ""
echo "🎉 РАЗВЕРТЫВАНИЕ ЗАВЕРШЕНО!"
echo ""
echo "📊 Статус:"
systemctl is-active --quiet dmt && echo -e "${G}✅ DMT: Работает${NC}" || echo -e "${R}❌ DMT: Не работает${NC}"
systemctl is-active --quiet nginx && echo -e "${G}✅ Nginx: Работает${NC}" || echo -e "${R}❌ Nginx: Не работает${NC}"
echo ""
echo "🌐 Сайт доступен по адресу: http://$(hostname -I | awk '{print $1}')"
echo ""
echo "📝 Полезные команды:"
echo "  systemctl status dmt     # Статус"
echo "  journalctl -u dmt -f     # Логи"
echo "  systemctl restart dmt    # Перезапуск"
echo ""
success "Готово за $(date '+%M:%S')! 🚀"
