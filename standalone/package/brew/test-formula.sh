#!/bin/bash

# SSP Server Homebrew Testing Script
# This script helps test the Homebrew formula locally before publishing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORMULA_FILE="$SCRIPT_DIR/sspserver.rb"
TEST_PREFIX="/tmp/sspserver-test"

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

cleanup() {
    if [[ -d "$TEST_PREFIX" ]]; then
        log "info" "Cleaning up test directory..."
        rm -rf "$TEST_PREFIX"
    fi
}

trap cleanup EXIT

test_formula_syntax() {
    log "info" "Testing formula syntax..."
    
    if [[ ! -f "$FORMULA_FILE" ]]; then
        log "error" "Formula file not found: $FORMULA_FILE"
        return 1
    fi
    
    # Test Ruby syntax
    if ruby -c "$FORMULA_FILE" >/dev/null 2>&1; then
        log "ok" "Ruby syntax is valid"
    else
        log "error" "Ruby syntax error in formula"
        return 1
    fi
    
    # Test Homebrew formula syntax
    if brew formula "$FORMULA_FILE" >/dev/null 2>&1; then
        log "ok" "Homebrew formula syntax is valid"
    else
        log "error" "Homebrew formula syntax error"
        brew formula "$FORMULA_FILE" 2>&1 || true
        return 1
    fi
}

test_formula_audit() {
    log "info" "Auditing formula..."
    
    # Run brew audit on the formula
    if brew audit --strict "$FORMULA_FILE" 2>/dev/null; then
        log "ok" "Formula audit passed"
    else
        log "warn" "Formula audit has warnings:"
        brew audit --strict "$FORMULA_FILE" 2>&1 || true
    fi
}

test_dependencies() {
    log "info" "Checking formula dependencies..."
    
    # Extract dependencies from formula
    local deps=$(grep -E "depends_on" "$FORMULA_FILE" | sed 's/.*"//;s/".*//' | tr '\n' ' ')
    
    log "info" "Formula dependencies: $deps"
    
    for dep in $deps; do
        if [[ "$dep" == "docker" ]]; then
            # Docker is special case - can be cask or formula
            if command -v docker >/dev/null 2>&1; then
                log "ok" "Docker is available"
            else
                log "warn" "Docker not found - users will need to install Docker"
            fi
        else
            if brew list "$dep" >/dev/null 2>&1; then
                log "ok" "Dependency $dep is installed"
            else
                log "warn" "Dependency $dep is not installed"
            fi
        fi
    done
}

test_dry_run_install() {
    log "info" "Testing dry-run installation..."
    
    # Create temporary prefix for testing
    mkdir -p "$TEST_PREFIX"
    
    # Test installation without actually installing
    if brew install --dry-run "$FORMULA_FILE" 2>/dev/null; then
        log "ok" "Dry-run installation test passed"
    else
        log "warn" "Dry-run installation test failed:"
        brew install --dry-run "$FORMULA_FILE" 2>&1 || true
    fi
}

test_formula_info() {
    log "info" "Testing formula information extraction..."
    
    # Test that we can extract basic info from formula
    local name=$(brew formula "$FORMULA_FILE" --json | jq -r '.[0].name' 2>/dev/null || echo "unknown")
    local version=$(brew formula "$FORMULA_FILE" --json | jq -r '.[0].versions.stable' 2>/dev/null || echo "unknown")
    local desc=$(brew formula "$FORMULA_FILE" --json | jq -r '.[0].desc' 2>/dev/null || echo "unknown")
    
    log "info" "Formula name: $name"
    log "info" "Formula version: $version"
    log "info" "Formula description: $desc"
    
    if [[ "$name" != "unknown" && "$version" != "unknown" ]]; then
        log "ok" "Formula information extraction successful"
    else
        log "warn" "Could not extract all formula information"
    fi
}

test_wrapper_script() {
    log "info" "Testing wrapper script generation..."
    
    # Extract the wrapper script from the formula and test its syntax
    local temp_script="/tmp/sspserver-wrapper-test.sh"
    
    # Extract the wrapper script content (between <<~EOS and EOS)
    sed -n '/<<~EOS/,/^[[:space:]]*EOS$/p' "$FORMULA_FILE" | sed '1d;$d' > "$temp_script"
    
    if [[ -s "$temp_script" ]]; then
        if bash -n "$temp_script" 2>/dev/null; then
            log "ok" "Wrapper script syntax is valid"
        else
            log "error" "Wrapper script has syntax errors"
            bash -n "$temp_script" 2>&1 || true
        fi
    else
        log "error" "Could not extract wrapper script from formula"
    fi
    
    rm -f "$temp_script"
}

run_all_tests() {
    log "info" "Running all formula tests..."
    
    local failed_tests=0
    
    test_formula_syntax || ((failed_tests++))
    test_formula_audit || ((failed_tests++))
    test_dependencies || ((failed_tests++))
    test_dry_run_install || ((failed_tests++))
    test_formula_info || ((failed_tests++))
    test_wrapper_script || ((failed_tests++))
    
    if [[ $failed_tests -eq 0 ]]; then
        log "ok" "All tests passed!"
        return 0
    else
        log "warn" "$failed_tests test(s) failed or had warnings"
        return 1
    fi
}

show_usage() {
    echo "Usage: $0 [test_name]"
    echo ""
    echo "Available tests:"
    echo "  syntax      - Test formula syntax"
    echo "  audit       - Audit formula"
    echo "  deps        - Check dependencies"
    echo "  dry-run     - Test dry-run installation"
    echo "  info        - Test formula info extraction"
    echo "  wrapper     - Test wrapper script"
    echo "  all         - Run all tests (default)"
    echo ""
    echo "Examples:"
    echo "  $0              # Run all tests"
    echo "  $0 syntax       # Test only syntax"
    echo "  $0 audit        # Audit formula only"
}

main() {
    local test_name="${1:-all}"
    
    case "$test_name" in
        syntax)
            test_formula_syntax
            ;;
        audit)
            test_formula_audit
            ;;
        deps)
            test_dependencies
            ;;
        dry-run)
            test_dry_run_install
            ;;
        info)
            test_formula_info
            ;;
        wrapper)
            test_wrapper_script
            ;;
        all)
            run_all_tests
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            log "error" "Unknown test: $test_name"
            show_usage
            exit 1
            ;;
    esac
}

# Check if Homebrew is available
if ! command -v brew >/dev/null 2>&1; then
    log "error" "Homebrew is not installed. Please install Homebrew first."
    exit 1
fi

main "$@"
