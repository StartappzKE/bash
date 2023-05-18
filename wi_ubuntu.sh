#!/bin/bash
echo "============================================"
echo "Install LEMP stack with bash"
echo "============================================"

echo "Add repository for PHP 7.4"
sudo apt install software-properties-common -y
sudo add-apt-repository ppa:ondrej/php -y

echo "Update packages"
sudo apt-get update -y

echo "Install Apache web server"
sudo apt install apache2 -y

echo "Install database"
sudo apt install mysql-server -y

echo "Install PHP and required modules"
sudo apt install php7.4-fpm php7.4-common php7.4-xml php7.4-zip php7.4-mysql php7.4-mbstring php7.4-json php7.4-curl php7.4-gd php7.4-pgsql -y

echo "Start services"
sudo systemctl restart apache2
sudo systemctl restart mysql

echo "Enable services"
sudo systemctl enable apache2
sudo systemctl enable mysql

echo "Check service status"
echo "Apache service status: $(systemctl show -p ActiveState --value apache2)"
echo "Database service status: $(systemctl show -p ActiveState --value mysql)"

echo "============================================"
echo "Create database & user for WordPress"
echo "============================================"

# Variables for database
user="wp_user"
pass="wordpress123513"
dbname="wp_db"

echo "Create database"
mysql -e "CREATE DATABASE $dbname;"

echo "Creating new user..."
mysql -e "CREATE USER '$user'@'localhost' IDENTIFIED BY '$pass';"
echo "User successfully created!"

echo "Granting ALL privileges on $dbname to $user!"
mysql -e "GRANT ALL PRIVILEGES ON $dbname.* TO '$user'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"
echo "Success :)"

echo "============================================"
echo "Install WordPress using Bash Script"
echo "============================================"

# Download WordPress
curl -O https://wordpress.org/latest.tar.gz

# Unzip WordPress
tar -zxvf latest.tar.gz

# Move WordPress files to web server root
sudo mv wordpress/* /var/www/html/

# Change ownership and permissions
sudo chown -R www-data:www-data /var/www/html/
sudo chmod -R 755 /var/www/html/

# Create wp-config.php
cd /var/www/html/
sudo cp wp-config-sample.php wp-config.php
sudo chown www-data:www-data wp-config.php

# Set database details with sed find and replace
sudo sed -i "s/database_name_here/$dbname/g" wp-config.php
sudo sed -i "s/username_here/$user/g" wp-config.php
sudo sed -i "s/password_here/$pass/g" wp-config.php

# Set WP salts
curl -s https://api.wordpress.org/secret-key/1.1/salt/ >> wp-config.php

# Create uploads folder and set permissions
sudo mkdir wp-content/uploads
sudo chmod 775 wp-content/uploads

echo "============================================"
echo "Install Certbot and configure SSL"
echo "============================================"

# Install Certbot and Apache plugin
sudo apt install certbot python3-certbot-apache -y

# Set your domain name
domain="example.com"

# Obtain and install SSL certificate
sudo certbot run -n --apache --agree-tos -d $domain -m admin@$domain --redirect

echo "========================="
echo "Installation is complete."
echo "========================="