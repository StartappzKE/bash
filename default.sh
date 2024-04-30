#!/bin/bash

if [ -z "$1" ]; then
    echo "Please provide the domain name as an argument."
    exit 1
fi

domain=$1
sudo yum install dnf -y
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
echo "Installing Firewalld and configuring"
echo "============================================"

# install firewalld
sudo yum install firewalld -y
#start firewalld
sudo systemctl start firewalld
#enable firewalld
sudo systemctl enable firewalld
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload


echo "============================================"
echo "Create database & user for WordPress"
echo "============================================"


# Ask user for database details
read -p "Enter database username: " user
read -sp "Enter database password: " pass
echo ""
read -p "Enter database name: " dbname
read -p "Enter host (default is localhost): " host

# If host is not provided, default to localhost
if [ -z "$host" ]; then
    host="localhost"
fi

# Create database if host is localhost
if [ "$host" == "localhost" ]; then
    echo "Create database"
    sudo mysql -e "CREATE DATABASE $dbname;"

    echo "Creating new user..."
    sudo mysql -e "CREATE USER '$user'@'$host' IDENTIFIED BY '$pass';"
    echo "User successfully created!"

    echo "Granting ALL privileges on $dbname to $user!"
    sudo mysql -e "GRANT ALL PRIVILEGES ON $dbname.* TO '$user'@'$host';"
    sudo mysql -e "FLUSH PRIVILEGES;"
    echo "Success :)"
fi


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
sudo sed -i "s/localhost/$host/g" wp-config.php

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


# Install Composer globally
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php --install-dir=/usr/local/bin --filename=composer
php -r "unlink('composer-setup.php');"

mv composer.phar /usr/local/bin/composer
ln -s /usr/local/bin/composer /usr/bin/composer

echo "============================================"
echo "Install Certbot and configure SSL"
echo "============================================"

# Ask user if they want to install SSL
read -p "Do you want to install SSL? (yes/no): " install_ssl

if [ "$install_ssl" == "yes" ]; then
    # Install necessary packages
    sudo dnf install epel-release
    sudo yum install certbot python3-certbot-apache -y

    # Obtain and install SSL certificate
    sudo certbot --apache -d $domain --redirect

    echo "SSL installed successfully!"
    echo "============================================"
    echo "Adding Autorenew of SSL"
    echo "============================================"

    # Define the cron schedule
    cron_schedule="0 12 * * *"

    # Add the autorenew script to the crontab
    (crontab -l 2>/dev/null; echo "$cron_schedule python -c 'import random; import time; time.sleep(random.random() * 3600)' && certbot renew") | sudo crontab -
else
    echo "SSL installation skipped."
fi

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
     Header always append X-Frame-Options SAMEORIGIN
        Header set X-XSS-Protection "1; mode=block"
        Header edit Set-Cookie ^(.*)$ $1;HttpOnly;Secure
        Header always set Strict-Transport-Security "max-age=63072000; includeSubdomains; preload"
        Header always set Content-Security-Policy "default-src https: data: 'unsafe-inline' 'unsafe-eval'"
        Header always set X-Content-Type-Options "nosniff"
</IfModule>
EOF

echo "============================================"
echo "Installation is complete."
echo "============================================"
