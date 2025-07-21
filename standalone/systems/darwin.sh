#!/usr/bin/env bash

###############################################################################
# SSP Server Installation Script for macOS/Darwin
###############################################################################
#
# This script installs and configures SSP Server on macOS systems using:
# - Homebrew or MacPorts for package management
# - Docker Desktop for containerization
# - launchd for service management (instead of systemd)
#
# USAGE:
#   Run this script from the main install.sh:
#   ./install.sh              # Interactive mode
#   ./install.sh -y           # Auto-confirmation mode
#
# SERVICE MANAGEMENT:
#   After installation, you can manage the SSP service using launchctl:
#
#   # Load service
#   sudo launchctl load /Library/LaunchDaemons/org.sspserver.sspserver.plist
#
#   # Unload service  
#   sudo launchctl unload /Library/LaunchDaemons/org.sspserver.sspserver.plist
#
#   # Check status
#   sudo launchctl list | grep sspserver
#
#   # View logs
#   tail -f /var/log/sspserver/sspserver.out.log
#   tail -f /var/log/sspserver/sspserver.err.log
#
# REQUIREMENTS:
#   - macOS 10.15+ (Catalina or later)
#   - Admin privileges (sudo access)
#   - Internet connection for downloads
#   - 4GB+ available disk space
#
# INSTALLED COMPONENTS:
#   - System dependencies (curl, unzip, jq, git)
#   - Docker Desktop
#   - SSP Server service files
#   - launchd service configuration
#
###############################################################################

# Installation directories and files
LOG_DIR="/var/log/sspserver"
LOG_FILE="${LOG_DIR}/sspserver_1click_standalone.log"
INSTALL_DIR="/opt/sspserver"
OS_NAME="darwin"
DOWNLOAD_STANDALONE_URI="https://github.com/sspserver/deploy/raw/refs/heads/build/standalone/darwin.zip"

# Auto-confirmation parameter (passed from main install.sh)
AUTO_YES=${AUTO_YES:-false}

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

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

#############################################################################
# PROJECT INSTALLATION FUNCTIONS
#############################################################################
# Functions for installing dependencies and configuring SSP Server on macOS

# Function: install_dependencies
# Description: Installs required system dependencies for SSP Server on macOS
# Parameters: None
# Returns: None
# Dependencies: macOS package manager (brew), system utilities
# Note: Installs curl, unzip, jq, git, Docker, and other required packages
install_dependencies () {
    log "info" "Installing dependencies..." "+"
    
    # Required packages for SSP Server
    local packages=("curl" "unzip" "jq" "git")
    
    # Check if Homebrew is available
    if command -v brew &> /dev/null; then
        log "info" "Using Homebrew package manager..." "+"
        
        # Update Homebrew
        log "info" "Updating Homebrew..." "+"
        if ! brew update; then
            log "error" "Failed to update Homebrew" "+"
            exit 1
        fi
        
        # Check and install packages using Homebrew
        for package in "${packages[@]}"; do
            if command -v "$package" &> /dev/null; then
                log "ok" "$package is already installed" "+"
            else
                log "info" "Installing $package via Homebrew..." "+"
                if ! brew install "$package"; then
                    log "error" "Failed to install $package via Homebrew" "+"
                    exit 1
                fi
                log "ok" "$package installed successfully" "+"
            fi
        done
        
    # Check if MacPorts is available
    elif command -v port &> /dev/null; then
        log "info" "Using MacPorts package manager..." "+"
        
        # Update MacPorts
        log "info" "Updating MacPorts..." "+"
        if ! sudo port selfupdate; then
            log "error" "Failed to update MacPorts" "+"
            exit 1
        fi
        
        # Check and install packages using MacPorts
        for package in "${packages[@]}"; do
            if command -v "$package" &> /dev/null; then
                log "ok" "$package is already installed" "+"
            else
                log "info" "Installing $package via MacPorts..." "+"
                if ! sudo port install "$package"; then
                    log "error" "Failed to install $package via MacPorts" "+"
                    exit 1
                fi
                log "ok" "$package installed successfully" "+"
            fi
        done
        
    else
        # No package manager found, check if tools are available
        log "error" "No package manager found (Homebrew or MacPorts)" "+"
        
        # Check if required tools are already installed
        local missing_packages=()
        for package in "${packages[@]}"; do
            if ! command -v "$package" &> /dev/null; then
                missing_packages+=("$package")
            fi
        done
        
        if [ ${#missing_packages[@]} -gt 0 ]; then
            log "error" "Missing required packages: ${missing_packages[*]}" "+"
            log "error" "Please install Homebrew or MacPorts first:" "+"
            log "error" "  Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            log "error" "  MacPorts: https://www.macports.org/install.php"
            exit 1
        else
            log "ok" "All required packages are already installed" "+"
        fi
    fi
    
    log "ok" "Dependencies installation completed" "+"
}

# Function: setup_service_manager
# Description: Sets up service management system for macOS (launchd instead of systemd)
# Parameters: None
# Returns: None
# Dependencies: macOS launchd system
# Note: macOS uses launchd instead of systemd, this function validates launchd availability
setup_service_manager () {
    log "info" "Setting up service manager for macOS..." "+"
    
    # Check if launchctl is available (should be by default on macOS)
    if command -v launchctl &> /dev/null; then
        log "ok" "launchd (launchctl) is available - macOS service manager ready" "+"
    else
        log "error" "launchctl not found - this is unusual for macOS" "+"
        exit 1
    fi
    
    log "ok" "Service manager setup completed for macOS" "+"
}

# Function: install_docker
# Description: Installs Docker Desktop or Docker Engine on macOS
# Parameters: None
# Returns: None
# Dependencies: macOS package manager, system permissions
# Note: Downloads and installs Docker from official sources or package manager
install_docker () {
    log "info" "Installing Docker for macOS..." "+"
    
    # Check if Docker is already installed and working
    if command -v docker &> /dev/null && docker info &> /dev/null; then
        log "ok" "Docker is already installed and running" "+"
        
        # Check for modern docker compose command
        if docker compose version &> /dev/null; then
            log "ok" "Docker Compose (modern) is available" "+"
        elif command -v docker-compose &> /dev/null; then
            log "info" "Legacy docker-compose found, modern 'docker compose' preferred" "+"
        else
            log "error" "Docker Compose not available" "+"
        fi
        return 0
    fi
    
    # Check if Homebrew is available for Docker installation
    if command -v brew &> /dev/null; then
        log "info" "Installing Docker Desktop via Homebrew..." "+"
        
        # Install Docker Desktop using Homebrew cask
        if ! brew install --cask docker; then
            log "error" "Failed to install Docker Desktop via Homebrew" "+"
            log "error" "Failed to install Docker Desktop via Homebrew" "+"
            exit 1
        fi
        
        log "ok" "Docker Desktop installed via Homebrew" "+"
        
    else
        # Manual installation if no package manager
        log "info" "No package manager found, attempting manual Docker installation..." "+"
        
        # Detect architecture for correct Docker Desktop download
        local arch=$(uname -m)
        local docker_url=""
        
        if [[ "$arch" == "arm64" ]] || [[ "$arch" == "aarch64" ]]; then
            docker_url="https://desktop.docker.com/mac/stable/arm64/Docker.dmg"
            log "info" "Detected Apple Silicon (ARM64), downloading Docker for Apple Silicon..." "+"
        else
            docker_url="https://desktop.docker.com/mac/stable/amd64/Docker.dmg"
            log "info" "Detected Intel (x86_64), downloading Docker for Intel..." "+"
        fi
        
        # Download Docker Desktop DMG
        log "info" "Downloading Docker Desktop..." "+"
        if ! curl -fsSL "$docker_url" -o "/tmp/Docker.dmg"; then
            log "error" "Failed to download Docker Desktop" "+"
            exit 1
        fi
        
        # Mount DMG and install
        log "info" "Mounting Docker Desktop installer..." "+"
        if ! hdiutil attach "/tmp/Docker.dmg" -quiet; then
            log "error" "Failed to mount Docker Desktop installer" "+"
            log "error" "Failed to mount Docker.dmg" "+"
            exit 1
        fi
        
        # Copy Docker to Applications
        log "info" "Installing Docker Desktop to Applications..." "+"
        if ! cp -R "/Volumes/Docker/Docker.app" "/Applications/"; then
            log "error" "Failed to copy Docker to Applications" "+"
            exit 1
        fi
        
        # Unmount DMG and cleanup
        hdiutil detach "/Volumes/Docker" -quiet
        rm -f "/tmp/Docker.dmg"
        
        log "ok" "Docker Desktop installed manually" "+"
    fi
    
    # Check if Docker Desktop needs to be started
    if ! pgrep -f "Docker Desktop" > /dev/null; then
        log "info" "Starting Docker Desktop..." "+"
        
        # Start Docker Desktop
        open -a Docker
        
        # Wait for Docker to be ready
        log "info" "Waiting for Docker to start..." "+"
        local timeout=120
        local count=0
        
        while ! command -v docker &> /dev/null || ! docker info &> /dev/null; do
            if [ $count -ge $timeout ]; then
                log "error" "Docker failed to start within $timeout seconds" "+"
                exit 1
            fi
            
            sleep 3
            ((count+=3))
            log "info" "Waiting for Docker... ($count/$timeout seconds)" "+"
        done
        
        log "ok" "Docker Desktop is running" "+"
    else
        log "ok" "Docker Desktop is already running" "+"
    fi
    
    # Verify modern docker compose is available
    log "info" "Checking Docker Compose availability..." "+"
    if docker compose version &> /dev/null; then
        log "ok" "Docker Compose (modern) is available" "+"
    else
        log "error" "Docker Compose is not available. Please restart Docker Desktop." "+"
        exit 1
    fi
    
    log "ok" "Docker installation completed" "+"
}

# Function: pass_generator
# Description: Generates random passwords for database and service authentication
# Parameters: 
#   $1 - password length (number of characters)
# Returns: Prints generated password to stdout
# Dependencies: RANDOM variable for random generation
# Note: Uses RANDOM for password generation, compatible with ubuntu.sh implementation
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
# Dependencies: curl, internet connectivity, write permissions to INSTALL_DIR
# Note: Downloads from GitHub repository and extracts to installation directory
download_service_files () {
    log "info" "Downloading service files..." "+"
    
    # Create installation directory if it doesn't exist
    if [ ! -d "${INSTALL_DIR}" ]; then
        log "info" "Creating installation directory: ${INSTALL_DIR}" "+"
        if ! sudo mkdir -p "${INSTALL_DIR}"; then
            log "error" "Failed to create installation directory" "+"
            exit 1
        fi
        log "ok" "Created installation directory: ${INSTALL_DIR}" "+"
    fi
    
    # Download service files archive
    log "info" "Downloading SSP Server service files from GitHub..." "+"
    
    if ! curl -sSL "${DOWNLOAD_STANDALONE_URI}" -o "${INSTALL_DIR}/sspserver.zip"; then
        log "error" "Failed to download service files" "+"
        exit 1
    fi
    
    log "ok" "Service files downloaded successfully" "+"
    
    # Extract the archive
    log "info" "Extracting service files..." "+"
    
    if ! unzip -o "${INSTALL_DIR}/sspserver.zip" -d "${INSTALL_DIR}" >> "${LOG_FILE}" 2>&1; then
        log "error" "Failed to extract service files" "+"
        exit 1
    fi
    
    log "ok" "Service files extracted successfully" "+"
    log "ok" "Service files extracted successfully" "+"
    
    # Clean up the downloaded archive
    log "info" "Cleaning up download archive..." "+"
    if ! rm "${INSTALL_DIR}/sspserver.zip"; then
        log "error" "Failed to remove download archive" "+"
        # Non-fatal error, continue
    else
        log "ok" "Download archive cleaned up" "+"
    fi
    
    # Verify extraction was successful
    if [ ! -f "${INSTALL_DIR}/docker-compose.yml" ]; then
        log "error" "Expected docker-compose.yml not found after extraction" "+"
        exit 1
    fi
    
    log "ok" "Service files download and extraction completed" "+"
}

# Function: prepare_general_environment
# Description: Prepares system environment, creates directories, and sets up configuration
# Parameters: None
# Returns: None
# Dependencies: write permissions, pass_generator function
# Note: Creates log directories, sets permissions, and prepares environment variables
prepare_general_environment () {
    log "info" "Preparing general environment..." "+"
    
    # Check if .init.env file exists
    if [ ! -f "${INSTALL_DIR}/.init.env" ]; then
        log "error" "Configuration file .init.env not found in ${INSTALL_DIR}" "+"
        exit 1
    fi
    
    log "ok" ".init.env configuration file found" "+"
    
    # Configure domains based on AUTO_YES parameter (passed from main install.sh)
    if [[ "${AUTO_YES:-false}" == "true" ]]; then
        # Use default values in auto mode
        log "info" "Auto-configuration mode: using default domain values" "+"
        
        SSPSERVER_API_DOMAIN="apidemo.sspserver.org"
        SSPSERVER_UI_DOMAIN="demo.sspserver.org" 
        SSPSERVER_DOMAIN="sspdemo.sspserver.org"
        
        log "info" "Using default API domain: ${SSPSERVER_API_DOMAIN}" "+"
        log "info" "Using default UI domain: ${SSPSERVER_UI_DOMAIN}" "+"
        log "info" "Using default SSP domain: ${SSPSERVER_DOMAIN}" "+"
        
    else
        # Interactive mode - ask user for domain configuration
        log "info" "Interactive configuration mode" "+"
        log "info" "Interactive configuration mode" "+"
        
        # API Server Domain
        echo -n "Enter the domain for the SSP API server [apidemo.sspserver.org]: "
        read -r SSPSERVER_API_DOMAIN < /dev/tty
        SSPSERVER_API_DOMAIN=${SSPSERVER_API_DOMAIN:-apidemo.sspserver.org}
        log "ok" "API domain set to: ${SSPSERVER_API_DOMAIN}" "+"
        
        # UI Server Domain  
        echo -n "Enter the domain for the SSP UI server [demo.sspserver.org]: "
        read -r SSPSERVER_UI_DOMAIN < /dev/tty
        SSPSERVER_UI_DOMAIN=${SSPSERVER_UI_DOMAIN:-demo.sspserver.org}
        log "ok" "UI domain set to: ${SSPSERVER_UI_DOMAIN}" "+"
        
        # SSP Server Domain
        echo -n "Enter the domain for the SSP server [sspdemo.sspserver.org]: "
        read -r SSPSERVER_DOMAIN < /dev/tty
        SSPSERVER_DOMAIN=${SSPSERVER_DOMAIN:-sspdemo.sspserver.org}
        log "ok" "SSP domain set to: ${SSPSERVER_DOMAIN}" "+"
    fi
    
    # Apply domain configuration to .init.env file
    log "info" "Updating configuration file with domain settings..." "+"
    
    # Replace API domain (apidemo.sspserver.org -> user input)
    if ! sed -i '' "s/apidemo\.sspserver\.org/${SSPSERVER_API_DOMAIN}/g" "${INSTALL_DIR}/.init.env"; then
        log "error" "Failed to update API domain in configuration" "+"
        exit 1
    fi
    
    # Replace UI domain (demo.sspserver.org -> user input)  
    if ! sed -i '' "s/demo\.sspserver\.org/${SSPSERVER_UI_DOMAIN}/g" "${INSTALL_DIR}/.init.env"; then
        log "error" "Failed to update UI domain in configuration" "+"
        exit 1
    fi
    
    # Replace SSP domain (sspdemo.sspserver.org -> user input)
    if ! sed -i '' "s/sspdemo\.sspserver\.org/${SSPSERVER_DOMAIN}/g" "${INSTALL_DIR}/.init.env"; then
        log "error" "Failed to update SSP domain in configuration" "+"
        exit 1
    fi
    
    log "ok" "Domain configuration applied successfully" "+"
    
    # Ensure proper file permissions
    log "info" "Setting proper file permissions..." "+"
    if ! chmod 644 "${INSTALL_DIR}/.init.env"; then
        log "error" "Failed to set permissions on .init.env" "+"
        exit 1
    fi
    
    log "ok" "File permissions set correctly" "+"
    
    log "ok" "General environment preparation completed" "+"
}

# Function: prepare_sspservice
# Description: Prepares and configures SSP Server service for startup
# Parameters: None
# Returns: None
# Dependencies: Docker, service files, environment configuration
# Note: Pulls Docker images, configures services, and prepares for launch
prepare_sspservice () {
    log "info" "Preparing SSP service..." "+"
    
    # Define launchd plist path for macOS
    local LAUNCHD_SERVICE_DIR="/Library/LaunchDaemons"
    local SERVICE_PLIST="org.sspserver.sspserver.plist"
    
    # Check if the service plist file exists in install directory
    if [ ! -f "${INSTALL_DIR}/sspserver/${SERVICE_PLIST}" ]; then
        log "error" "Service plist file not found: ${INSTALL_DIR}/sspserver/${SERVICE_PLIST}" "+"
        exit 1
    fi
    
    log "ok" "Found service plist file" "+"
    
    # Copy service plist to LaunchDaemons directory
    log "info" "Installing launchd service..." "+"
    if ! sudo cp "${INSTALL_DIR}/sspserver/${SERVICE_PLIST}" "${LAUNCHD_SERVICE_DIR}/${SERVICE_PLIST}"; then
        log "error" "Failed to copy service plist to ${LAUNCHD_SERVICE_DIR}" "+"
        exit 1
    fi
    
    log "ok" "Service plist copied to LaunchDaemons" "+"
    
    # Set proper ownership and permissions
    log "info" "Setting service file permissions..." "+"
    if ! sudo chown root:wheel "${LAUNCHD_SERVICE_DIR}/${SERVICE_PLIST}"; then
        log "error" "Failed to set ownership on service plist" "+"
        exit 1
    fi
    
    if ! sudo chmod 644 "${LAUNCHD_SERVICE_DIR}/${SERVICE_PLIST}"; then
        log "error" "Failed to set permissions on service plist" "+"
        exit 1
    fi
    
    log "ok" "Service file permissions set correctly" "+"
    
    # Load the service with launchd
    log "info" "Loading SSP service with launchd..." "+"
    if ! sudo launchctl load "${LAUNCHD_SERVICE_DIR}/${SERVICE_PLIST}"; then
        log "error" "Failed to load SSP service with launchd" "+"
        exit 1
    fi
    
    log "ok" "SSP service loaded with launchd" "+"
    
    # Enable the service to start at boot
    log "info" "Enabling SSP service to start at boot..." "+"
    if ! sudo launchctl enable "system/${SERVICE_PLIST%.*}"; then
        log "info" "Note: Service enable command may not be available on older macOS versions" "+"
    else
        log "ok" "SSP service enabled to start at boot" "+"
    fi
    
    # Check if service is already running and manage accordingly
    log "info" "Managing SSP service state..." "+"
    
    # Check if service is loaded
    if sudo launchctl list | grep -q "${SERVICE_PLIST%.*}"; then
        log "info" "SSP service is loaded, restarting to apply changes..." "+"
        
        # Stop the service
        if ! sudo launchctl unload "${LAUNCHD_SERVICE_DIR}/${SERVICE_PLIST}" 2>/dev/null; then
            log "info" "Service was not running, will start fresh" "+"
        else
            log "ok" "SSP service stopped" "+"
        fi
        
        # Start the service
        if ! sudo launchctl load "${LAUNCHD_SERVICE_DIR}/${SERVICE_PLIST}"; then
            log "error" "Failed to start SSP service" "+"
            exit 1
        fi
    else
        log "info" "Starting SSP service for the first time..." "+"
    fi
    
    # Wait a moment for service to initialize
    log "info" "Waiting for service to initialize..." "+"
    sleep 3
    
    # Verify service is running
    if sudo launchctl list | grep -q "${SERVICE_PLIST%.*}"; then
        log "ok" "SSP service is running" "+"
        
        # Show service status
        log "info" "Service status:" "+"
        sudo launchctl list | grep "${SERVICE_PLIST%.*}" || true
        
    else
        log "error" "SSP service failed to start" "+"
        
        # Show logs for debugging
        log "info" "Checking service logs:" "+"
        if [ -f "/var/log/sspserver/sspserver.err.log" ]; then
            echo "Error log:"
            tail -10 "/var/log/sspserver/sspserver.err.log" || true
        fi
        if [ -f "/var/log/sspserver/sspserver.out.log" ]; then
            echo "Output log:"
            tail -10 "/var/log/sspserver/sspserver.out.log" || true
        fi
        
        exit 1
    fi
    
    log "ok" "SSP service preparation completed" "+"
}

#############################################################################

###############################################################################
## Standalone installation script for SSP Server on Darwin/macOS
###############################################################################

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

# Log startup information
log "info" "Starting SSP Server installation for macOS/Darwin" "+"
log "info" "Auto-confirmation mode: ${AUTO_YES}" "+"

# 1. Install dependencies
install_dependencies

# 2. Setup service manager (launchd for macOS)
setup_service_manager

# 3. Install docker if not installed
log "info" "Checking for Docker..." "+"
if ! command -v docker &> /dev/null
then
    log "error" "Docker not found, installing..." "+"
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
