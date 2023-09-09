#!/bin/bash

# Install Nginx or Apache based on user choice

# Choose web server (Nginx or Apache)
echo "Which web server would you like to install?"
echo "1. Nginx"
echo "2. Apache"
read -p "Enter your choice (1 or 2): " webserver_choice

if [ "$webserver_choice" -eq 1 ]; then
  # Install and configure Nginx
  dnf install -y nginx
  systemctl enable --now nginx
  webserver="nginx"
  certbot_package="python3-certbot-nginx"
elif [ "$webserver_choice" -eq 2 ]; then
  # Install and configure Apache
  dnf install -y httpd
  systemctl enable --now httpd
  webserver="httpd"
  certbot_package="python3-certbot-apache"
else
  echo "Invalid choice. Exiting."
  exit 1
fi

# Install necessary packages
dnf install -y epel-release
dnf install -y mariadb-server php php-fpm php-mysqlnd git certbot $certbot_package

# Enable and start MariaDB
systemctl enable --now mariadb

# Configure PHP-FPM
sed -i 's/;date.timezone =/date.timezone = Africa\/Nairobi/' /etc/php.ini
systemctl enable --now php-fpm

# Set up MySQL secure installation
mysql_secure_installation

# Enable and start the chosen web server
systemctl enable --now $webserver

# Set server and database timezone to Africa/Nairobi
timedatectl set-timezone Africa/Nairobi
mysql -e "SET GLOBAL time_zone = '+3:00';"

# Set up SSL using Certbot if a domain is provided
read -p "Enter your domain (e.g., example.com) or press Enter to skip: " domain
if [ -n "$domain" ]; then
  certbot --$webserver -d $domain

  conf_name=$(echo "$domain" | tr -s [:punct:] '_')

  if [ "$webserver" == "nginx" ]; then

            cat > /etc/nginx/conf.d/$conf_name.conf << EOF
            # Nginx configuration directives go here
            # Replace this with your desired configuration
            server {
                listen 80;
                server_name $domain

                location / {
                    root /var/www/html;
                    index index.html;
                }
            }
EOF


  elif [ "$webserver" == "httpd" ]; then
cat > /etc/httpd/conf.d/$conf_name.conf << EOF
# Apache configuration directives go here
# Replace this with your desired configuration
<VirtualHost *:80>
    ServerName $domain
    DocumentRoot /var/www/html

    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF
  fi
fi

if [ "$webserver" == "nginx" ]; then

cat > /etc/nginx/conf.d/server_security.conf << EOF
# Custom Server Security Measures
http {
    server {
        # Add the following directives inside your server block
        trace_enable off;
        server_tokens off;
        server_signature off;
        etag off;
        add_header X-Frame-Options SAMEORIGIN;
        add_header X-XSS-Protection "1; mode=block";
        add_header Set-Cookie HttpOnly Secure;
        add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";
        add_header Content-Security-Policy "default-src https: data: 'unsafe-inline' 'unsafe-eval'";
        add_header X-Content-Type-Options nosniff;

        # Your existing configuration goes here
        # ...
    }
}
EOF
  elif [ "$webserver" == "httpd" ]; then
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
  fi



# Install Composer globally
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php --install-dir=/usr/local/bin --filename=composer
php -r "unlink('composer-setup.php');"

mv composer.phar /usr/local/bin/composer

#git config credential.helper store

# Apply production-level security configurations
# Add your production security configurations here

echo "Installation and configuration completed successfully!"