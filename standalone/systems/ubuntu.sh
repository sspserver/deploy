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
SYSTEMD_SERVICE_DIR="/etc/systemd/system"
OS_NAME="ubuntu"

DOWNLOAD_STANDALONE_URI="https://github.com/sspserver/deploy/raw/refs/heads/build/standalone/ubuntu.zip"

mkdir -p "${LOG_DIR}"

log () {
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -" >> "${LOG_FILE}"
    echo "$(date '+%d-%m-%Y %H:%M:%S') $1" >> "${LOG_FILE}"
    if [ "$2" == "+" ]; then
        echo -e "$(date '+%d-%m-%Y %H:%M:%S') $1"
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

install_dependencies () {
    log "${BLUE}Installing dependencies...${NC}" "+"

    # Check if apt-get is available
    if ! command -v apt-get &> /dev/null; then
        log "${RED}apt-get not found, please install it first.${NC}" "+"
        exit 1
    fi

    # Update package list and install dependencies
    log "Updating package list..." "+"
    apt-get -y update >> "${LOG_FILE}" 2>&1

    log "Installing dependencies..." "+"
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

install_systemd_dependency () {
    log "${BLUE}Installing systemd dependency...${NC}" "+"
    {
        apt-get -y install systemd
    } >> "${LOG_FILE}" 2>&1
    if [[ $? -ne 0 ]]; then
        log "Failed to install systemd dependency" "-"
        exit 1
    else
        log "Systemd dependency installed successfully" "+"
    fi
    # Check if systemd is running
    if ! systemctl is-active --quiet systemd; then
        log "Systemd is not running, starting it..." "+"
        systemctl start systemd
        if [[ $? -ne 0 ]]; then
            log "Failed to start systemd" "-"
            exit 1
        else
            log "Systemd started successfully" "+"
        fi
    else
        log "Systemd is already running" "+"
    fi
    # Check if systemd is enabled to start on boot
    if ! systemctl is-enabled --quiet systemd; then
        log "Enabling systemd to start on boot..." "+"
        systemctl enable systemd
        if [[ $? -ne 0 ]]; then
            log "Failed to enable systemd" "-"
            exit 1
        else
            log "Systemd enabled successfully" "+"
        fi
    else
        log "Systemd is already enabled to start on boot" "+"
    fi
}

install_docker () {
    log "${BLUE}Installing docker...${NC}" "+"
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
        log "Installing docker cli..." "+"
        {
            apt-get -y update
            apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        } >> "${LOG_FILE}" 2>&1
    fi
    # If docker-switch command not found, install compose-switch
    if ! [[ -f /usr/local/bin/compose-switch ]]; then
        log "Installing docker-compose-switch..." "+"
        {
            curl -fL https://github.com/docker/compose-switch/releases/latest/download/docker-compose-linux-amd64 -o /usr/local/bin/compose-switch
            chmod +x /usr/local/bin/compose-switch
            update-alternatives --install /usr/local/bin/docker-compose docker-compose /usr/local/bin/compose-switch 99
        } >> "${LOG_FILE}" 2>&1
    fi
    #wait for the file to be created
    if [ ! -f  /etc/docker/daemon.json ]; then
        touch /etc/docker/daemon.json && cat << EOF >> /etc/docker/daemon.json
    {
    "log-driver": "journald"
    }
EOF
    elif grep -qF '"log-driver": "journald"' /etc/docker/daemon.json; then
        :
    else cat << EOF >> /etc/docker/daemon.json
    {
    "log-driver": "journald"
    }
EOF
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

download_service_files () {
    log "${BLUE}Downloading service files...${NC}" "+"
    curl -sSL "${DOWNLOAD_STANDALONE_URI}" -o "${INSTALL_DIR}/sspserver.zip"
    if [[ $? -ne 0 ]]; then
        log "Failed to download service files" "+"
        exit 1
    fi

    log "Unzipping service files..." "+"
    unzip -o "${INSTALL_DIR}/sspserver.zip" -d "${INSTALL_DIR}" >> "${LOG_FILE}" 2>&1
    if [[ $? -ne 0 ]]; then
        log "Failed to unzip service files" "+"
        exit 1
    fi

    log "Service files downloaded and unzipped successfully" "+"
    rm "${INSTALL_DIR}/sspserver.zip"
}

prepare_general_environment () {
    log "${BLUE}Preparing general environment...${NC}" "+"

    ## Replace domains in .init.env
    read -p "Enter the domain for the SSP API server [apidemo.sspserver.org]: " SSPSERVER_API_DOMAIN
    SSPSERVER_API_DOMAIN=${SSPSERVER_API_DOMAIN:-apidemo.sspserver.org}
    sed -i "s/apidemo.sspserver.org/${SSPSERVER_API_DOMAIN}/g" ${INSTALL_DIR}/.init.env

    read -p "Enter the domain for the SSP UI server [demo.sspserver.org]: " SSPSERVER_UI_DOMAIN
    SSPSERVER_UI_DOMAIN=${SSPSERVER_UI_DOMAIN:-demo.sspserver.org}
    sed -i "s/demo.sspserver.org/${SSPSERVER_UI_DOMAIN}/g" ${INSTALL_DIR}/.init.env

    read -p "Enter the domain for the SSP server [sspdemo.sspserver.org]: " SSPSERVER_DOMAIN
    SSPSERVER_DOMAIN=${SSPSERVER_DOMAIN:-sspdemo.sspserver.org}
    sed -i "s/sspdemo.sspserver.org/${SSPSERVER_DOMAIN}/g" ${INSTALL_DIR}/.init.env
}

prepare_sspservice () {
    log "${BLUE}Preparing SSP service...${NC}" "+"
    cp ${INSTALL_DIR}/sspserver/sspserver.service ${SYSTEMD_SERVICE_DIR}/sspserver.service

    chmod 644 ${SYSTEMD_SERVICE_DIR}/sspserver.service

    systemctl daemon-reload
    systemctl enable sspserver.service
    # Stop and start the service to apply changes
    log "Restarting SSP service..." "+"
    if systemctl is-active --quiet sspserver.service; then
        systemctl stop sspserver.service
        log "SSP service is already running, stopping it..." "+"
    else
        log "SSP service is not running, starting it for the first time..." "+"
    fi
    systemctl start sspserver.service
    if [[ $? -ne 0 ]]; then
        log "Failed to start SSP service" "+"
        exit 1
    else
        log "SSP service started successfully" "+"
    fi
}

###############################################################################
## Standalone installation script for SSP Server on Ubuntu
###############################################################################

# 1. Install dependencies
install_dependencies

# 2. Install systemd dependency if not installed
log "${BLUE}Checking for systemd...${NC}" "+"
if ! command -v systemctl &> /dev/null
then
    log "${RED}Systemd not found, installing...${NC}" "+"
    install_systemd_dependency
else
    log "${GREEN}Systemd is already installed${NC}" "+"
fi

# 3. Install docker if not installed
log "${BLUE}Checking for Docker...${NC}" "+"
if ! command -v docker &> /dev/null
then
    log "${RED}Docker not found, installing...${NC}" "+"
    install_docker
else
    log "${GREEN}Docker is already installed${NC}" "+"
fi

# 4. Download and prepare service files
download_service_files

# 5. Prepare project environment
prepare_general_environment

# 6. Pull SSP Server service
prepare_sspservice
