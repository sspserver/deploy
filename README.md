# SSP Server Deployment Scripts

Automated deployment scripts for SSP Server using standalone mode with cross-platform support.

## 🚀 Quick Start

### Interactive Installation (Recommended)

```bash
# Download and run locally for interactive mode
curl -sSL https://raw.githubusercontent.com/sspserver/deploy/refs/heads/main/standalone/install.sh -o install.sh
chmod +x install.sh
./install.sh

# Or use process substitution for interactive mode
bash <(curl -sSL https://raw.githubusercontent.com/sspserver/deploy/refs/heads/main/standalone/install.sh)
```

### Automated Installation (No Prompts)

```bash
# For automated deployment without user interaction
curl -sSL https://raw.githubusercontent.com/sspserver/deploy/refs/heads/main/standalone/install.sh | bash -s -- -y
```

## 📋 System Requirements

- **OS**: Ubuntu/Debian Linux, macOS/Darwin (CentOS/RHEL planned)
- **CPU**: x86_64 architecture, minimum 2 cores
- **RAM**: Minimum 4GB
- **Storage**: Minimum 10GB free space
- **Network**: Internet connectivity for package downloads
- **Privileges**: Root or sudo access required

## 🔧 Installation Options

| Command | Mode | Description |
|---------|------|-------------|
| `./install.sh` | Interactive | Prompts for confirmation and domain configuration |
| `./install.sh -y` | Automated | Uses default settings, no user input required |
| `./install.sh -h` | Help | Shows usage information and examples |

## 🌐 Platform Support

### ✅ Fully Supported

- **Ubuntu/Debian**: Complete installation with systemd service management
- **macOS/Darwin**: Full support with launchd service management

### 🔄 In Development

- **CentOS/RHEL**: Planned support with systemd

## 📁 Project Structure

```text
standalone/
├── install.sh          # Universal installer with system checks
├── systems/
│   ├── ubuntu.sh       # Ubuntu/Debian specific installer
│   └── darwin.sh       # macOS/Darwin specific installer
└── README.md          # This file
```

## 🛠️ What Gets Installed

### System Dependencies

- **Ubuntu/Debian**: curl, unzip, jq, git, build-essential, ca-certificates
- **macOS**: Dependencies via Homebrew or MacPorts

### Services

- **Docker**: Container runtime (Docker CE on Ubuntu, Docker Desktop on macOS)
- **SSP Server**: Main application as system service
- **Service Manager**: systemd (Linux) or launchd (macOS)

### Configuration

- Service files and configurations
- Environment settings (domains, ports, etc.)
- Logging setup with unified log format

## ⚙️ Configuration

During interactive installation, you'll be prompted to configure:

- **SSP API Domain** (default: `apidemo.sspserver.org`)
- **SSP UI Domain** (default: `demo.sspserver.org`)
- **SSP Server Domain** (default: `sspdemo.sspserver.org`)

In automated mode (`-y` flag), default values are used.

## 📝 Logging

All installation activities are logged with unified format:

- **Log Location**: `/var/log/sspserver/sspserver_1click_standalone.log`
- **Log Format**: `[TIMESTAMP] [TYPE] Message`
- **Log Types**: `[ERROR]`, `[INFO]`, `[OK]`

## 🔍 Service Management

### Ubuntu/Debian (systemd)

```bash
# Check service status
systemctl status sspserver

# Start/stop/restart service
sudo systemctl start sspserver
sudo systemctl stop sspserver
sudo systemctl restart sspserver

# View logs
journalctl -u sspserver -f
```

### macOS (launchd)

```bash
# Check service status
sudo launchctl list | grep sspserver

# Start/stop service
sudo launchctl load /Library/LaunchDaemons/com.sspserver.plist
sudo launchctl unload /Library/LaunchDaemons/com.sspserver.plist

# View logs
tail -f /var/log/sspserver/sspserver_1click_standalone.log
```

## 🆘 Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure you have sudo/root privileges
2. **Network Issues**: Check internet connectivity and firewall settings
3. **Port Conflicts**: Ensure required ports are available
4. **Disk Space**: Verify sufficient free space (minimum 10GB)

### Debug Information

```bash
# Check system requirements
./install.sh --help

# View installation logs
tail -f /var/log/sspserver/sspserver_1click_standalone.log

# Check service status
# Ubuntu/Debian: systemctl status sspserver
# macOS: sudo launchctl list | grep sspserver
```

## 🔄 Updates

To update SSP Server, simply re-run the installation script:

```bash
# Interactive update
bash <(curl -sSL https://raw.githubusercontent.com/sspserver/deploy/refs/heads/main/standalone/install.sh)

# Automated update
curl -sSL https://raw.githubusercontent.com/sspserver/deploy/refs/heads/main/standalone/install.sh | bash -s -- -y
```

## 📞 Support

- **Documentation**: [SSP Server Docs](https://docs.sspserver.org)
- **Issues**: [GitHub Issues](https://github.com/sspserver/deploy/issues)
- **Community**: [SSP Server Community](https://community.sspserver.org)

## ⚖️ License

This project is licensed under the terms specified in the [LICENSE](LICENSE) file.
