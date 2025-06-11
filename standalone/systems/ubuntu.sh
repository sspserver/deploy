#!/usr/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
OK="${GREEN}OK${NC}"
ERROR="${RED}ERROR${NC}"

LOG_DIR="/var/log/sspserver"
LOG_FILE="${LOG_DIR}/sspserver_1click_standalone.log"

PROJECT_DIR="/opt/sspserver"

install_docker () {
    log "Installing docker..." "+"
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

download_project () {
  if [ -d ${PROJECT_DIR} ]; then
    log "SSP Server project already exists" "+"
    return
  fi

  mkdir -p ${PROJECT_DIR}
  cd ${PROJECT_DIR}

  log "Downloading SSP Server project..." "+"
  curl -fsSL https://github.com/sspserver/sspserver/archive/refs/heads/main.zip -o sspserver.zip >> "${LOG_FILE}" 2>&1
  unzip sspserver.zip >> "${LOG_FILE}" 2>&1
  rm sspserver.zip
  mv sspserver-main/* ./ && rm -rf sspserver-main
  log "SSP Server project downloaded" "+"
}
