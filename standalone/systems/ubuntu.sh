#!/usr/bin/env bash

###############################################################################
# SSP Server Ubuntu Installation Script
#
# Description: Automated installation script for SSP Server on Ubuntu systems
# Author: SSP Server Team
# Version: 1.0
# Platform: Ubuntu with systemd
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
# - Ubuntu Linux distribution
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
PROJECT_ENV_FILE="${INSTALL_DIR}/.env"
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
        echo -e "$(date '+%d-%m-%Y %H:%M:%S') $formatted_message" >&2
    fi
}

# Function: update_env_file_from
# Description: Updates environment file with variables from another source file
# Parameters:
#   $1 - target environment file path
#   $2 - source environment file path
# Returns: None
update_env_file_from () {
    local env_file="$1"
    local env_source_file="$2"

    log "info" "Updating environment file ${env_file} from ${env_source_file}" "+"

    grep -v '^#' "$env_source_file" | while IFS='=' read -r key value; do
        if [ -z "$key" ]; then
            continue
        fi
        if ! grep -q "^$key=" "$env_file"; then
            echo "$key=$value" >> "$env_file"
        fi
    done
}

## Project dependencies
# * curl
# * unzip
# * jq
# * git
# * envsubst
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

    log "info" "Installing packages..." "+"

    for pkg in curl unzip jq git build-essential ca-certificates gnupg lsb-release gettext; do
        if dpkg -s "$pkg" &> /dev/null; then
            log "ok" "Package '$pkg' is already installed." "+"
        else
            log "info" "Installing package '$pkg'..." "+"
            apt-get -y install "$pkg" >> "${LOG_FILE}" 2>&1
        fi
    done
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
    length="$1"
    password=""
    while [ "${symbol:=1}" -le "$length" ]
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

    log "info" "Unzipping service files: ${INSTALL_DIR}/sspserver.zip ..." "+"
    unzip -o "${INSTALL_DIR}/sspserver.zip" -d "${INSTALL_DIR}" >> "${LOG_FILE}" 2>&1
    if [[ $? -ne 0 ]]; then
        log "error" "Failed to unzip service files" "+"
        exit 1
    fi

    log "ok" "Service files downloaded and unzipped successfully" "+"
    rm "${INSTALL_DIR}/sspserver.zip"
}

# Function: is_env_var_setup
# Description: Checks if a specific environment variable is set in the given file
# Parameters:
#   $1 - environment file path
#   $2 - variable name to check
# Returns: 0 if variable is set, 1 if not
# Dependencies: grep command
# Note: Checks for non-empty variable value in the environment file
is_env_var_setup () {
    local env_file="$1"
    local var_name="$2"
    
    if grep -q "^${var_name}=[^[:space:]]*[[:graph:]]" "${env_file}" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Function: setup_env_file_variable
# Description: Sets up environment variables in configuration files with interactive or auto mode
# Parameters:
#   $1 - env file path
#   $2 - variable name  
#   $3 - default variable value
#   $4 - prompt message
#   $5 - auto-confirmation mode (optional)
# Returns: None
# Dependencies: grep, sed (GNU version), read command, file write permissions
# Note: Ubuntu/Debian uses GNU sed which has different syntax than BSD sed
setup_env_file_variable () {
    local env_file="$1"
    local var_name="$2"
    local default_value="$3"
    local prompt_message="$4"
    local auto_confirm="$5"
    local return_value="${default_value}"

    # Check if variable is already set in env file (non-empty value)
    if grep -q "^${var_name}=[^[:space:]]*[[:graph:]]" "${env_file}" 2>/dev/null; then
        log "info" "Environment variable '${var_name}' is already set in ${env_file}" "+"
    else
        # Prompt user for value
        if [[ "$auto_confirm" == "true" ]]; then
            # Use default value in auto mode
            user_input=${default_value}
            log "info" "Using default value for '${var_name}': ${user_input}" "+"
        else
            read -p "${prompt_message} [${default_value}]: " user_input < /dev/tty
            user_input=${user_input:-$default_value}
            return_value="${user_input}"
        fi

        # GNU sed doesn't require empty string after -i for in-place editing
        if grep -q "^${var_name}=" "${env_file}" 2>/dev/null; then
            # Variable exists but is empty, update it
            sed -i "s/^${var_name}=.*/${var_name}=${user_input}/g" "${env_file}"
        else
            # Variable not found, append it to the env file
            echo "${var_name}=${user_input}" >> "${env_file}"
        fi

        log "info" "Set environment variable '${var_name}' to '${user_input}' in ${env_file}" "+"
    fi

    # Return the value for further use
    echo "${return_value}"
}

# Function: prepare_environment_file
# Description: Prepares the environment file, initializes variables from other environment files
# Parameters:
#   $1 - env file path with variables which need to prepare env file in second parameter
#   $2 - env file path for preparation (template)
# Returns: new environment file stdout
prepare_environment_file () {
    local env_file="$1"
    local template_file="$2"

    log "info" "Preparing environment file from ${template_file} to ${env_file}" "+"

    # Check if template file exists
    if [ ! -f "${template_file}" ]; then
        log "error" "Template file not found: ${template_file}" "+"
        exit 1
    fi

    # Mix template file with environment variables and put to stdout
    set -a
    source "${env_file}"
    set +a
    envsubst < "${template_file}"
}

# Function: prepare_general_environment
# Description: Prepares system environment, creates directories, and sets up configuration
# Parameters: None
# Returns: None
# Dependencies: setup_env_file_variable function, write permissions to INSTALL_DIR
# Note: Uses unified environment variable setup with AUTO_YES support
prepare_general_environment () {
    log "info" "Preparing general environment..." "+"

    # Check if .env file exists (should be created during service file download)
    if [ ! -f "${PROJECT_ENV_FILE}" ]; then
        log "error" "Configuration file ${PROJECT_ENV_FILE} not found in ${INSTALL_DIR}" "+"
        exit 1
    fi

    # Set up environment variables with prompts or defaults for service web domains
    log "info" "Setting domains of the service..." "+"

    SSPSERVER_PROJECT_DOMAIN=$(
        setup_env_file_variable "${PROJECT_ENV_FILE}" \
            "SSPSERVER_PROJECT_DOMAIN" "${SSPSERVER_PROJECT_DOMAIN:-sspserver.org}" \
            "Enter the domain for the project" "$AUTO_YES"
    )

    setup_env_file_variable "${PROJECT_ENV_FILE}" \
        "SSPSERVER_API_DOMAIN" "api.${SSPSERVER_PROJECT_DOMAIN}" \
        "Enter the domain for the SSP API server" "$AUTO_YES"

    setup_env_file_variable "${PROJECT_ENV_FILE}" \
        "SSPSERVER_CONTROL_DOMAIN" "control.${SSPSERVER_PROJECT_DOMAIN}" \
        "Enter the domain for the SSP UI server" "$AUTO_YES"

    SSPSERVER_AD_DOMAIN=$(
        setup_env_file_variable "${PROJECT_ENV_FILE}" \
            "SSPSERVER_AD_DOMAIN" "ssp.${SSPSERVER_PROJECT_DOMAIN}" \
            "Enter the domain for the SSP AD server" "$AUTO_YES"
    )

    SSPSERVER_JSSDK_DOMAIN=$(
        setup_env_file_variable "${PROJECT_ENV_FILE}" \
            "SSPSERVER_JSSDK_DOMAIN" "jssdk.${SSPSERVER_PROJECT_DOMAIN}" \
            "Enter the domain for the SSP JSSDK server" "$AUTO_YES"
    )

    setup_env_file_variable "${PROJECT_ENV_FILE}" \
        "SSPSERVER_TRACKER_DOMAIN" "${SSPSERVER_AD_DOMAIN}" \
        "Enter the domain for the SSP Tracker server" "$AUTO_YES"

    # Set up control environment variables
    log "info" "Setting up control environment variables..." "+"

    setup_env_file_variable "${PROJECT_ENV_FILE}" \
        "CONTROL_AUTH_SECRET" "$(pass_generator 32)" \
        "Enter the NextAuth secret" "$AUTO_YES"

    # Set up additional environment variables for database and service authentication
    log "info" "Setting up database environment variables..." "+"

    # Check if need to set up external database
    local use_external_db='N'
    if is_env_var_setup "${PROJECT_ENV_FILE}" "POSTGRES_CONNECTION"; then
        log "ok"  "External PostgreSQL connection is already set up" "+"
        use_external_db='Y'
    elif ! is_env_var_setup "${PROJECT_ENV_FILE}" "POSTGRES_DB"; then
        read -p "Do you want to set up an external database? (y/N): " -n 1 use_external_db < /dev/tty
    fi

    if [[ "$use_external_db" =~ ^[Yy]$ ]]; then
        log "info" "Setting up external database connection..." "+"

        setup_env_file_variable "${PROJECT_ENV_FILE}" \
            "POSTGRES_CONNECTION" "${POSTGRES_CONNECTION_EXTERNAL:-}" \
            "Enter the PostgreSQL connection: (postgres://user:password@host:port/dbname?sslmode=disable)" "$AUTO_YES"

        if ! is_env_var_setup "${PROJECT_ENV_FILE}" "POSTGRES_CONNECTION"; then
            log "error" "PostgreSQL connection string cannot be empty" "+"
            exit 1
        fi
    else
        setup_env_file_variable "${PROJECT_ENV_FILE}" \
            "POSTGRES_DB" "sspdb" \
            "Enter the PostgreSQL database name" "$AUTO_YES"

        setup_env_file_variable "${PROJECT_ENV_FILE}" \
            "POSTGRES_USER" "sspuser" \
            "Enter the PostgreSQL user" "$AUTO_YES"

        setup_env_file_variable "${PROJECT_ENV_FILE}" \
            "POSTGRES_PASSWORD" "$(pass_generator 12)" \
            "Enter the PostgreSQL password" "$AUTO_YES"
    fi

    # Set up statistic environment variables
    log "info" "Setting up statistic environment variables..." "+"

    # Check if need to set up external statistic database
    local use_external_statistic_db='N'
    if is_env_var_setup "${PROJECT_ENV_FILE}" "CLICKHOUSE_CONNECTION"; then
        log "ok" "External ClickHouse connection is already set up" "+"
        use_external_statistic_db='Y'
    elif ! is_env_var_setup "${PROJECT_ENV_FILE}" "CLICKHOUSE_USER"; then
        read -p "Do you want to set up an external statistic database? (y/N): " -n 1 use_external_statistic_db < /dev/tty
    fi

    if [[ "$use_external_statistic_db" =~ ^[Yy]$ ]]; then
        log "info" "Setting up external statistic database connection..." "+"

        setup_env_file_variable "${PROJECT_ENV_FILE}" \
            "CLICKHOUSE_CONNECTION" "" \
            "Enter the ClickHouse connection: (clickhouse://user:password@host:port/dbname?sslmode=disable)" "$AUTO_YES"

        if ! is_env_var_setup "${PROJECT_ENV_FILE}" "CLICKHOUSE_CONNECTION"; then
            log "error" "ClickHouse connection string cannot be empty" "+"
            exit 1
        fi
    else
        # setup_env_file_variable "${PROJECT_ENV_FILE}" \
        #     "CLICKHOUSE_DB" "stats" \
        #     "Enter the ClickHouse database name" "$AUTO_YES"

        setup_env_file_variable "${PROJECT_ENV_FILE}" \
            "CLICKHOUSE_USER" "default" \
            "Enter the ClickHouse user" "$AUTO_YES"

        # setup_env_file_variable "${PROJECT_ENV_FILE}" \
        #     "CLICKHOUSE_PASSWORD" "" \
        #     "Enter the ClickHouse password" "$AUTO_YES"
    fi

    # Ensure proper file permissions for .env files
    if ! chmod 644 "${PROJECT_ENV_FILE}"; then
        log "error" "Failed to set permissions on postgres/.env" "+"
        exit 1
    fi

    log "ok" "File permissions set correctly" "+"
    log "ok" "General environment preparation completed" "+"
}

# Function: prepare_sspservice
# Description: Prepares and configures SSP Server service for startup with systemd
# Parameters: None
# Returns: None
# Dependencies: systemctl, service files, systemd service directory
# Note: Installs systemd service, enables auto-start, and manages service lifecycle
prepare_sspservice () {
    log "info" "Preparing SSP service..." "+"

    # Prepare services environment
    log "info" "Preparing services environment..." "+"
    prepare_environment_file "${PROJECT_ENV_FILE}" \
        "${INSTALL_DIR}/app-ssp/.tmpl.env" > "${INSTALL_DIR}/app-ssp/.env"
    prepare_environment_file "${PROJECT_ENV_FILE}" \
        "${INSTALL_DIR}/app-api/.tmpl.env" > "${INSTALL_DIR}/app-api/.env"
    prepare_environment_file "${PROJECT_ENV_FILE}" \
        "${INSTALL_DIR}/postgres/.tmpl.env" > "${INSTALL_DIR}/postgres/.env"
    prepare_environment_file "${PROJECT_ENV_FILE}" \
        "${INSTALL_DIR}/app-control/.tmpl.env" > "${INSTALL_DIR}/app-control/.env"
    prepare_environment_file "${PROJECT_ENV_FILE}" \
        "${INSTALL_DIR}/eventstream/.tmpl.env" > "${INSTALL_DIR}/eventstream/.env"

    log "info" "Configuring docker-compose.yml..." "+"
    COMPOSE_FILES=(
        "${INSTALL_DIR}/docker-compose.base.yml"
        "${INSTALL_DIR}/eventstream/docker-compose.yml"
        "${INSTALL_DIR}/nginx/docker-compose.yml"
        "${INSTALL_DIR}/jssdk/docker-compose.yml"
    )

    source "${PROJECT_ENV_FILE}" && {
        [[ -z "${POSTGRES_CONNECTION}" ]]           && COMPOSE_FILES+=("${INSTALL_DIR}/postgres/docker-compose.yml")
        [[ -z "${CLICKHOUSE_CONNECTION}" ]]         && COMPOSE_FILES+=("${INSTALL_DIR}/clickhouse/docker-compose.yml")
        [[ -z "${EVENT_QUEUE_CONNECTION_BASE}" ]]   && COMPOSE_FILES+=("${INSTALL_DIR}/redis/docker-compose.yml")
    }

    source "${PROJECT_ENV_FILE}" && \
        docker compose \
            $(for file in "${COMPOSE_FILES[@]}"; do echo -n "-f ${file} "; done) \
            config > "${INSTALL_DIR}/docker-compose.yml"

    #===========================================================================
    # Create systemd service file
    # This file will be used to manage the SSP Server service
    # It will be placed in /etc/systemd/system/sspserver.service
    #===========================================================================

    log "info" "Creating systemd service file..." "+"
    cp ${INSTALL_DIR}/init.d/sspserver.service ${SYSTEMD_SERVICE_DIR}/sspserver.service
    chmod 644 ${SYSTEMD_SERVICE_DIR}/sspserver.service
}

# Function: run_sspservice
# Description: Starts the SSP Server service using systemd
# Parameters: None
# Returns: None
# Dependencies: systemctl, service files, systemd service directory
# Note: Enables the service to start on boot, stops if already running, and starts it
run_sspservice () {
    log "info" "Running SSP service..." "+"
    systemctl daemon-reload
    systemctl enable sspserver.service

    # Stop and start the service to apply changes
    log "info" "Restarting SSP service..." "+"
    if systemctl is-active --quiet sspserver.service; then
        log "info" "SSP service is already running, stopping it..." "+"
        systemctl stop sspserver.service
    else
        log "info" "SSP service is not running, starting it for the first time..." "+"
    fi

    # Start the SSP service
    log "info" "Starting SSP service..." "+"
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

# 5. Update project environment file
log "info" "Updating project environment file..." "+"
if [ -f "${PROJECT_ENV_FILE}" ]; then
    log "info" "Project environment file already exists, updating..." "+"
    update_env_file_from "${PROJECT_ENV_FILE}" "${INSTALL_DIR}/.init.env"
else
    log "info" "Project environment file not found, creating new one..." "+"
    cp "${INSTALL_DIR}/.init.env" "${PROJECT_ENV_FILE}"
fi

# 6. Prepare project environment
prepare_general_environment

# 7. Prepare SSP Server service for running
prepare_sspservice

# 8. Run SSP Server service
run_sspservice
