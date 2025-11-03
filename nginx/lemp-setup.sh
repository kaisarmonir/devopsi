#!/bin/bash

# =========================================
# Automated LEMP Stack Setup Script
# =========================================

set -e  # Exit on error

# --------------------------
# Variables (customize)
# --------------------------
DB_NAME="mydatabase"
DB_USER="sakib"
DB_PASS="sakib"
MYSQL_ROOT_PASS="sakib"
PHP_VERSION="8.3"

# --------------------------
# Update system
# --------------------------
echo "Updating system..."
sudo apt update -y

# --------------------------
# Install Nginx
# --------------------------
echo "Installing Nginx..."
#sudo apt install nginx -y
sudo systemctl start nginx
sudo systemctl enable nginx
echo "Nginx installed."

# --------------------------
# Install MySQL
# --------------------------
echo "Installing MySQL..."
sudo apt install mysql-server -y
sudo systemctl start mysql
sudo systemctl enable mysql

# Secure MySQL
echo "Securing MySQL..."
sudo mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASS}';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

# Create database and user
echo "Creating database and user..."
sudo mysql -u root -p"${MYSQL_ROOT_PASS}" <<EOF
CREATE DATABASE ${DB_NAME};
CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

# --------------------------
# Install PHP and extensions
# --------------------------
echo "Installing PHP ${PHP_VERSION} and extensions..."
sudo apt install software-properties-common -y
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update -y
sudo apt install php${PHP_VERSION} php${PHP_VERSION}-fpm php${PHP_VERSION}-cli php${PHP_VERSION}-mysql php${PHP_VERSION}-curl php${PHP_VERSION}-gd php${PHP_VERSION}-mbstring php${PHP_VERSION}-imagick php${PHP_VERSION}-bcmath php${PHP_VERSION}-xml php${PHP_VERSION}-zip php${PHP_VERSION}-intl -y

# Start and enable PHP-FPM
sudo systemctl start php${PHP_VERSION}-fpm
sudo systemctl enable php${PHP_VERSION}-fpm

# --------------------------
# Configure Nginx for PHP
# --------------------------
echo "Configuring Nginx to use PHP..."
NGINX_CONF="/etc/nginx/sites-available/default"

sudo cp $NGINX_CONF ${NGINX_CONF}.bak

sudo tee $NGINX_CONF > /dev/null <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.php index.html index.htm index.nginx-debian.html;

    server_name _;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

sudo nginx -t
sudo systemctl reload nginx



# --------------------------
# Install phpMyAdmin
# --------------------------
echo "Installing phpMyAdmin..."

# Download latest phpMyAdmin
cd /usr/share
sudo wget https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz
sudo tar xzf phpMyAdmin-latest-all-languages.tar.gz
sudo rm phpMyAdmin-latest-all-languages.tar.gz
sudo mv phpMyAdmin-*-all-languages phpmyadmin

# Create phpMyAdmin tmp directory
sudo mkdir -p /usr/share/phpmyadmin/tmp
sudo chown -R www-data:www-data /usr/share/phpmyadmin
sudo chmod 777 /usr/share/phpmyadmin/tmp

# Create Nginx site for phpMyAdmin
echo "Configuring Nginx site for phpMyAdmin..."
sudo tee /etc/nginx/sites-available/phpmyadmin.conf > /dev/null <<EOF
server {
    listen 8080;
    server_name _;

    root /usr/share/phpmyadmin;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# Enable phpMyAdmin site
sudo ln -s /etc/nginx/sites-available/phpmyadmin.conf /etc/nginx/sites-enabled/phpmyadmin.conf

# Test Nginx configuration
sudo nginx -t



# --------------------------
# Restart services
# --------------------------
sudo systemctl restart nginx
sudo systemctl restart mysql
sudo systemctl restart php${PHP_VERSION}-fpm

echo "======================================"
echo "LEMP Stack installation complete!"
echo "MySQL root password: ${MYSQL_ROOT_PASS}"
echo "Database: ${DB_NAME}, User: ${DB_USER}, Password: ${DB_PASS}"
echo "PHP Version: ${PHP_VERSION}"
echo "======================================"

