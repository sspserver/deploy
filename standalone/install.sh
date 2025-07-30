#!/usr/bin/env bash

#############################################################################
# SSP Server One-Click Standalone Installer
#############################################################################
# Description: Universal installation script for SSP Server deployment
# Author: SSP Server Team
# Version: 1.0
# 
# Purpose: This script performs system compatibility checks and downloads
#          OS-specific installation scripts for automated SSP Server deployment
#
# Supported Systems:
#   - Ubuntu Linux (fully supported)
#   - Debian Linux (partial support)  
#   - CentOS/RHEL Linux (requires centos.sh implementation)
#   - macOS/Darwin (requires compatibility fixes)
#
# System Requirements:
#   - CPU: Architecture and core count defined in SUPPORTED_ARCH and MIN_CPU_CORES
#   - RAM: Minimum memory defined in MIN_RAM_KB 
#   - Storage: Minimum free space defined in MIN_STORAGE_KB in STORAGE_CHECK_PATH
#   - Network: Internet connectivity for package downloads
#   - OS: Supported systems listed in SUPPORTED_OS_LIST array
#
# Usage: 
#   Interactive mode (with TTY):
#     ./install.sh           # Download and run locally for interactive mode
#     bash <(curl -sSL <url>) # Interactive mode with process substitution
#   
#   Non-interactive mode:
#     ./install.sh -y        # Local execution without prompts
#     curl -sSL <url> | bash -s -- -y # Remote execution without prompts
#
# Options:
#   -y, --yes    Automatically answer 'yes' to all prompts (non-interactive mode)
#   -h, --help   Display usage information and exit
#
# Examples:
#   # Interactive installation (download first, then run):
#   curl -sSL <url> -o install.sh && chmod +x install.sh && ./install.sh
#   
#   # Or using process substitution for interactive mode:
#   bash <(curl -sSL <url>)
#   
#   # Automated installation without user prompts:
#   curl -sSL <url> | bash -s -- -y
#
# Note: When using 'curl | bash' without -y flag, the script will detect
#       non-interactive mode and require you to use the -y flag.
#
# Warning: This script downloads and executes remote code. Ensure you trust
#          the source repository before execution.
#############################################################################

# Color definitions for console output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color

# Installation directories and files
LOG_DIR="/var/log/sspserver"                            # Directory for installation logs
LOG_FILE="${LOG_DIR}/sspserver_1click_standalone.log"   # Main log file path
INSTALL_DIR="/opt/sspserver"                            # Target installation directory
TEMP_INSTALL_SCRIPT="/tmp/sspserver_installer_$(date +%s)_$$.sh"  # Temporary OS-specific installer script

# Remote repository URL template for OS-specific installers
# Template variable {{os-name}} will be replaced with actual OS identifier
RUN_INSTALLER_SCRIPT_URI="https://raw.githubusercontent.com/sspserver/deploy/refs/heads/build/standalone/install-{{os-name}}.sh?r=$(date +%s)"

#############################################################################
# SYSTEM REQUIREMENTS CONFIGURATION
#############################################################################
# These variables define the minimum system requirements for SSP Server.
# Modify these values to adjust installation requirements as needed.

# CPU Requirements
MIN_CPU_CORES=2                                 # Minimum number of CPU cores/threads required
SUPPORTED_ARCH=("x86_64" "arm64" "aarch64")     # Supported CPU architectures (x86_64 and ARM64)

# Memory Requirements  
MIN_RAM_KB=3900000                # Minimum RAM in kilobytes (approximately 4GB)
                                  # Formula: 4GB = 4 * 1024 * 1024 = 4,194,304 KB
                                  # Using 3,900,000 KB to account for system overhead

# Storage Requirements
MIN_STORAGE_KB=38000000           # Minimum free disk space in kilobytes (approximately 40GB)
                                  # Formula: 40GB = 40 * 1024 * 1024 = 41,943,040 KB  
                                  # Using 38,000,000 KB to account for filesystem overhead
STORAGE_CHECK_PATH="/var/lib"     # Directory path to check for available disk space

# Supported Operating Systems
# Array of OS identifiers that are officially supported by this installer
SUPPORTED_OS_LIST=("centos" "debian" "ubuntu" "darwin")

#############################################################################

#############################################################################
# COMMAND LINE PARAMETERS PROCESSING
#############################################################################
# Process command line arguments for automated installation options

# Default values
AUTO_YES=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--yes)
            AUTO_YES=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [-y|--yes] [-h|--help]"
            echo ""
            echo "Options:"
            echo "  -y, --yes    Automatically answer 'yes' to all prompts"
            echo "  -h, --help   Display this help message"
            echo ""
            echo "Examples:"
            echo "  # Interactive mode (download first, then run):"
            echo "  curl -sSL <url> -o install.sh && chmod +x install.sh && ./install.sh"
            echo "  # Or using process substitution:"
            echo "  bash <(curl -sSL <url>)"
            echo ""
            echo "  # Automated mode (no prompts):"
            echo "  $0 -y        # Local execution"
            echo "  curl -sSL <url> | bash -s -- -y # Remote execution"
            echo ""
            exit 0
            ;;
        *)
            log "error" "Unknown option: $1" "+"
            echo "Use $0 --help for usage information"
            exit 1
            ;;
    esac
done

#############################################################################

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

# Helper functions

# Function: print_system_info
# Description: Displays system information including OS name, version, hostname and architecture
# Parameters: None
# Returns: Prints system info to stdout
# Dependencies: uname command
print_system_info () {
    OS_NAME=$(uname -s | tr '[:upper:]' '[:lower:]')
    OS_VERS=$(uname -r | tr '[:upper:]' '[:lower:]')
    OS_TYPE=$(uname -n | tr '[:upper:]' '[:lower:]')
    OS_ARCH=$(uname -m | tr '[:upper:]' '[:lower:]')

    # Print the OS information
    echo "OS Name: $OS_NAME ($OS_VERS)"
    echo "OS Type: $OS_TYPE"
    echo "OS Arch: $OS_ARCH"
}

# Function: convert_bytes
# Description: Converts byte values to human-readable format (GB/MB/Bytes)
# Parameters:
#   $1 - number of bytes to convert
# Returns: Formatted string with appropriate unit (GB/MB/Bytes)
# Dependencies: awk, printf
convert_bytes () {
    local bytes=$1

    if [[ $bytes -ge 1073741824 ]]; then
        # Convert to GB
        awk "BEGIN {printf \"%.2f GB\n\", $bytes / 1073741824}"
    elif [[ $bytes -ge 1048576 ]]; then
        # Convert to MB
        awk "BEGIN {printf \"%.2f MB\n\", $bytes / 1048576}"
    else
        # Less than 1 MB
        printf "%d Bytes\n" "$bytes"
    fi
}

# Function: convert_kilobytes
# Description: Converts kilobyte values to human-readable format (GB/MB/KB)
# Parameters:
#   $1 - number of kilobytes to convert
# Returns: Formatted string with appropriate unit (GB/MB/KB)
# Dependencies: awk, printf
convert_kilobytes () {
    local kilobytes=$1

    if [[ $kilobytes -ge 1048576 ]]; then
        # Convert to GB
        awk "BEGIN {printf \"%.2f GB\n\", $kilobytes / 1048576}"
    elif [[ $kilobytes -ge 1024 ]]; then
        # Convert to MB
        awk "BEGIN {printf \"%.2f MB\n\", $kilobytes / 1024}"
    else
        # Less than 1 MB
        printf "%d KB\n" "$kilobytes"
    fi
}

# Function: get_os_name
# Description: Determines the operating system name by checking system info and files
# Parameters: None
# Returns: OS identifier string (darwin, ubuntu, debian, centos, unknown)
# Dependencies: uname command, access to /etc/os-release, /etc/redhat-release, /etc/debian_version
# Note: Now supports macOS/Darwin detection via uname, uses fallback mechanism for older Linux systems
get_os_name () {
    # Check for macOS/Darwin first
    if [[ "$(uname -s)" == "Darwin" ]]; then
        echo "darwin"
    elif [[ -f /etc/os-release ]]; then
        # Source the os-release file
        . /etc/os-release
        echo "$ID" # ID gives the base name of the OS
    elif [[ -f /etc/redhat-release ]]; then
        echo "centos"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

# Function: check_os
# Description: Validates if current OS is supported by the installer
# Parameters: None
# Returns: Exits with code 0 if OS is unsupported, continues if supported
# Dependencies: get_os_name function, log function, SUPPORTED_OS_LIST global variable
# Supported OS: Defined in SUPPORTED_OS_LIST array
check_os () {
    os_name=$(get_os_name)
    if [[ " ${SUPPORTED_OS_LIST[@]} " =~ " ${os_name} " ]]; then
        log "ok" "Check OS [${os_name}]" "+"
    else 
        log "error" "Unsupported OS ${os_name}. Supported: ${SUPPORTED_OS_LIST[*]}. Exiting..." "+"
        exit 0
    fi
}

# Function: check_architecture
# Description: Validates if current CPU architecture is supported
# Parameters: None
# Returns: Logs success for supported arch, shows error for unsupported architectures
# Dependencies: uname command, log function, SUPPORTED_ARCH global variable
# Note: Supports x86_64, arm64, and aarch64 architectures
check_architecture () {
    cpu_type=$(uname -m)
    if [[ " ${SUPPORTED_ARCH[@]} " =~ " ${cpu_type} " ]]; then
        log "ok" "Check architecture [${cpu_type}]" "+"
    else 
        log "error" "SSPServer supports only ${SUPPORTED_ARCH[*]} CPU architectures, current is '${cpu_type}'. Exiting..." "+"
        exit 0
    fi
}

# Function: check_cpu
# Description: Verifies system has minimum required CPU cores (cross-platform)
# Parameters: None
# Returns: Exits with code 0 if insufficient cores, continues if adequate
# Dependencies: sysctl (macOS) or /proc/cpuinfo (Linux), log function, MIN_CPU_CORES global variable
# Requirement: Minimum CPU threads/cores defined in MIN_CPU_CORES
# Note: Now supports both Linux (/proc/cpuinfo) and macOS (sysctl) systems
check_cpu () {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        # macOS
        cpu_threads=$(sysctl -n hw.ncpu 2>/dev/null)
    else
        # Linux
        cpu_threads=$(grep -c ^processor /proc/cpuinfo 2>/dev/null)
    fi

    if [[ -z "$cpu_threads" ]] || [[ "$cpu_threads" -lt "$MIN_CPU_CORES" ]]; then
        log "error" "SSPServer requires ${MIN_CPU_CORES} or more CPU threads to operate. Current: ${cpu_threads:-unknown}. Exiting..." "+"
        exit 0
    else 
        log "ok" "Check CPU [${cpu_threads}]" "+"
    fi
}

# Function: check_ram
# Description: Verifies system has minimum required RAM (cross-platform)
# Parameters: None
# Returns: Exits with code 0 if insufficient RAM, continues if adequate
# Dependencies: sysctl (macOS) or /proc/meminfo (Linux), convert_kilobytes function, MIN_RAM_KB global variable
# Requirement: Minimum RAM defined in MIN_RAM_KB (default ~4GB)
# Note: Now supports both Linux (/proc/meminfo) and macOS (sysctl) systems
check_ram () {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        # macOS
        ram_bytes=$(sysctl -n hw.memsize 2>/dev/null)
        ram_total=$((ram_bytes / 1024))
    else
        # Linux
        ram_total=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
    fi

    if [[ -z "$ram_total" ]] || [[ "$ram_total" -lt "$MIN_RAM_KB" ]]; then
        ram_total_readable=$(convert_kilobytes ${ram_total:-0})
        min_ram_readable=$(convert_kilobytes $MIN_RAM_KB)
        log "error" "SSPServer requires ${min_ram_readable} of RAM to operate. Current: ${ram_total_readable}. Exiting..." "+"
        exit 0
    else
        ram_size=$(convert_kilobytes $ram_total)
        log "ok" "Check RAM [${ram_size}]" "+"
    fi
}

# Function: check_storage
# Description: Verifies system has minimum required free disk space (cross-platform)
# Parameters: None
# Returns: Exits with code 0 if insufficient space, continues if adequate
# Dependencies: df command (BSD/GNU variants), convert_kilobytes function, MIN_STORAGE_KB and STORAGE_CHECK_PATH global variables
# Requirement: Minimum free space defined in MIN_STORAGE_KB (default ~40GB) in STORAGE_CHECK_PATH directory
# Note: Now supports both Linux (GNU df --output) and macOS (BSD df) systems
check_storage () {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        # macOS - use BSD df syntax
        free_storage=$(df "$STORAGE_CHECK_PATH" 2>/dev/null | tail -1 | awk '{print $4}')
    else
        # Linux - use GNU df syntax
        free_storage=$(df --output=avail "$STORAGE_CHECK_PATH" 2>/dev/null | tail -n 1)
    fi

    if [[ -z "$free_storage" ]] || [[ "$free_storage" -lt "$MIN_STORAGE_KB" ]]; then
        free_storage_readable=$(convert_kilobytes ${free_storage:-0})
        min_storage_readable=$(convert_kilobytes $MIN_STORAGE_KB)
        log "error" "SSPServer requires ${min_storage_readable} of free disk storage in ${STORAGE_CHECK_PATH} to operate. Current: ${free_storage_readable}. Exiting..." "+"
        exit 0
    else
        storage_size=$(convert_kilobytes $free_storage)
        log "ok" "Free storage check [${storage_size}] in ${STORAGE_CHECK_PATH}" "+"
    fi
}

# Install the standalone version of the app

# Function: run_install_script
# Description: Downloads and executes OS-specific installation script from remote repository with error handling
# Parameters: None
# Returns: Executes the downloaded script, inherits its exit code
# Dependencies: get_os_name function, curl, chmod, bash, log function
# Remote URL: https://raw.githubusercontent.com/sspserver/deploy/refs/heads/build/standalone/install-{os-name}.sh
# Note: Now includes download validation and error handling for improved reliability
run_install_script () {
    os_name=$(get_os_name)
    URL=$(echo "${RUN_INSTALLER_SCRIPT_URI}" | sed "s/{{os-name}}/${os_name}/g")

    log "info" "Downloading OS-specific installer for ${os_name}..." "+"
    log "info" "Downloading installer from: ${URL}" "+"

    if ! curl -sSL "${URL}" -o "${TEMP_INSTALL_SCRIPT}"; then
        log "error" "Failed to download installation script from ${URL}" "+"
        log "error" "Download failed for URL: ${URL}" "+"
        exit 1
    fi

    if [[ ! -f "${TEMP_INSTALL_SCRIPT}" ]] || [[ ! -s "${TEMP_INSTALL_SCRIPT}" ]]; then
        log "error" "Downloaded script is empty or missing" "+"
        log "error" "Script validation failed: ${TEMP_INSTALL_SCRIPT}" "+"
        exit 1
    fi

    log "ok" "Script downloaded successfully, executing..." "+"
    chmod +x "${TEMP_INSTALL_SCRIPT}"

    # Pass the -y flag to the downloaded script if auto-confirmation is enabled
    if [[ "$AUTO_YES" == "true" ]]; then
        bash "${TEMP_INSTALL_SCRIPT}" -y
    else
        bash "${TEMP_INSTALL_SCRIPT}"
    fi

    # Store exit code before cleanup
    script_exit_code=$?

    # Clean up temporary file
    if [[ -f "${TEMP_INSTALL_SCRIPT}" ]]; then
        rm -f "${TEMP_INSTALL_SCRIPT}"
        log "info" "Temporary installer script cleaned up: ${TEMP_INSTALL_SCRIPT}" "+"
    fi

    # Exit with the same code as the installer script
    exit $script_exit_code
}

#############################################################################
# MAIN EXECUTION FLOW
#############################################################################
# The script follows a systematic validation approach before installation:
# 1. Display system information for troubleshooting
# 2. Validate OS compatibility  
# 3. Check CPU architecture requirements
# 4. Verify minimum CPU core count
# 5. Validate RAM requirements
# 6. Check available disk space
# 7. Download and execute OS-specific installer
#############################################################################

# 1. Print OS information
log "info" "System Information:" "+"
print_system_info

# 2. Check OS
log "info" "Checking OS..." "+"
check_os

# 3. Check architecture
log "info" "Checking architecture..." "+"
check_architecture

# 4. Check CPU
log "info" "Checking CPU..." "+"
check_cpu

# 5. Check RAM
log "info" "Checking RAM..." "+"
check_ram

# 6. Check storage
log "info" "Checking storage..." "+"
check_storage

log "ok" "All checks passed. Proceeding with the installation..." "+"
echo "==============================================="

# Ask user confirmation before proceeding
echo ""
if [[ "$AUTO_YES" == "true" ]]; then
    log "info" "Auto-confirmation mode enabled (-y flag). Proceeding with installation automatically." "+"
    log "info" "Installation proceeding automatically due to -y flag" "+"
else
    log "info" "Ready to download and execute OS-specific installation script." "+"
    log "info" "This will install SSP Server and all required dependencies." "+"
    echo ""
    
    # Check if we have a TTY (interactive terminal)
    if [ -t 0 ]; then
        # Interactive mode with TTY
        read -p "Do you want to continue with the installation? [y/N]: " -n 1 -r < /dev/tty
        echo ""
        
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "info" "Installation cancelled by user." "+"
            exit 0
        fi
    else
        # Non-interactive mode (e.g., piped from curl)
        log "info" "Non-interactive mode detected (no TTY)." "+"
        log "info" "To proceed automatically, use: curl -sSL <url> | bash -s -- -y" "+"
        log "info" "Installation cancelled by user." "+"
        exit 0
    fi
fi

log "info" "Starting installation..." "+"

# 7. Run the install script
run_install_script