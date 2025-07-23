# SSP Server Homebrew Package

This directory contains the Homebrew formula and related tools for installing SSP Server on macOS.

## Files

- `sspserver.rb` - The main Homebrew formula
- `create-tap.sh` - Script to create and manage the Homebrew tap
- `test-formula.sh` - Script to test the formula before publishing
- `README.md` - This documentation

## Quick Start

### For Users

Install SSP Server via Homebrew:

```bash
# Add the tap (once published)
brew tap sspserver/tap

# Install SSP Server
brew install sspserver

# Install and start SSP Server
sspserver install

# Use automatic installation (no prompts)
sspserver install -y
```

### Available Commands

After installing the formula, you can use these commands:

```bash
sspserver install     # Install and configure SSP Server
sspserver status      # Check service status
sspserver start       # Start the service
sspserver stop        # Stop the service  
sspserver restart     # Restart the service
sspserver logs        # View logs (tail -f)
sspserver uninstall   # Remove SSP Server completely
```

## For Developers

### Testing the Formula

Before publishing, test the formula locally:

```bash
# Test formula syntax and audit
./test-formula.sh

# Test specific aspects
./test-formula.sh syntax    # Test Ruby/Homebrew syntax
./test-formula.sh audit     # Run brew audit
./test-formula.sh deps      # Check dependencies
./test-formula.sh dry-run   # Test installation dry-run
```

### Creating the Tap

To create the Homebrew tap for publishing:

```bash
# Create tap repository structure
./create-tap.sh

# This creates a 'homebrew-tap' directory ready for GitHub
```

### Local Testing

Test the formula locally without publishing:

```bash
# Test the formula directly
brew install ./sspserver.rb

# Or create a local tap
brew tap sspserver/tap ./homebrew-tap
brew install sspserver
```

## Formula Details

### Dependencies

The formula depends on:

- `curl` - For downloading components
- `unzip` - For extracting archives
- `jq` - For JSON processing
- `git` - For repository operations
- `docker` (recommended) - For containerized services

### Installation Process

1. Creates necessary directories in Homebrew prefix
2. Installs wrapper scripts and configuration templates
3. Creates a unified `sspserver` command for easy management
4. Sets up proper permissions and logging directories

### Service Management

The formula integrates with macOS launchd for service management:

- Services are managed via launchctl
- Logs are stored in `$(brew --prefix)/var/log/sspserver/`
- Configuration is stored in `$(brew --prefix)/etc/sspserver/`

## Publishing

### Prerequisites

1. Create a GitHub repository: `sspserver/homebrew-tap`
2. Update the SHA256 hash in the formula
3. Test the formula thoroughly

### Steps

1. Run the tap creation script:

   ```bash
   ./create-tap.sh
   ```

2. Push to GitHub:

   ```bash
   cd homebrew-tap
   git remote add origin https://github.com/sspserver/homebrew-tap.git
   git push -u origin main
   ```

3. Users can then install with:

   ```bash
   brew tap sspserver/tap
   brew install sspserver
   ```

## Updating the Formula

When releasing a new version:

1. Update the `version` field in `sspserver.rb`
2. Update the `url` to point to the new release
3. Calculate and update the `sha256` hash:

   ```bash
   ./create-tap.sh --sha256
   ```

4. Test the updated formula:

   ```bash
   ./test-formula.sh
   ```

5. Commit and push changes to the tap repository

## Uninstallation

### Complete Removal

To completely remove SSP Server and all its components:

```bash
# 1. Remove SSP Server application and services
sspserver uninstall

# 2. Remove the Homebrew package
brew uninstall sspserver

# 3. Remove the tap (optional)
brew untap sspserver/tap
```

### What Gets Removed

The `sspserver uninstall` command removes:

- SSP Server services and processes
- Docker containers and images
- Installation directory (`/opt/sspserver`)
- Configuration files (`/etc/sspserver`)
- System service files (launchd)

The `brew uninstall sspserver` command:

- Automatically runs `sspserver uninstall` in automated mode
- Removes the `sspserver` command and wrapper scripts
- Removes Homebrew-managed files and directories
- Removes package metadata

**Note:** When you run `brew uninstall sspserver`, it automatically calls `sspserver uninstall` to clean up all SSP Server components before removing the Homebrew package itself.

### Preserved Data

The following are preserved by default (manual removal required):

- Log files (in case you need them for debugging)
- Docker volumes (may contain important data)

For detailed uninstallation instructions, see [UNINSTALL.md](UNINSTALL.md).

## Troubleshooting

### Common Issues

1. **SHA256 Mismatch**: Update the hash using `./create-tap.sh --sha256`
2. **Permission Issues**: Ensure scripts are executable: `chmod +x *.sh`
3. **Docker Not Found**: Install Docker Desktop: `brew install --cask docker`
4. **Service Won't Start**: Check logs with `sspserver logs`
5. **Uninstall Issues**: See [UNINSTALL.md](UNINSTALL.md) for detailed removal steps

### Testing Commands

```bash
# Validate formula syntax
./test-formula.sh syntax

# Check for common issues
./test-formula.sh audit

# Test dry-run installation
./test-formula.sh dry-run

# Run all tests
./test-formula.sh all
```

## Support

For issues with the Homebrew formula:

1. Check the logs: `sspserver logs`
2. Verify Docker is running: `docker info`
3. Test formula locally: `./test-formula.sh`
4. Report issues on the GitHub repository

## License

This Homebrew formula is distributed under the same license as SSP Server.
