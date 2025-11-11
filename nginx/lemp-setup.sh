#!/bin/bash

# =========================================
# Automated LEMP Stack Setup Script
# =========================================

set -e  # Exit on error

# --------------------------
# Variables (customize)
# --------------------------
INSTALL_NODE=true
MYSQL_ROOT_PASS="maruf"
linux_user="maruf"
PHP_VERSION="8.3"
PHP_SECONDARY=true
PHP_SECONDARY_VERSION="8.2"

# --------------------------
# Update system
# --------------------------
echo "Updating system..."
sudo apt update -y

# --------------------------
# Install Nginx
# --------------------------
echo "Installing Nginx..."
sudo apt install nginx -y
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


# --------------------------
# Install PHP and extensions
# --------------------------
echo "Installing PHP ${PHP_VERSION} and extensions..."
sudo apt install software-properties-common -y
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update -y
sudo apt install php${PHP_VERSION} php${PHP_VERSION}-fpm php${PHP_VERSION}-cli php${PHP_VERSION}-mysql php${PHP_VERSION}-curl php${PHP_VERSION}-gd php${PHP_VERSION}-mbstring php${PHP_VERSION}-imagick php${PHP_VERSION}-bcmath php${PHP_VERSION}-xml php${PHP_VERSION}-zip php${PHP_VERSION}-intl -y

#Installing composer...
sudo apt install composer -y

# Start and enable PHP-FPM
sudo systemctl start php${PHP_VERSION}-fpm
sudo systemctl enable php${PHP_VERSION}-fpm


install_second_php() {
    echo "Installing $PHP_SECONDARY_VERSION ..."
    
    sudo apt install php${PHP_SECONDARY_VERSION} php${PHP_SECONDARY_VERSION}-fpm php${PHP_SECONDARY_VERSION}-cli php${PHP_SECONDARY_VERSION}-mysql php${PHP_SECONDARY_VERSION}-curl php${PHP_SECONDARY_VERSION}-gd php${PHP_SECONDARY_VERSION}-mbstring php${PHP_SECONDARY_VERSION}-imagick php${PHP_SECONDARY_VERSION}-bcmath php${PHP_SECONDARY_VERSION}-xml php${PHP_SECONDARY_VERSION}-zip php${PHP_SECONDARY_VERSION}-intl -y

    sudo systemctl start php${PHP_SECONDARY_VERSION}-fpm
    sudo systemctl enable php${PHP_SECONDARY_VERSION}-fpm
}

if [ "$PHP_SECONDARY" = true ]; then
    install_second_php
else
    echo "Skipping secondary php installation."
fi


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

# add linux user to www-data group and vice-versa
sudo usermod -aG www-data $linux_user
sudo usermod -aG $linux_user www-data

# Test Nginx configuration
sudo nginx -t



# --------------------------
# Restart services
# --------------------------
sudo systemctl restart nginx
sudo systemctl restart mysql
sudo systemctl restart php${PHP_VERSION}-fpm


install_node() {
    echo "Installing CURL..."
    sudo apt install curl -y
    echo "Installing NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

    # Load NVM into current shell session
    export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    echo "Installing Node.js 20..."
    nvm install 20
    nvm use 20
    nvm alias default 20

    echo "Node.js version installed: $(node -v)"
}

if [ "$INSTALL_NODE" = true ]; then
    install_node
else
    echo "Skipping NVM and Node.js installation."
fi

echo "======================================"
echo "LEMP Stack installation complete!"
echo "MySQL root password: ${MYSQL_ROOT_PASS}"
echo "PHP Version: ${PHP_VERSION}"
echo "======================================"

