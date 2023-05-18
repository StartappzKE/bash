#!/bin/bash

# Check if username and password are provided as arguments
if [ $# -ne 2 ]; then
    echo "Usage: $0 <username> <password>"
    exit 1
fi

username=$1
password=$2

echo "============================================"
echo "Disabling root login"
echo "============================================"

# Disable root login by setting PermitRootLogin to no in SSH config
if [ -f /etc/ssh/sshd_config ]; then
    sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
fi

# Restart SSH service
if command -v systemctl >/dev/null; then
    sudo systemctl restart sshd
else
    sudo service ssh restart
fi

echo "Root login disabled"

echo "============================================"
echo "Creating new user"
echo "============================================"

# Create new user
sudo useradd -m $username

# Set password for the new user
echo "$username:$password" | sudo chpasswd

echo "New user created"

echo "============================================"
echo "User Configuration"
echo "============================================"

# Add new user to sudoers (Ubuntu)
if [ -f /etc/sudoers.d/$username ]; then
    sudo rm /etc/sudoers.d/$username
fi
echo "$username ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$username >/dev/null

# Add new user to wheel group (CentOS)
if [ -f /etc/group ]; then
    sudo usermod -aG wheel $username
fi

echo "User configuration updated"

echo "============================================"
echo "Script execution complete"
echo "============================================"
