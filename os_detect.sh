#!/bin/bash

# Function to detect the operating system
get_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo $ID
    elif [ -f /etc/redhat-release ]; then
        echo "centos"
    else
        echo "unknown"
    fi
}

# Detect the operating system
os=$(get_os)

# Execute script based on the detected OS
case $os in
    "ubuntu")
        echo "Detected Ubuntu"
        # Execute Ubuntu script here
        sh ubuntu_script.sh
        ;;
    "centos")
        echo "Detected CentOS"
        # Execute CentOS script here
        sh centos_script.sh
        ;;
    *)
        echo "Unsupported operating system: $os"
        ;;
esac