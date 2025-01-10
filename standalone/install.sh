#!/usr/bin/env bash

# Install the standalone version of the app

# 1. Detect the OS

OS_NAME=$(uname -s | tr '[:upper:]' '[:lower:]')
OS_VERS=$(uname -r | tr '[:upper:]' '[:lower:]')
OS_TYPE=$(uname -n | tr '[:upper:]' '[:lower:]')
OS_ARCH=$(uname -m | tr '[:upper:]' '[:lower:]')

# Print the OS information
echo "OS Name: $OS_NAME ($OS_VERS)"
echo "OS Type: $OS_TYPE"
echo "OS Arch: $OS_ARCH"

# 2. If OS is linux centos, debian or ubuntu
supported_os=("centos" "debian" "ubuntu", "darwin")
if [[ " ${supported_os[@]} " =~ " ${OS_NAME} " ]]; then
    echo "Install on $OS_NAME"
    # 3.1 run install script.sh from ./systems directory
    ./systems/${OS_NAME}.sh
else
    echo "Unsupported OS ${OS_NAME}"
    exit 1
fi
