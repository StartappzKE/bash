#!/bin/bash
echo "============================================"
echo "Install LEMP stack with bash"
echo "============================================"

echo "Install EPEL repository"
yum install epel-release -y

echo "Install Remi repository"
yum install http://rpms.remirepo.net/enterprise/remi-release-8.rpm -y

echo "Install required packages"
yum install httpd mariadb-server php php-cli php-fpm php-common php-mysqlnd php-xml php-zip php-mbstring php-json php-curl php-gd php-pgsql -y

echo "Start services"
systemctl start httpd
systemctl start mariadb

echo "Enable services"
systemctl enable httpd
systemctl enable mariadb

echo "Check service status"
echo "Apache service status: $(systemctl is-active httpd)"
echo "Database service status: $(systemctl is-active mariadb)"

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
mv wordpress/* /var/www/html/

# Change ownership and permissions
chown -R apache:apache /var/www/html/
chmod -R 755 /var/www/html/

# Create wp-config.php
cd /var/www/html/
cp wp-config-sample.php wp-config.php
chown apache:apache wp-config.php

# Set database details with sed find and replace
sed -i "s/database_name_here/$dbname/g" wp-config.php
sed -i "s/username_here/$user/g" wp-config.php
sed -i "s/password_here/$pass/g" wp-config.php

# Set WP salts
curl -s https://api.wordpress.org/secret-key/1.1/salt/ >> wp-config.php

# Create uploads folder and set permissions
mkdir wp-content/uploads
chmod 775 wp-content/uploads

echo "============================================"
echo "Install Certbot and configure SSL"
echo "============================================"

# Install Certbot and Apache plugin
yum install certbot python3-certbot-apache -y

# Set your domain name
domain="example.com"

# Obtain and install SSL certificate
certbot run -n --apache --agree-tos -d $domain -m admin@$domain --redirect

echo "========================="
echo "Installation is complete."
echo "========================="
