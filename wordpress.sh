#!/bin/bash

echo "============================================"
echo "Create database & user for WordPress"
echo "============================================"

# Default values
default_user="wp_"
default_pass="wordpress"
default_dbname="wp_"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -u|--user)
            user=$2
            shift 2
            ;;
        -p|--password)
            pass=$2
            shift 2
            ;;
        -db|--dbname)
            dbname=$2
            shift 2
            ;;
        *)
            echo "Invalid argument: $1"
            exit 1
            ;;
    esac
done

# Use default values or generate random string
user=${user:-$default_user}
pass=${pass:-$default_pass}
dbname=${dbname:-$default_dbname}

# Generate a random string if default values are used
if [[ $user == $default_user ]]; then
    user+="_$RANDOM"
fi

if [[ $pass == $default_pass ]]; then
    pass+="_$RANDOM"
fi

if [[ $dbname == $default_dbname ]]; then
    dbname+="_$RANDOM"
fi

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
chcon -R -t httpd_sys_rw_content_t /var/www/html/

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
chown -R wp-content/uploads
