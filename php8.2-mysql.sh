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
sudo dnf install httpd mariadb-server php-fpm php-mysqlnd php-xml php-zip php-mbstring php-json php-curl php-gd php-pgsql git -y

# Configure PHP-FPM
sed -i 's/;date.timezone =/date.timezone = Africa\/Nairobi/' /etc/php.ini

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
user="db_user_agent"
pass="Pq)Ps+jb6aRT+Axn"
dbname="db_agents"

echo "Create database"
sudo mysql -e "CREATE DATABASE $dbname;"

echo "Creating new user..."
sudo mysql -e "CREATE USER '$user'@'localhost' IDENTIFIED BY '$pass';"
echo "User successfully created!"

echo "Granting ALL privileges on $dbname to $user!"
sudo mysql -e "GRANT ALL PRIVILEGES ON $dbname.* TO '$user'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"
echo "Success :)"


# Install Composer globally
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php --install-dir=/usr/local/bin --filename=composer
php -r "unlink('composer-setup.php');"

mv composer.phar /usr/local/bin/composer

git config credential.helper store

# Apply production-level security configurations
# Add your production security configurations here

echo "Installation and configuration completed successfully!"
cat > /etc/httpd/conf.d/server_security.conf << EOF
# Custom Server Security Measures
<IfModule mod_headers.c>
    <Location />
        # Add the following directives inside your Location block
        TraceEnable off
        ServerTokens Prod
        ServerSignature Off
        FileETag None
        Header always append X-Frame-Options SAMEORIGIN
        Header set X-XSS-Protection "1; mode=block"
        Header edit Set-Cookie ^(.*)$ $1;HttpOnly;Secure
        Header always set Strict-Transport-Security "max-age=63072000; includeSubdomains; preload"
        Header always set Content-Security-Policy "default-src https: data: 'unsafe-inline' 'unsafe-eval'"
        Header always set X-Content-Type-Options "nosniff"
    </Location>
</IfModule>
EOF

echo  "clone from git"

git clone 'https://github.com/StartappzKE/microsite.git' /var/www/html/.

chown -R apache:apache /var/www/html/
chmod -R 755 /var/www/html/
chcon -R -t httpd_sys_rw_content_t /var/www/html/

# Set server and database timezone to Africa/Nairobi
timedatectl set-timezone Africa/Nairobi
mysql -e "SET GLOBAL time_zone = '+3:00';"

domain_conf=${domain//[^a-zA-Z0-9]/_}

# Create VirtualHost configuration file
sudo tee /etc/httpd/conf.d/$domain_conf.conf <<EOF
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


# Prompt for Git configuration
read -p "Enter your Git username: " git_username
read -p "Enter your Git email address: " git_email

# Set Git global configuration
git config --global user.name "$git_username"
git config --global user.email "$git_email"
