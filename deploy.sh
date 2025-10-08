#!/bin/bash

# Скрипт автоматического развертывания DMT на Ubuntu сервере
# Использование: bash deploy.sh

set -e  # Остановка при ошибке

echo "🚀 Начинаем развертывание DMT Document Generation System..."

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Функция для вывода успешного сообщения
success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Функция для вывода предупреждения
warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Функция для вывода ошибки
error() {
    echo -e "${RED}❌ $1${NC}"
}

# Проверка, что скрипт запущен от root
if [ "$EUID" -ne 0 ]; then 
    error "Запустите скрипт от имени root: sudo bash deploy.sh"
    exit 1
fi

echo ""
echo "Шаг 1/12: Обновление системы..."
apt update && apt upgrade -y
success "Система обновлена"

echo ""
echo "Шаг 2/12: Установка Python и зависимостей..."
apt install -y python3 python3-pip python3-venv
success "Python установлен"

echo ""
echo "Шаг 3/12: Установка Nginx..."
apt install -y nginx
success "Nginx установлен"

echo ""
echo "Шаг 4/12: Установка Git..."
apt install -y git
success "Git установлен"

echo ""
echo "Шаг 5/12: Установка Certbot для SSL..."
apt install -y certbot python3-certbot-nginx
success "Certbot установлен"

echo ""
echo "Шаг 6/12: Создание директории для приложения..."
mkdir -p /var/www/dmt.expert
cd /var/www/dmt.expert
success "Директория создана"

echo ""
echo "Шаг 7/12: Создание виртуального окружения Python..."
python3 -m venv venv
source venv/bin/activate
success "Виртуальное окружение создано"

echo ""
warning "ВНИМАНИЕ! Скопируйте файлы проекта в /var/www/dmt.expert/"
warning "Используйте SCP, SFTP или FileZilla для загрузки файлов"
echo ""
read -p "Нажмите Enter после того, как скопируете файлы..."

echo ""
echo "Шаг 8/12: Установка зависимостей Python..."
if [ -f "/var/www/dmt.expert/requirements.txt" ]; then
    pip install -r requirements.txt
    pip install gunicorn
    success "Зависимости установлены"
else
    error "Файл requirements.txt не найден! Убедитесь, что файлы скопированы."
    exit 1
fi

echo ""
echo "Шаг 9/12: Создание .env файла..."
if [ ! -f "/var/www/dmt.expert/.env" ]; then
    SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_hex(32))')
    cat > /var/www/dmt.expert/.env << EOF
FLASK_ENV=production
SECRET_KEY=$SECRET_KEY
EOF
    success ".env файл создан с случайным SECRET_KEY"
else
    warning ".env файл уже существует, пропускаем..."
fi

echo ""
echo "Шаг 10/12: Создание systemd службы..."
cat > /etc/systemd/system/dmt.service << 'EOF'
[Unit]
Description=DMT Document Generation Service
After=network.target

[Service]
User=root
Group=root
WorkingDirectory=/var/www/dmt.expert
Environment="PATH=/var/www/dmt.expert/venv/bin"
Environment="FLASK_ENV=production"
ExecStart=/var/www/dmt.expert/venv/bin/gunicorn --workers 3 --bind 127.0.0.1:5000 app:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start dmt
systemctl enable dmt
success "Служба DMT создана и запущена"

echo ""
echo "Шаг 11/12: Настройка Nginx..."
cat > /etc/nginx/sites-available/dmt.expert << 'EOF'
server {
    listen 80;
    server_name dmt.expert www.dmt.expert;

    client_max_body_size 20M;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Увеличенные таймауты
        proxy_connect_timeout 600;
        proxy_send_timeout 600;
        proxy_read_timeout 600;
    }

    location /static {
        alias /var/www/dmt.expert/static;
    }
}
EOF

ln -sf /etc/nginx/sites-available/dmt.expert /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

nginx -t && systemctl restart nginx
success "Nginx настроен и перезапущен"

echo ""
echo "Шаг 12/12: Настройка firewall..."
apt install -y ufw
ufw --force enable
ufw allow OpenSSH
ufw allow 'Nginx Full'
success "Firewall настроен"

echo ""
echo "Создание дополнительных директорий..."
mkdir -p /var/www/dmt.expert/logs
mkdir -p /var/www/dmt.expert/created_docx
mkdir -p /backups
chmod 755 /var/www/dmt.expert/logs
chmod 755 /var/www/dmt.expert/created_docx
success "Директории созданы"

echo ""
echo ""
echo "🎉 Базовое развертывание завершено!"
echo ""
warning "ВАЖНЫЕ СЛЕДУЮЩИЕ ШАГИ:"
echo ""
echo "1️⃣  Настройте DNS для домена dmt.expert:"
echo "    - Создайте A-запись: @ -> 38.242.128.68"
echo "    - Создайте A-запись: www -> 38.242.128.68"
echo ""
echo "2️⃣  После настройки DNS (подождите 15-30 минут) установите SSL:"
echo "    sudo certbot --nginx -d dmt.expert -d www.dmt.expert"
echo ""
echo "3️⃣  Проверьте статус служб:"
echo "    sudo systemctl status dmt"
echo "    sudo systemctl status nginx"
echo ""
echo "4️⃣  Откройте в браузере:"
echo "    http://dmt.expert (сейчас)"
echo "    https://dmt.expert (после установки SSL)"
echo ""
success "Готово! 🚀"


