#!/usr/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
OK="${GREEN}OK${NC}"
ERROR="${RED}ERROR${NC}"

LOG_DIR="/var/log/sspserver"
LOG_FILE="${LOG_DIR}/sspserver_1click_standalone.log"
INSTALL_DIR="/opt/sspserver"

RUN_INSTALLER_SCRIPT_URI="https://raw.githubusercontent.com/sspserver/deploy/refs/heads/build/standalone/install-{{os-name}}.sh"

mkdir -p "${LOG_DIR}"

log () {
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -" >> "${LOG_FILE}"
    echo "$(date '+%d-%m-%Y %H:%M:%S') $1" >> "${LOG_FILE}"
    if [ "$2" == "+" ]; then
        echo -e "$(date '+%d-%m-%Y %H:%M:%S') $1"
    fi
}

# Helper functions

print_info () {
    OS_NAME=$(uname -s | tr '[:upper:]' '[:lower:]')
    OS_VERS=$(uname -r | tr '[:upper:]' '[:lower:]')
    OS_TYPE=$(uname -n | tr '[:upper:]' '[:lower:]')
    OS_ARCH=$(uname -m | tr '[:upper:]' '[:lower:]')

    # Print the OS information
    echo "OS Name: $OS_NAME ($OS_VERS)"
    echo "OS Type: $OS_TYPE"
    echo "OS Arch: $OS_ARCH"
}

convert_bytes () {
    local bytes=$1

    if [[ $bytes -ge 1073741824 ]]; then
        # Convert to GB
        echo | awk "{printf \"%.2f GB\n\", $bytes / 1073741824}"
    elif [[ $bytes -ge 1048576 ]]; then
        # Convert to MB
        echo | awk "{printf \"%.2f MB\n\", $bytes / 1048576}"
    else
        # Less than 1 MB
        printf "%d Bytes\n" "$bytes"
    fi
}

convert_kilobytes () {
    local kilobytes=$1

    if [[ $kilobytes -ge 1048576 ]]; then
        # Convert to GB
        echo | awk "{printf \"%.2f GB\n\", $kilobytes / 1048576}"
    elif [[ $kilobytes -ge 1024 ]]; then
        # Convert to MB
        echo | awk "{printf \"%.2f MB\n\", $kilobytes / 1024}"
    else
        # Less than 1 MB
        printf "%d KB\n" "$kilobytes"
    fi
}

get_os_name () {
    if [[ -f /etc/os-release ]]; then
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

check_os () {
    os_name=$(get_os_name) # $(uname -s | tr '[:upper:]' '[:lower:]')
    supported_os=("centos" "debian" "ubuntu" "darwin")
    if [[ " ${supported_os[@]} " =~ " ${os_name} " ]]; then
        log "Check OS [${os_name}] - ${OK}" "+"
    else echo -e "${ERROR}: Unsupported OS ${os_name}. Exiting..."
        exit 0
    fi
}

check_architecture () {
    cpu_type=$(uname -m)
    if [ "$cpu_type" == "x86_64" ]; then
        log "Check architecture [${cpu_type}] - ${OK}" "+"
    else echo -e "${ERROR}: SSPServer should be installed only on x86/64 CPU architecture, current is '${cpu_type}'. Exiting..."
        # exit 0
    fi
}

check_cpu () {
    cpu_threads=$(grep -c ^processor /proc/cpuinfo)
    if [ "$cpu_threads" -lt 2 ] ; then
        echo -e "${ERROR}: SSPServer requires 2 or more CPU threads to operate. Exiting..."
        exit 0
    else log "Check CPU [${cpu_threads}] - ${OK}" "+"
    fi
}

check_ram () {
    ram_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    if [ "$ram_total" -lt 3900000 ] ; then
        echo -e "${ERROR}: There requires 4GB of RAM on the server for the SSPServer to operate. Exiting..."
        exit 0
    else
        ram_size=$(convert_kilobytes $ram_total)
        log "Check RAM [${ram_size}] - ${OK}" "+"
    fi
}

check_storage () {
    free_storage=$(df --output=avail "/var/lib" | tail -n 1)
    if  [[ "$free_storage" -lt 38000000 ]]; then
        echo -e "${ERROR}: There requires 40Gb of free disk storage to operate. Exiting..."
        exit 0
    else
        storage_size=$(convert_kilobytes $free_storage)
        log "Free storage check [${storage_size}] - ${OK}" "+"
    fi
}

# Install the standalone version of the app

run_install_script () {
    os_name=$(get_os_name)
    URL=`echo "${RUN_INSTALLER_SCRIPT_URI}" | sed "s/{{os-name}}/${os_name}/g"`
    curl -sSL "${URL}" -o /tmp/install_script.sh
    chmod +x /tmp/install_script.sh
    bash /tmp/install_script.sh
}

# 1. Print OS information
echo -e "${BLUE}System Information:>${NC}"
print_info

# 2. Check OS
echo -e "${BLUE}Checking OS...${NC}"
check_os

# 3. Check architecture
echo -e "${BLUE}Checking architecture...${NC}"
check_architecture

# 4. Check CPU
echo -e "${BLUE}Checking CPU...${NC}"
check_cpu

# 5. Check RAM
echo -e "${BLUE}Checking RAM...${NC}"
check_ram

# 6. Check storage
echo -e "${BLUE}Checking storage...${NC}"
check_storage

echo -e "${GREEN}All checks passed. Proceeding with the installation...${NC}"
echo "==============================================="

# 7. Run the install script
run_install_script