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
read -p "Enter the database user: " db_user
read -p "Enter the database password: " db_pass
read -p "Enter the database name: " db_name

if [ -z "$db_user" ] || [ -z "$db_pass" ] || [ -z "$db_name" ]; then
    echo "Please provide the database user, password, and name."
    exit 1
fi


echo "You entered the following details:"
echo "Database user: $db_user"
echo "Database password: $db_pass"
echo "Database name: $db_name"

echo "Create database"
mysql -e "CREATE DATABASE $db_name;"

echo "Creating new user..."
mysql -e "CREATE USER '$db_user'@'localhost' IDENTIFIED BY '$db_pass';"
echo "User successfully created!"


echo "Granting ALL privileges on $db_name to $db_user!"
sudo mysql -e "GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"
echo "Success :)"


# Install Composer globally
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php --install-dir=/usr/local/bin --filename=composer
php -r "unlink('composer-setup.php');"

mv composer.phar /usr/local/bin/composer

ln -s /usr/local/bin/composer /usr/bin/composer

git config credential.helper store

# Apply production-level security configurations
# Add your production security configurations here

echo "Installation and configuration completed successfully!"
cat > /etc/httpd/conf.d/server_security.conf << EOF
# Custom Server Security Measures
<IfModule mod_headers.c>
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
</IfModule>
EOF

echo  "clone from git"
read -p "Repo/Git Url " git_url

if [ -z "$git_url" ]; then
    echo "Please provide the git url"
    exit 1
fi

read -p "Path to clone to " path 

if [ -z "$path" ]; then
    path = /var/www/html/
fi

git clone $git_url $path/.

chown -R apache:apache $path
chmod -R 755 $path
chcon -R -t httpd_sys_rw_content_t $path

# Set server and database timezone to Africa/Nairobi
timedatectl set-timezone Africa/Nairobi
mysql -e "SET GLOBAL time_zone = '+3:00';"

domain_conf=${domain//[^a-zA-Z0-9]/_}

# Create VirtualHost configuration file
sudo tee /etc/httpd/conf.d/$domain_conf.conf <<EOF
<VirtualHost *:80>
    ServerAdmin admin@$domain
    ServerName $domain
    DocumentRoot $path
    ErrorLog /var/log/httpd/error.log
    CustomLog /var/log/httpd/access.log combined

    <Directory $path>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

#Add https and http to the firewall
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload

# Prompt for Git configuration
#read -p "Enter your Git username: " git_username
#read -p "Enter your Git email address: " git_email

# Set Git global configuration
#git config --global user.name "$git_username"
#git config --global user.email "$git_email"

sudo setsebool -P httpd_can_network_connect_db 1
sudo setsebool -P httpd_can_sendmail 1
sudo setsebool -P httpd_can_network_connect 1

#install certbot
sudo dnf install certbot python3-certbot-apache -y

# Obtain and install SSL certificate
sudo certbot --apache -d $domain --redirect

# Adding Autorenew of SSL
sudo systemctl enable certbot-renew.timer
sudo systemctl start certbot-renew.timer

echo "============================================"
echo "Adding Autorenew of SSL"
echo "============================================"

# Define the cron schedule
cron_schedule="0 12 * * *"

# Add the autorenew script to the crontab
(crontab -l 2>/dev/null; echo "$cron_schedule python -c 'import random; import time; time.sleep(random.random() * 3600)' && certbot renew") | sudo crontab -

#would you like to install nodejs
read -p "Would you like to install nodejs? (y/n) " nodejs
if [ "$nodejs" == "y" ]; then
   
   # Install Node.js and npm
   #list available nodejs streams
    sudo dnf module list nodejs

    # Enable the desired Node.js stream ask for the version 
    read -p "Enter the Node.js version you want to install: " node_version
    
    sudo dnf module install nodejs:$node_version -y
    #sudo dnf module enable nodejs:$node_version -y

    echo "Node.js and npm installation completed."
fi



echo "Installation and configuration completed successfully!"