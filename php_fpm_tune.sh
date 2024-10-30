#!/bin/bash

# Check if the user is root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

# Get server memory information
TOTAL_MEM=$(free -m | awk '/Mem:/ {print $2}')
CPU_CORES=$(nproc)

# Set pm.max_children based on the total memory
# Formula: Total Memory / 25MB per child (avg PHP-FPM process size)
if [ $TOTAL_MEM -le 1024 ]; then
    MAX_CHILDREN=40  # For 1GB RAM
elif [ $TOTAL_MEM -le 2048 ]; then
    MAX_CHILDREN=80  # For 2GB RAM
elif [ $TOTAL_MEM -le 4096 ]; then
    MAX_CHILDREN=160 # For 4GB RAM
else
    MAX_CHILDREN=320 # For 8GB+ RAM
fi

# Check if the www.conf file exists
FPM_CONF="/etc/php-fpm.d/www.conf"
if [ ! -f "$FPM_CONF" ]; then
    echo "PHP-FPM configuration file not found at $FPM_CONF"
    exit 1
fi

# Backup the original www.conf file
cp "$FPM_CONF" "$FPM_CONF.bak"

# Update the www.conf file with the new settings
sed -i "s/^pm.max_children = .*/pm.max_children = $MAX_CHILDREN/" "$FPM_CONF"
sed -i "s/^pm.start_servers = .*/pm.start_servers = $(($MAX_CHILDREN / 4))/" "$FPM_CONF"
sed -i "s/^pm.min_spare_servers = .*/pm.min_spare_servers = $(($MAX_CHILDREN / 4))/" "$FPM_CONF"
sed -i "s/^pm.max_spare_servers = .*/pm.max_spare_servers = $(($MAX_CHILDREN / 2))/" "$FPM_CONF"
sed -i "s/^request_terminate_timeout = .*/request_terminate_timeout = 300/" "$FPM_CONF"

echo "PHP-FPM configuration updated: pm.max_children = $MAX_CHILDREN"
echo "pm.start_servers = $(($MAX_CHILDREN / 4)), pm.min_spare_servers = $(($MAX_CHILDREN / 4)), pm.max_spare_servers = $(($MAX_CHILDREN / 2))"

# Restart PHP-FPM and Apache
echo "Restarting PHP-FPM and Apache services..."
systemctl restart php-fpm
systemctl restart httpd

# Check for Apache and PHP-FPM logs
echo "Checking Apache and PHP-FPM error logs..."

APACHE_LOG="/var/log/httpd/error_log"
PHP_FPM_LOG="/var/log/php-fpm/www-error.log"

echo "---- Apache Error Log ----"
tail -n 20 "$APACHE_LOG"

echo "---- PHP-FPM Error Log ----"
tail -n 20 "$PHP_FPM_LOG"

# Check system resource usage
echo "---- System Resource Usage ----"
echo "CPU cores: $CPU_CORES"
echo "Total Memory: ${TOTAL_MEM}MB"

echo "Monitoring services for any issues... Please check logs for further details."
