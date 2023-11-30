#!/bin/bash

# Check if httpd is running
if systemctl is-active --quiet httpd; then
    echo "httpd is running."
else
    echo "httpd is not running. Restarting..."
    systemctl restart httpd
    echo "httpd restarted."
fi