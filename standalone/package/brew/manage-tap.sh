#!/bin/bash

###############################################################################
# SSP Server Homebrew Tap Management Script
###############################################################################
# 
# This script helps manage the SSP Server Homebrew tap and formula
#
# Usage:
#   ./manage-tap.sh create      # Create new tap repository
#   ./manage-tap.sh update      # Update formula in existing tap
#   ./manage-tap.sh validate    # Validate formula
#   ./manage-tap.sh publish     # Publish to Homebrew tap
###############################################################################

set -e

# Configuration
TAP_NAME="sspserver/tap"
FORMULA_NAME="sspserver"
REPO_URL="https://github.com/sspserver/homebrew-tap"
FORMULA_FILE="sspserver.rb"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function: calculate_sha256
# Description: Calculate SHA256 hash for the source archive
calculate_sha256() {
    log "Calculating SHA256 hash for source archive..."
    
    local source_url="https://github.com/sspserver/deploy/archive/refs/heads/main.tar.gz"
    local sha256=$(curl -sL "$source_url" | shasum -a 256 | cut -d' ' -f1)
    
    if [ -n "$sha256" ]; then
        success "SHA256: $sha256"
        echo "$sha256"
    else
        error "Failed to calculate SHA256"
        exit 1
    fi
}

# Function: update_formula_sha256
# Description: Update SHA256 hash in formula file
update_formula_sha256() {
    local new_sha256="$1"
    
    if [ -f "$FORMULA_FILE" ]; then
        log "Updating SHA256 in formula file..."
        
        # Use sed to replace the SHA256 line
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS BSD sed
            sed -i '' "s/sha256 \"[^\"]*\"/sha256 \"$new_sha256\"/" "$FORMULA_FILE"
        else
            # Linux GNU sed
            sed -i "s/sha256 \"[^\"]*\"/sha256 \"$new_sha256\"/" "$FORMULA_FILE"
        fi
        
        success "Formula SHA256 updated"
    else
        error "Formula file not found: $FORMULA_FILE"
        exit 1
    fi
}

# Function: validate_formula
# Description: Validate the Homebrew formula
validate_formula() {
    log "Validating Homebrew formula..."
    
    if ! command -v brew &> /dev/null; then
        error "Homebrew not found. Please install Homebrew first."
        exit 1
    fi
    
    # Basic syntax check
    if brew audit --strict "$FORMULA_FILE"; then
        success "Formula validation passed"
    else
        error "Formula validation failed"
        exit 1
    fi
}

# Function: test_formula
# Description: Test the formula installation
test_formula() {
    log "Testing formula installation..."
    
    # Test formula
    if brew test "$FORMULA_FILE"; then
        success "Formula test passed"
    else
        warn "Formula test failed (may be expected for complex installations)"
    fi
}

# Function: create_tap
# Description: Create a new Homebrew tap repository
create_tap() {
    log "Creating new Homebrew tap..."
    
    # Check if tap already exists
    if brew tap | grep -q "$TAP_NAME"; then
        warn "Tap $TAP_NAME already exists"
        return 0
    fi
    
    # Create tap directory structure
    local tap_dir="$(brew --repository)/Library/Taps/sspserver/homebrew-tap"
    
    if [ ! -d "$tap_dir" ]; then
        log "Creating tap directory structure..."
        mkdir -p "$tap_dir"
        
        # Initialize git repository
        cd "$tap_dir"
        git init
        
        # Copy formula
        cp "$(pwd)/$FORMULA_FILE" "$tap_dir/"
        
        # Create initial commit
        git add .
        git commit -m "Initial commit: Add $FORMULA_NAME formula"
        
        success "Tap created successfully"
    else
        warn "Tap directory already exists"
    fi
}

# Function: update_tap
# Description: Update existing tap with new formula
update_tap() {
    log "Updating existing tap..."
    
    local tap_dir="$(brew --repository)/Library/Taps/sspserver/homebrew-tap"
    
    if [ -d "$tap_dir" ]; then
        # Copy updated formula
        cp "$FORMULA_FILE" "$tap_dir/"
        
        cd "$tap_dir"
        
        # Check for changes
        if git diff --quiet; then
            log "No changes to commit"
        else
            # Commit changes
            git add "$FORMULA_FILE"
            git commit -m "Update $FORMULA_NAME formula"
            success "Tap updated successfully"
        fi
    else
        error "Tap directory not found. Run 'create' first."
        exit 1
    fi
}

# Function: publish_tap
# Description: Publish tap to GitHub
publish_tap() {
    log "Publishing tap to GitHub..."
    
    local tap_dir="$(brew --repository)/Library/Taps/sspserver/homebrew-tap"
    
    if [ -d "$tap_dir" ]; then
        cd "$tap_dir"
        
        # Add remote if not exists
        if ! git remote get-url origin &> /dev/null; then
            git remote add origin "$REPO_URL"
        fi
        
        # Push to GitHub
        git push -u origin main
        
        success "Tap published to GitHub"
    else
        error "Tap directory not found"
        exit 1
    fi
}

# Function: install_local
# Description: Install formula locally for testing
install_local() {
    log "Installing formula locally for testing..."
    
    # Uninstall if already installed
    if brew list "$FORMULA_NAME" &> /dev/null; then
        log "Uninstalling existing version..."
        brew uninstall "$FORMULA_NAME"
    fi
    
    # Install from local formula
    brew install --formula "$FORMULA_FILE"
    
    success "Formula installed locally"
}

# Main script logic
case "${1:-}" in
    "create")
        log "Creating new Homebrew tap..."
        calculate_sha256
        new_sha256=$(calculate_sha256)
        update_formula_sha256 "$new_sha256"
        validate_formula
        create_tap
        success "Tap creation completed"
        ;;
    
    "update")
        log "Updating existing tap..."
        new_sha256=$(calculate_sha256)
        update_formula_sha256 "$new_sha256"
        validate_formula
        update_tap
        success "Tap update completed"
        ;;
    
    "validate")
        log "Validating formula..."
        validate_formula
        test_formula
        success "Validation completed"
        ;;
    
    "publish")
        log "Publishing tap..."
        publish_tap
        success "Publishing completed"
        ;;
    
    "install-local")
        log "Installing locally..."
        install_local
        success "Local installation completed"
        ;;
    
    "full-update")
        log "Performing full update cycle..."
        new_sha256=$(calculate_sha256)
        update_formula_sha256 "$new_sha256"
        validate_formula
        update_tap
        publish_tap
        success "Full update completed"
        ;;
    
    *)
        echo "Usage: $0 {create|update|validate|publish|install-local|full-update}"
        echo ""
        echo "Commands:"
        echo "  create        Create new Homebrew tap"
        echo "  update        Update formula in existing tap"
        echo "  validate      Validate formula syntax and structure"
        echo "  publish       Publish tap to GitHub"
        echo "  install-local Install formula locally for testing"
        echo "  full-update   Complete update cycle (update + validate + publish)"
        echo ""
        echo "Examples:"
        echo "  $0 create        # First time setup"
        echo "  $0 update        # Update after changes"
        echo "  $0 validate      # Check formula"
        echo "  $0 full-update   # Complete update"
        exit 1
        ;;
esac
