#!/bin/bash

# Check if MariaDB is running
sudo service mariadb status > /dev/null 2>&1

# Restart the MariaDB service if it's not running.
if [ $? != 0 ]; then
    sudo service mariadb restart
fi