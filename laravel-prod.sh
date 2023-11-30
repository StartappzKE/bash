#!/bin/bash

if [ -z "$1" ]; then
      echo "Please provide the laravel directory as an argument."

     #exit 1
     LARAVEL_DIR="/var/www/html/your-laravel-app"

     echo "Default Path is $LARAVEL_DIR"

fi

LARAVEL_DIR=$1

# Laravel deployment script for CentOS

# Define your Laravel project directory and environment file
#LARAVEL_DIR="/var/www/html/your-laravel-app"
ENV_FILE="$LARAVEL_DIR/.env"

# Replace these with your database credentials
DB_HOST="localhost"
DB_DATABASE="your_database"
DB_USERNAME="your_username"
DB_PASSWORD="your_password"

# Ensure the Laravel directory exists
if [ ! -d "$LARAVEL_DIR" ]; then
    echo "Laravel directory not found. Please check the directory path."
    exit 1
fi

# Edit .env file with database credentials
sed -i "s/DB_HOST=.*/DB_HOST=$DB_HOST/" "$ENV_FILE"
sed -i "s/DB_DATABASE=.*/DB_DATABASE=$DB_DATABASE/" "$ENV_FILE"
sed -i "s/DB_USERNAME=.*/DB_USERNAME=$DB_USERNAME/" "$ENV_FILE"
sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$DB_PASSWORD/" "$ENV_FILE"

# Set proper permissions
chown -R apache:apache "$LARAVEL_DIR" # Change 'apache' to your web server user
chmod -R 755 "$LARAVEL_DIR/storage"
chmod -R 755 "$LARAVEL_DIR/bootstrap/cache"

# Install Composer dependencies
cd "$LARAVEL_DIR"
composer install --no-dev --optimize-autoloader

# Generate application key
php artisan key:generate

# Perform any other setup tasks you need, such as running migrations and seeders
# php artisan migrate --seed

# Restart your web server
systemctl restart httpd # For Apache

echo "Laravel application deployed successfully!"