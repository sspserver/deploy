#!/bin/bash

# Homebrew Tap Creation Script for SSP Server
# This script helps create and manage the Homebrew tap for SSP Server

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAP_NAME="sspserver/tap"
FORMULA_NAME="sspserver"
GITHUB_REPO="sspserver/homebrew-tap"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    local type="$1"
    local message="$2"
    local show_stdout="${3:-}"
    
    case "$type" in
        "error")
            echo -e "${RED}[ERROR]${NC} $message" >&2
            ;;
        "info")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        "ok")
            echo -e "${GREEN}[OK]${NC} $message"
            ;;
        "warn")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
    esac
    
    if [[ "$show_stdout" == "+" ]]; then
        echo "$message"
    fi
}

check_dependencies() {
    log "info" "Checking dependencies..."
    
    if ! command -v brew >/dev/null 2>&1; then
        log "error" "Homebrew is not installed. Please install Homebrew first."
        exit 1
    fi
    
    if ! command -v git >/dev/null 2>&1; then
        log "error" "Git is not installed. Please install Git first."
        exit 1
    fi
    
    log "ok" "All dependencies are available"
}

validate_formula() {
    log "info" "Validating formula..."
    
    if [[ ! -f "$SCRIPT_DIR/sspserver.rb" ]]; then
        log "error" "Formula file sspserver.rb not found in $SCRIPT_DIR"
        exit 1
    fi
    
    # Check formula syntax
    if ! brew formula "$SCRIPT_DIR/sspserver.rb" >/dev/null 2>&1; then
        log "warn" "Formula syntax validation failed, but continuing..."
    else
        log "ok" "Formula syntax is valid"
    fi
}

calculate_sha256() {
    log "info" "Calculating SHA256 for the source archive..."
    
    # This would need to be updated with the actual source URL
    local source_url="https://github.com/sspserver/deploy/archive/refs/heads/main.tar.gz"
    local temp_file=$(mktemp)
    
    if curl -L -s "$source_url" -o "$temp_file"; then
        local sha256=$(shasum -a 256 "$temp_file" | cut -d' ' -f1)
        log "ok" "SHA256: $sha256"
        
        # Update the formula with the correct SHA256
        sed -i.bak "s/sha256 \"[^\"]*\"/sha256 \"$sha256\"/" "$SCRIPT_DIR/sspserver.rb"
        rm "$SCRIPT_DIR/sspserver.rb.bak"
        
        log "ok" "Updated formula with correct SHA256"
    else
        log "warn" "Could not download source to calculate SHA256"
        log "warn" "Please update the SHA256 manually in the formula"
    fi
    
    rm -f "$temp_file"
}

create_tap_repo() {
    log "info" "Creating tap repository structure..."
    
    local tap_dir="homebrew-tap"
    
    if [[ -d "$tap_dir" ]]; then
        log "warn" "Tap directory already exists, removing..."
        rm -rf "$tap_dir"
    fi
    
    mkdir -p "$tap_dir/Formula"
    cd "$tap_dir"
    
    # Initialize git repository
    git init
    git config user.name "SSP Server Bot"
    git config user.email "bot@sspserver.org"
    
    # Copy formula
    cp "$SCRIPT_DIR/sspserver.rb" "Formula/sspserver.rb"
    
    # Create README
    cat > README.md << 'EOF'
# SSP Server Homebrew Tap

This is the official Homebrew tap for SSP Server.

## Usage

```bash
# Add the tap
brew tap sspserver/tap

# Install SSP Server
brew install sspserver

# Use SSP Server
sspserver install
```

## Commands

After installation, you can use the following commands:

- `sspserver install` - Install SSP Server
- `sspserver status` - Check service status
- `sspserver start` - Start service
- `sspserver stop` - Stop service
- `sspserver restart` - Restart service
- `sspserver logs` - View logs
- `sspserver uninstall` - Remove completely

## Requirements

- macOS 10.14 or later
- Docker (recommended: `brew install --cask docker`)

## Support

For issues and support, please visit our GitHub repository.
EOF
    
    # Create initial commit
    git add .
    git commit -m "Initial commit: Add sspserver formula"
    
    log "ok" "Tap repository created in $tap_dir/"
    cd ..
}

test_local_install() {
    log "info" "Testing local installation..."
    
    # Test formula syntax
    if brew formula "$SCRIPT_DIR/sspserver.rb" >/dev/null 2>&1; then
        log "ok" "Formula syntax is valid"
    else
        log "error" "Formula syntax is invalid"
        return 1
    fi
    
    # Try to install locally (dry run)
    log "info" "Performing dry-run installation test..."
    if brew install --dry-run "$SCRIPT_DIR/sspserver.rb" >/dev/null 2>&1; then
        log "ok" "Dry-run installation test passed"
    else
        log "warn" "Dry-run installation test failed (this may be expected)"
    fi
}

show_next_steps() {
    log "ok" "Homebrew tap creation completed!"
    echo ""
    log "info" "Next steps:" "+"
    echo "1. Push the tap repository to GitHub:"
    echo "   cd homebrew-tap"
    echo "   git remote add origin https://github.com/$GITHUB_REPO.git"
    echo "   git push -u origin main"
    echo ""
    echo "2. Test the tap locally:"
    echo "   brew tap sspserver/tap ./homebrew-tap"
    echo "   brew install sspserver"
    echo ""
    echo "3. Once published, users can install with:"
    echo "   brew tap sspserver/tap"
    echo "   brew install sspserver"
    echo ""
    echo "4. To update the formula later:"
    echo "   - Update version and sha256 in Formula/sspserver.rb"
    echo "   - Commit and push changes"
    echo "   - Users can update with: brew upgrade sspserver"
}

main() {
    log "info" "Starting Homebrew tap creation for SSP Server..."
    
    check_dependencies
    validate_formula
    calculate_sha256
    create_tap_repo
    test_local_install
    show_next_steps
    
    log "ok" "Homebrew tap setup completed successfully!"
}

# Command line argument handling
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [options]"
        echo ""
        echo "This script creates a Homebrew tap for SSP Server."
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --validate     Only validate the formula"
        echo "  --sha256       Only update SHA256"
        echo ""
        exit 0
        ;;
    --validate)
        validate_formula
        exit 0
        ;;
    --sha256)
        calculate_sha256
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
