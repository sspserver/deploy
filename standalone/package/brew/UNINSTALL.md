# SSP Server Uninstallation Guide

This guide explains how to properly remove SSP Server when it was installed via Homebrew.

## Quick Uninstall

For complete removal of SSP Server and all its components:

```bash
# 1. Remove SSP Server application and services
sspserver uninstall

# 2. Remove the Homebrew package
brew uninstall sspserver

# 3. Remove the tap (optional)
brew untap sspserver/tap
```

## Step-by-Step Uninstallation

### Step 1: Stop and Remove SSP Server Application

The `sspserver uninstall` command will:

- Stop all running SSP Server services
- Remove Docker containers and images
- Delete installation directory (`/opt/sspserver`)
- Remove configuration files (`/etc/sspserver`)
- Remove launchd service files

```bash
sspserver uninstall
```

This will show you what will be removed and ask for confirmation:

```text
Uninstalling SSP Server...
This will remove:
  - SSP Server services
  - Docker containers and images
  - Installation directory (/opt/sspserver)
  - Configuration files (/etc/sspserver)
  - Service files (/Library/LaunchDaemons/org.sspserver.sspserver.plist)

Are you sure you want to continue? (y/N):
```

### Step 2: Remove Homebrew Package

Remove the Homebrew formula and wrapper scripts:

```bash
brew uninstall sspserver
```

**Note:** When you run `brew uninstall sspserver`, Homebrew will automatically call `sspserver uninstall` in automated mode (no confirmation prompts) to clean up all SSP Server components before removing the package itself.

This removes:

- The `sspserver` command
- Homebrew-managed configuration templates
- Package metadata

### Step 3: Clean Up Remaining Files (Optional)

#### Remove Logs

Logs are preserved by default. To remove them:

```bash
# Remove Homebrew-managed logs
rm -rf $(brew --prefix)/var/log/sspserver

# Remove system logs (if any)
sudo rm -rf /var/log/sspserver
```

#### Remove Docker Resources

If you want to remove all Docker resources:

```bash
# Remove all SSP Server related containers
docker ps -a --filter "name=sspserver" -q | xargs docker rm -f

# Remove all SSP Server related images
docker images --filter "reference=sspserver*" -q | xargs docker rmi -f

# Remove unused Docker volumes (optional)
docker volume prune
```

#### Remove Tap

If you no longer need the SSP Server tap:

```bash
brew untap sspserver/tap
```

## Verification

After uninstallation, verify that everything is removed:

```bash
# Check that command is not available
sspserver --help
# Should output: command not found

# Check that no services are running
launchctl list | grep sspserver
# Should return nothing

# Check that directories are removed
ls -la /opt/sspserver
# Should output: No such file or directory

ls -la /etc/sspserver
# Should output: No such file or directory

# Check Docker containers
docker ps -a --filter "name=sspserver"
# Should show no containers

# Check Docker images
docker images --filter "reference=sspserver*"
# Should show no images
```

## Troubleshooting

### Permission Issues

If you encounter permission errors:

```bash
# Make sure you have sudo access
sudo -v

# Force remove stuck launchd services
sudo launchctl remove org.sspserver.sspserver 2>/dev/null || true
sudo rm -f /Library/LaunchDaemons/org.sspserver.sspserver.plist
```

### Docker Issues

If Docker containers won't stop:

```bash
# Force stop all SSP Server containers
docker ps --filter "name=sspserver" -q | xargs docker kill

# Force remove all SSP Server containers
docker ps -a --filter "name=sspserver" -q | xargs docker rm -f
```

### Partial Installation Issues

If the installation was incomplete or corrupted:

```bash
# Try to clean up manually
sudo launchctl unload /Library/LaunchDaemons/org.sspserver.sspserver.plist 2>/dev/null || true
sudo rm -f /Library/LaunchDaemons/org.sspserver.sspserver.plist
sudo rm -rf /opt/sspserver
sudo rm -rf /etc/sspserver

# Then proceed with Homebrew uninstall
brew uninstall sspserver --force
```

## Reinstallation

After complete uninstallation, you can reinstall cleanly:

```bash
# Add tap
brew tap sspserver/tap

# Install
brew install sspserver

# Install and configure
sspserver install
```

## What Gets Removed vs Preserved

### Removed by `sspserver uninstall`

- ✅ SSP Server application files
- ✅ Docker containers and images
- ✅ System services (launchd)
- ✅ Configuration files
- ✅ Installation directory

### Removed by `brew uninstall sspserver`

- ✅ Homebrew package
- ✅ `sspserver` command
- ✅ Package dependencies (if not used by other packages)

### Preserved (manual removal required)

- 📁 Log files (in case you need them)
- 📁 Docker volumes (in case they contain important data)
- 📁 Custom configurations you may have created outside standard locations

This approach ensures safe uninstallation while preserving potentially important data that users might want to keep.
