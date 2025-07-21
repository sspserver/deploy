#!/usr/bin/env bash

###############################################################################
# SSP Server Ubuntu Installation Script
# 
# Description: Automated installation script for SSP Server on Ubuntu/Debian systems
# Author: SSP Server Team
# Version: 1.0
# Platform: Ubuntu/Debian with systemd
#
# This script performs the following operations:
# - Installs system dependencies (curl, unzip, jq, git, build-essential)
# - Sets up systemd service manager for process management
# - Installs Docker CE and Docker Compose for containerization
# - Downloads and configures SSP Server service files
# - Configures domain settings through interactive prompts
# - Installs and starts SSP Server as a systemd service
#
# Requirements:
# - Ubuntu/Debian Linux distribution
# - Root or sudo privileges
# - Internet connectivity for package downloads
# - systemd service manager
#
# Usage:
#   sudo ./ubuntu.sh
#
# Log files:
#   /var/log/sspserver/sspserver_1click_standalone.log
#
# Service management:
#   systemctl status sspserver
#   systemctl start|stop|restart sspserver
#   journalctl -u sspserver -f
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

LOG_DIR="/var/log/sspserver"
LOG_FILE="${LOG_DIR}/sspserver_1click_standalone.log"

INSTALL_DIR="/opt/sspserver"
SYSTEMD_SERVICE_DIR="/etc/systemd/system"
OS_NAME="ubuntu"

DOWNLOAD_STANDALONE_URI="https://github.com/sspserver/deploy/raw/refs/heads/build/standalone/ubuntu.zip"

mkdir -p "${LOG_DIR}"
mkdir -p "${INSTALL_DIR}"

# Auto-confirmation mode (skip interactive prompts)
AUTO_YES=${AUTO_YES:-false}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--yes)
            AUTO_YES=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [-y|--yes] [-h|--help]"
            echo "  -y, --yes    Auto-confirmation mode (skip interactive prompts)"
            echo "  -h, --help   Show this help message"
            exit 0
            ;;
        *)
            log "error" "Unknown option: $1" "+"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Function: log
# Description: Universal logging function with message type support
# Parameters:
#   $1 - message type: "error", "info", "ok"
#   $2 - log message string
#   $3 - optional "+" flag to also display message on stdout
# Returns: None
# Example: log "error" "Installation failed" "+"
#          log "info" "Starting installation"
#          log "ok" "Installation completed" "+"
log () {
    local message_type="$1"
    local message="$2"
    local display_flag="$3"
    
    # Format message with type prefix
    local formatted_message=""
    case "$message_type" in
        "error")
            formatted_message="${RED}[ERROR]${NC} $message"
            ;;
        "info")
            formatted_message="${BLUE}[INFO]${NC} $message"
            ;;
        "ok")
            formatted_message="${GREEN}[OK]${NC} $message"
            ;;
        *)
            formatted_message="[UNKNOWN] $message"
            ;;
    esac
    
    # Write to log file
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -" >> "${LOG_FILE}"
    echo "$(date '+%d-%m-%Y %H:%M:%S') $formatted_message" >> "${LOG_FILE}"
    
    # Display on stdout if requested
    if [ "$display_flag" == "+" ]; then
        echo -e "$(date '+%d-%m-%Y %H:%M:%S') $formatted_message"
    fi
}

## Project dependencies
# * curl
# * unzip
# * jq
# * git
# * build-essential
# * ca-certificates
# * gnupg
# * lsb-release
# * systemd

# Function: install_dependencies
# Description: Installs required system dependencies for SSP Server on Ubuntu
# Parameters: None
# Returns: None
# Dependencies: apt-get package manager, system utilities
# Note: Installs curl, unzip, jq, git, build-essential, and other required packages
install_dependencies () {
    log "info" "Installing dependencies..." "+"

    # Check if apt-get is available
    if ! command -v apt-get &> /dev/null; then
        log "error" "apt-get not found, please install it first." "+"
        exit 1
    fi

    # Update package list and install dependencies
    log "info" "Updating package list..." "+"
    apt-get -y update >> "${LOG_FILE}" 2>&1

    log "info" "Installing dependencies..." "+"
    apt-get -y install \
        curl \
        unzip \
        jq \
        git \
        build-essential \
        ca-certificates \
        gnupg \
        lsb-release >> "${LOG_FILE}" 2>&1
}

# Function: install_systemd_dependency
# Description: Installs and configures systemd service manager for Ubuntu
# Parameters: None
# Returns: None
# Dependencies: apt-get package manager, systemctl command
# Note: Ensures systemd is installed, running, and enabled for boot
install_systemd_dependency () {
    log "info" "Installing systemd dependency..." "+"
    {
        apt-get -y install systemd
    } >> "${LOG_FILE}" 2>&1
    if [[ $? -ne 0 ]]; then
        log "error" "Failed to install systemd dependency" "+"
        exit 1
    else
        log "ok" "Systemd dependency installed successfully" "+"
    fi
    # Check if systemd is running
    if ! systemctl is-active --quiet systemd; then
        log "info" "Systemd is not running, starting it..." "+"
        systemctl start systemd
        if [[ $? -ne 0 ]]; then
            log "error" "Failed to start systemd" "+"
            exit 1
        else
            log "ok" "Systemd started successfully" "+"
        fi
    else
        log "ok" "Systemd is already running" "+"
    fi
    # Check if systemd is enabled to start on boot
    if ! systemctl is-enabled --quiet systemd; then
        log "info" "Enabling systemd to start on boot..." "+"
        systemctl enable systemd
        if [[ $? -ne 0 ]]; then
            log "error" "Failed to enable systemd" "+"
            exit 1
        else
            log "ok" "Systemd enabled successfully" "+"
        fi
    else
        log "ok" "Systemd is already enabled to start on boot" "+"
    fi
}

# Function: install_docker
# Description: Installs Docker Engine and Docker Compose on Ubuntu
# Parameters: None
# Returns: None
# Dependencies: apt-get, curl, systemctl, Ubuntu package repositories
# Note: Sets up Docker repository, installs Docker CE, configures logging and journald
install_docker () {
    log "info" "Installing docker..." "+"
    if ! [[ -f /etc/apt/keyrings/docker.gpg ]]; then
        {
            mkdir -p /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg >> "${LOG_FILE}" 2>&1
            chmod a+r /etc/apt/keyrings/docker.gpg
        } >> "${LOG_FILE}" 2>&1
    fi
    if ! [[ -f /etc/apt/sources.list.d/docker.list ]]; then
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
    fi
    # If docker command not found, install compose
    if ! command -v docker &> /dev/null; then
        log "info" "Installing docker cli..." "+"
        {
            apt-get -y update
            apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        } >> "${LOG_FILE}" 2>&1
    fi
    # If docker-switch command not found, install compose-switch
    if ! [[ -f /usr/local/bin/compose-switch ]]; then
        log "info" "Installing docker-compose-switch..." "+"
        {
            curl -fL https://github.com/docker/compose-switch/releases/latest/download/docker-compose-linux-amd64 -o /usr/local/bin/compose-switch
            chmod +x /usr/local/bin/compose-switch
            update-alternatives --install /usr/local/bin/docker-compose docker-compose /usr/local/bin/compose-switch 99
        } >> "${LOG_FILE}" 2>&1
    fi
    # Configure Docker daemon.json for journald logging
    mkdir -p /etc/docker
    if [ ! -f /etc/docker/daemon.json ]; then
        echo '{"log-driver": "journald"}' > /etc/docker/daemon.json
    elif ! grep -qF '"log-driver": "journald"' /etc/docker/daemon.json; then
        # Update existing daemon.json to include journald logging
        if [ -s /etc/docker/daemon.json ]; then
            # File exists and is not empty - need to merge JSON
            tmp_file=$(mktemp)
            jq '. + {"log-driver": "journald"}' /etc/docker/daemon.json > "$tmp_file" && mv "$tmp_file" /etc/docker/daemon.json
        else
            # File exists but is empty
            echo '{"log-driver": "journald"}' > /etc/docker/daemon.json
        fi
    fi
    #journald max file restriction
    sed -i '/SystemMaxUse=.*/d' /etc/systemd/journald.conf
    echo "SystemMaxUse=2G" >> /etc/systemd/journald.conf
    systemctl restart systemd-journald
    #waiting for journald to get up
    jstatus=$(systemctl is-active systemd-journald)
    while [ "$jstatus" != "active" ]; do
        echo "$jstatus"
        sleep 2
        jstatus=$(systemctl is-active systemd-journald)
    done
}

# Function: pass_generator
# Description: Generates random passwords for database and service authentication
# Parameters: 
#   $1 - password length (number of characters)
# Returns: Prints generated password to stdout
# Dependencies: RANDOM variable for random generation
# Note: Uses RANDOM for password generation, alphanumeric characters only
pass_generator () {
    symbols="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    lenght="$1"
    password=""
    while [ "${symbol:=1}" -le "$lenght" ]
    do
        password="${password}${symbols:$((RANDOM%${#symbols})):1}"
        ((symbol+=1))
    done
    symbol=0
    echo "${password}"
}

# Function: download_service_files
# Description: Downloads SSP Server service configuration files and Docker Compose setup
# Parameters: None
# Returns: None
# Dependencies: curl, unzip, internet connectivity, write permissions to INSTALL_DIR
# Note: Downloads from GitHub repository and extracts to installation directory
download_service_files () {
    log "info" "Downloading service files..." "+"
    curl -sSL "${DOWNLOAD_STANDALONE_URI}" -o "${INSTALL_DIR}/sspserver.zip"
    if [[ $? -ne 0 ]]; then
        log "error" "Failed to download service files" "+"
        exit 1
    fi

    log "info" "Unzipping service files (without overwriting existing files)..." "+"
    unzip -n "${INSTALL_DIR}/sspserver.zip" -d "${INSTALL_DIR}" >> "${LOG_FILE}" 2>&1
    if [[ $? -ne 0 ]]; then
        log "error" "Failed to unzip service files" "+"
        exit 1
    fi

    log "ok" "Service files downloaded and unzipped successfully" "+"
    rm "${INSTALL_DIR}/sspserver.zip"
}

# Parameters:
#  $1 - env file path
#  $2 - variable name
#  $3 - default variable value
#  $4 - prompt message
#  $5 - auto-confirmation mode (optional)
setup_env_file_variable () {
    local env_file="$1"
    local var_name="$2"
    local default_value="$3"
    local prompt_message="$4"
    local auto_confirm="$5"

    # Check if variable is already set in env file
    if grep -q "^${var_name}=[^\s]+" "${env_file}"; then
        log "info" "Environment variable '${var_name}' is already set in ${env_file}" "+"
    else
        # Prompt user for value
        if [[ "$auto_confirm" == "true" ]]; then
            # Use default value in auto mode
            user_input=${default_value}
            log "info" "Using default value for '${var_name}': ${user_input}" "+"
        else
            read -p "${prompt_message} [${default_value}]: " user_input
            user_input=${user_input:-$default_value}
        fi

        if grep -q "^${var_name}=" "${env_file}"; then
            sed -i "s/^${var_name}=\s+/${var_name}=${user_input}/g" "${env_file}"
        else
            # If variable not found, append it to the env file
            echo "${var_name}=${default_value}" >> "${env_file}"
        fi

        log "info" "Added environment variable '${var_name}' with default value to ${env_file}" "+"
    fi
}

# Function: prepare_general_environment
# Description: Prepares system environment, creates directories, and sets up configuration
# Parameters: None
# Returns: None
# Dependencies: user input, sed command, write permissions to INSTALL_DIR
# Note: Configures domain settings in .init.env file through interactive prompts
prepare_general_environment () {
    log "info" "Preparing general environment..." "+"

    setup_env_file_variable "${INSTALL_DIR}/.init.env" \
        "SSPSERVER_API_DOMAIN" "apidemo.sspserver.org" \
        "Enter the domain for the SSP API server" "$AUTO_YES"
    setup_env_file_variable "${INSTALL_DIR}/.init.env" \
        "SSPSERVER_UI_DOMAIN" "demo.sspserver.org" \
        "Enter the domain for the SSP UI server" "$AUTO_YES"
    setup_env_file_variable "${INSTALL_DIR}/.init.env" \
        "SSPSERVER_DOMAIN" "sspdemo.sspserver.org" \
        "Enter the domain for the SSP server" "$AUTO_YES"
}

# Function: prepare_sspservice
# Description: Prepares and configures SSP Server service for startup with systemd
# Parameters: None
# Returns: None
# Dependencies: systemctl, service files, systemd service directory
# Note: Installs systemd service, enables auto-start, and manages service lifecycle
prepare_sspservice () {
    log "info" "Preparing SSP service..." "+"
    cp ${INSTALL_DIR}/sspserver/sspserver.service ${SYSTEMD_SERVICE_DIR}/sspserver.service

    chmod 644 ${SYSTEMD_SERVICE_DIR}/sspserver.service

    systemctl daemon-reload
    systemctl enable sspserver.service
    # Stop and start the service to apply changes
    log "info" "Restarting SSP service..." "+"
    if systemctl is-active --quiet sspserver.service; then
        systemctl stop sspserver.service
        log "info" "SSP service is already running, stopping it..." "+"
    else
        log "info" "SSP service is not running, starting it for the first time..." "+"
    fi
    systemctl start sspserver.service
    if [[ $? -ne 0 ]]; then
        log "error" "Failed to start SSP service" "+"
        exit 1
    else
        log "ok" "SSP service started successfully" "+"
    fi
}

###############################################################################
## Standalone installation script for SSP Server on Ubuntu
###############################################################################

# Log startup information
log "info" "Starting SSP Server installation for Ubuntu" "+"
log "info" "Auto-confirmation mode: ${AUTO_YES}" "+"

# 1. Install dependencies
install_dependencies

# 2. Install systemd dependency if not installed
log "info" "Checking for systemd..." "+"
if ! command -v systemctl &> /dev/null
then
    log "info" "Systemd not found, installing..." "+"
    install_systemd_dependency
else
    log "ok" "Systemd is already installed" "+"
fi

# 3. Install docker if not installed
log "info" "Checking for Docker..." "+"
if ! command -v docker &> /dev/null
then
    log "info" "Docker not found, installing..." "+"
    install_docker
else
    log "ok" "Docker is already installed" "+"
fi

# 4. Download and prepare service files
download_service_files

# 5. Prepare project environment
prepare_general_environment

# 6. Pull SSP Server service
prepare_sspservice
