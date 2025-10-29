#!/bin/bash

#it will create nginx config file link it to site-enabled. will create document root inside var/www and symlink that folder with a folder inside home directory.

tld=lrvl

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root or with sudo."
  exit 1
fi
# Check if a variable is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <variable>"
  exit 1
fi

# Assign variable from the first argument
VAR=$1

# Define the Nginx config path and content
CONFIG_PATH="/etc/nginx/sites-available/$VAR.$tld"
PROJECT_PATH="/home/kaisar/project/$VAR"
PUBLIC_PATH="/var/www/$VAR/public"

# Step 1: Create the project directory if it doesn't exist
if [ ! -d "$PROJECT_PATH" ]; then
  echo "Creating project directory at $PROJECT_PATH..."
  mkdir -p "$PROJECT_PATH"
  echo "Project directory created."
else
  echo "Project directory already exists at $PROJECT_PATH."
fi

# Create the Nginx config file
echo "Creating Nginx configuration file at $CONFIG_PATH..."

cat > "$CONFIG_PATH" <<EOL
server {
    listen 80;
    listen [::]:80;

    server_name $VAR.$tld;

    root /var/www/$VAR/public;
    index index.html index.php;

    # Increase client upload size limit
    client_max_body_size 1000M;

    # Handle CodeIgniter URL routing
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    # Handle PHP files
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;

        # PHP-FPM socket (adjust as needed for your version)
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;

        # Ensure the Authorization header is passed to PHP
        fastcgi_param HTTP_AUTHORIZATION \$http_authorization;

        # Pass the script filename to PHP-FPM
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    # Deny access to sensitive PHP file extensions
    location ~ /\.(php4|php5|php3|php2|php|phtml)$ {
        deny all;
    }

    # Serve static files directly (assets, uploads, etc.)
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|ttf|woff|woff2)$ {
        expires max;
        log_not_found off;
    }
}
EOL


echo "Nginx configuration file created."

# Create symlink in /etc/nginx/sites-enabled
echo "Creating symlink in sites-enabled..."
sudo ln -s "$CONFIG_PATH" "/etc/nginx/sites-enabled/$VAR.$tld"

# Create the project symlink in /var/www
echo "Creating symlink for project directory..."
sudo ln -s "$PROJECT_PATH" "/var/www/$VAR"

sudo chown -R kaisar:kaisar "$PROJECT_PATH"

NEW_LINE="127.0.0.1   $VAR.$tld"

# The file to modify
HOSTS_FILE="/etc/hosts"

# Check if the line already exists in the hosts file
if grep -q "$NEW_LINE" "$HOSTS_FILE"; then
  echo "The line already exists in the $HOSTS_FILE file."
else
  # Append the new line to the hosts file
  echo "$NEW_LINE" >> "$HOSTS_FILE"
  echo "Line added to $HOSTS_FILE."
fi

echo "Setup complete."
echo "Restarting nginx..."
systemctl restart nginx

if [ $? -eq 0 ]; then
  echo "nginx restarted successfully."
else
  echo "Failed to restart nginx."
fi

