#!/usr/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
OK="${GREEN}OK${NC}"
ERROR="${RED}ERROR${NC}"
INFO="${BLUE}INFO${NC}"

# install_docker () {
#     log "Installing docker.." "+"
#     if ! [[ -f /etc/apt/sources.list.d/docker.list ]]; then
#         {
#             mkdir -p /etc/apt/keyrings
#             curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg >> "${log_file}" 2>&1
#             chmod a+r /etc/apt/keyrings/docker.gpg
#         } >> "${log_file}" 2>&1
#         echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
#         {
#             apt-get -y update
#             apt-get -y install \
#                 docker-ce="${DOCKER_VERSION}" \
#                 docker-ce-cli="${DOCKER_VERSION}" \
#                 containerd.io \
#                 docker-compose-plugin
#         } >> "${log_file}" 2>&1
#     fi
#     if ! [[ -f /usr/local/bin/compose-switch ]]; then
#         {
#             curl -fL https://github.com/docker/compose-switch/releases/latest/download/docker-compose-linux-amd64 -o /usr/local/bin/compose-switch
#             chmod +x /usr/local/bin/compose-switch
#             update-alternatives --install /usr/local/bin/docker-compose docker-compose /usr/local/bin/compose-switch 99
#         } >> "${log_file}" 2>&1
#     fi
#     #wait for the file to be created
#     if [ ! -f  /etc/docker/daemon.json ]; then
#         touch /etc/docker/daemon.json && cat << EOF >> /etc/docker/daemon.json
#     {
#     "log-driver": "journald"
#     }
# EOF
#     elif grep -qF '"log-driver": "journald"' /etc/docker/daemon.json; then
#         :
#     else cat << EOF >> /etc/docker/daemon.json
#     {
#     "log-driver": "journald"
#     }
# EOF
#     fi
#     #journald max file restriction
#     echo "SystemMaxUse=2G" >> /etc/systemd/journald.conf
#     systemctl restart systemd-journald
#     #waiting for journald to get up
#     jstatus=$(systemctl is-active systemd-journald)
#     while [ "$jstatus" != "active" ]; do
#         echo "$jstatus"
#         sleep 2
#         jstatus=$(systemctl is-active systemd-journald)
#     done
# }

check_is_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${ERROR}: This script must be run as root."
        exit 1
    fi
}

install_docker() {
    echo "Installing required packages..."
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        software-properties-common

    echo "Adding Docker's official GPG key..."
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    echo "Adding Docker's repository to APT sources..."
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    echo "Updating package database again to include Docker's repository..."
    apt-get update -y

    echo "Installing Docker Engine..."
    apt-get install -y docker-ce docker-ce-cli containerd.io

    echo "Verifying Docker installation..."
    if command -v docker > /dev/null; then
        echo -e "${OK}: Docker installed successfully!"
    else
        echo -e "${ERROR}: Docker installation failed."
        return 1
    fi

    echo "Installing Docker Compose..."
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -oP '(?<=tag_name": "v)[^"]+')
    curl -L "https://github.com/docker/compose/releases/download/v$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    echo "Verifying Docker Compose installation..."
    if command -v docker-compose > /dev/null; then
        echo -e "${OK}: Docker Compose installed successfully!"
    else
        echo -e "${ERROR}: Docker Compose installation failed."
        return 1
    fi

    echo -e "${OK}: Installation complete!"
}

is_systemd_enabled() {
    if [[ "$(ps -p 1 -o comm=)" == "systemd" ]]; then
        echo -e "${INFO}: systemd is enabled as the init system."
        return 0
    else
        echo -e "${INFO}: systemd is not enabled as the init system."
        return 1
    fi
}

register_docker_daemon_systemd () {
    echo -e "Enabling Docker service to start on boot..."

    # Enable the Docker service
    systemctl enable docker

    # Start the Docker service if it’s not already running
    echo "Starting Docker service..."
    systemctl start docker

    # Check the status of the Docker service
    if systemctl is-active --quiet docker; then
        echo -e "${OK}: Docker service is running and enabled on boot."
    else
        echo -e "${ERROR}: Failed to start or enable Docker service."
        return 1
    fi
}

register_docker_daemon_non_systemd () {
    echo "Configuring Docker daemon for non-systemd systems..."

    # Check if Docker service file exists
    if [[ -f /etc/init.d/docker ]]; then
        echo "Found Docker init script. Enabling Docker to start on boot..."

        # Enable Docker at startup
        update-rc.d docker defaults

        echo "Starting Docker service..."
        service docker start

        # Verify Docker is running
        if ps aux | grep -v grep | grep -q docker; then
            echo -e "${OK}: Docker service is running and enabled on boot."
        else
            echo -e "${ERROR}: Failed to start Docker service."
            return 1
        fi
    else
        echo -e "${ERROR}: Docker init script not found. Please check your Docker installation."
        return 1
    fi
}

register_docker_daemon () {
    if is_systemd_enabled; then
        register_docker_daemon_systemd
    else
        register_docker_daemon_non_systemd
    fi
}

# Check if the script is being run as root
check_is_root

# Update the package database
echo "Updating package database..."
apt-get update -y

echo "Install dependencies..."
apt-get install -y \
    curl \
    gnupg \
    lsb-release

# Install Docker
install_docker

# Register Docker daemon
register_docker_daemon
