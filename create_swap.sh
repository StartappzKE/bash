#!/bin/bash

# Check if count argument is provided, otherwise use double the current memory
if [[ $# -eq 0 ]]; then
  mem_total=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
  count=$((mem_total * 2))
else
  count=$1
fi

# Create a swap file with the specified count
echo "Creating swap file..."
dd if=/dev/zero of=/swapfile bs=1G count=$count
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

# Add entry in fstab to load swap on boot
echo "/swapfile none swap sw 0 0" >> /etc/fstab

# Configure sysctl settings for swappiness and vfs_cache_pressure
echo "Setting sysctl settings..."
sysctl vm.swappiness=10
sysctl vm.vfs_cache_pressure=50

# Update sysctl.conf to persist sysctl settings across reboots
echo "vm.swappiness=10" >> /etc/sysctl.conf
echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf

echo "Swap file created successfully."