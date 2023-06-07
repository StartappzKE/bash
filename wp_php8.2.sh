#!/bin/bash

if [ -z "$1" ]; then
    echo "Please provide the domain name as an argument."
    exit 1
fi

domain=$1

echo "Updating the OS. This may take a couple of minutes..."
sudo dnf upgrade --refresh

echo "============================================"
echo "Install LEMP stack with bash"
echo "============================================"

echo "Install EPEL repository"
sudo yum install epel-release -y

echo "Install Remi repository"
sudo yum install http://rpms.remirepo.net/enterprise/remi-release-8.rpm -y

# PHP 8.2 installation
echo "============================================"
echo "Installing PHP 8.2"
echo "============================================"

echo "Enabling EPEL repository..."
sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm

echo "Installing Remi repository..."
sudo dnf install -y https://rpms.remirepo.net/enterprise/remi-release-8.rpm

echo "Listing available PHP module streams..."
sudo dnf module list php

echo "Enabling php:remi-8.2 module..."
sudo dnf module enable php:remi-8.2 -y

echo "Installing PHP and PHP modules..."
sudo dnf install -y php php-cli php-common

echo "PHP installation completed."

# LEMP stack installation continues...
echo "Install required packages"
sudo yum install httpd mariadb-server php-fpm php-mysqlnd php-xml php-zip php-mbstring php-json php-curl php-gd php-pgsql -y

echo "Start services"
sudo systemctl start httpd
sudo systemctl start mariadb

echo "Enable services"
sudo systemctl enable httpd
sudo systemctl enable mariadb

echo "Check service status"
echo "Apache service status: $(sudo systemctl is-active httpd)"
echo "Database service status: $(sudo systemctl is-active mariadb)"

echo "============================================"
echo "Create database & user for WordPress"
echo "============================================"

# Variables for database
user="wp_user"
pass="Pq)Ps+jb6aRT+Axn"
dbname="wp_db"

echo "Create database"
sudo mysql -e "CREATE DATABASE $dbname;"

echo "Creating new user..."
sudo mysql -e "CREATE USER '$user'@'localhost' IDENTIFIED BY '$pass';"
echo "User successfully created!"

echo "Granting ALL privileges on $dbname to $user!"
sudo mysql -e "GRANT ALL PRIVILEGES ON $dbname.* TO '$user'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"
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
sudo chown -R apache:apache /var/www/html/
sudo chmod -R 755 /var/www/html/
sudo chcon -R -t httpd_sys_rw_content_t /var/www/html/

# Create wp-config.php
cd /var/www/html/
sudo cp wp-config-sample.php wp-config.php
sudo chown apache:apache wp-config.php

# Set database details with sed find and replace
sudo sed -i "s/database_name_here/$dbname/g" wp-config.php
sudo sed -i "s/username_here/$user/g" wp-config.php
sudo sed -i "s/password_here/$pass/g" wp-config.php

# Set WP salts
curl -s https://api.wordpress.org/secret-key/1.1/salt/ >> wp-config.php

# Create uploads folder and set permissions
sudo mkdir wp-content/uploads
sudo chmod 775 wp-content/uploads
sudo chown -R apache:apache wp-content/uploads

echo "============================================"
echo "Create VirtualHost for WordPress"
echo "============================================"

# Create VirtualHost configuration file
sudo tee /etc/httpd/conf.d/wordpress.conf <<EOF
<VirtualHost *:80>
    ServerAdmin admin@$domain
    ServerName $domain
    DocumentRoot /var/www/html
    ErrorLog /var/log/httpd/error.log
    CustomLog /var/log/httpd/access.log combined

    <Directory /var/www/html/>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

echo "============================================"
echo "Install Certbot and configure SSL"
echo "============================================"

# Install Certbot and Apache plugin
sudo yum install certbot python3-certbot-apache -y

# Obtain and install SSL certificate
sudo certbot --apache -d $domain --redirect

echo "============================================"
echo "Adding Autorenew of SSL"
echo "============================================"

# Define the cron schedule
cron_schedule="0 12 * * *"

# Add the autorenew script to the crontab
(crontab -l 2>/dev/null; echo "$cron_schedule python -c 'import random; import time; time.sleep(random.random() * 3600)' && certbot renew") | sudo crontab -

echo "Add send mail configurations"
sudo yum install policycoreutils-python-utils
sudo semanage permissive -a httpd_t
sudo audit2allow -a -M httpd_sendmail
sudo semodule -i httpd_sendmail.pp

echo "============================================"
echo "Configuring additional security features"
echo "============================================"

sudo tee /etc/httpd/conf.d/security.conf <<EOF
TraceEnable off
ServerSignature Off
ServerTokens Prod
FileETag None

<IfModule mod_headers.c>
    Header always set X-Frame-Options "SAMEORIGIN"
</IfModule>
EOF

echo "============================================"
echo "Installation is complete."
echo "============================================"
