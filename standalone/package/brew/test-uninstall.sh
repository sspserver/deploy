#!/bin/bash

# Test script for SSP Server Homebrew uninstall logic
# This script simulates the uninstall process without actually removing anything

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORMULA_FILE="$SCRIPT_DIR/sspserver.rb"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    local type="$1"
    local message="$2"
    
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
}

test_uninstall_logic() {
    log "info" "Testing uninstall logic consistency..."
    
    # Extract the uninstall commands from the wrapper script
    local wrapper_uninstall=$(sed -n '/uninstall)/,/;;/p' "$FORMULA_FILE" | grep -E "(sudo|docker|rm)" | wc -l)
    
    # Check that uninstall_preflight calls the wrapper script
    local preflight_calls_wrapper=$(grep -c "bin}/sspserver.*uninstall" "$FORMULA_FILE" || echo "0")
    
    if [[ $preflight_calls_wrapper -gt 0 ]]; then
        log "ok" "uninstall_preflight correctly delegates to wrapper script"
    else
        log "error" "uninstall_preflight does not call wrapper script"
        return 1
    fi
    
    # Check that SSPSERVER_UNINSTALL_FORCE is used
    local force_var_usage=$(grep -c "SSPSERVER_UNINSTALL_FORCE" "$FORMULA_FILE" || echo "0")
    
    if [[ $force_var_usage -ge 2 ]]; then
        log "ok" "SSPSERVER_UNINSTALL_FORCE environment variable is properly used"
    else
        log "warn" "SSPSERVER_UNINSTALL_FORCE usage might be incomplete"
    fi
    
    log "info" "Wrapper script has $wrapper_uninstall cleanup commands"
}

test_environment_variable_handling() {
    log "info" "Testing environment variable handling..."
    
    # Check that the formula sets and unsets the environment variable
    local env_set=$(grep -c 'ENV\[.*SSPSERVER_UNINSTALL_FORCE.*\] = ' "$FORMULA_FILE" || echo "0")
    local env_unset=$(grep -c 'ENV\.delete.*SSPSERVER_UNINSTALL_FORCE' "$FORMULA_FILE" || echo "0")
    
    if [[ $env_set -gt 0 && $env_unset -gt 0 ]]; then
        log "ok" "Environment variable is properly set and cleaned up"
    else
        log "error" "Environment variable handling is incomplete"
        return 1
    fi
}

test_fallback_logic() {
    log "info" "Testing fallback cleanup logic..."
    
    # Check that there's a fallback when wrapper script doesn't exist
    local fallback_exists=$(grep -c "Fallback.*manual cleanup" "$FORMULA_FILE" || echo "0")
    
    if [[ $fallback_exists -gt 0 ]]; then
        log "ok" "Fallback cleanup logic exists"
    else
        log "warn" "No fallback cleanup logic found"
    fi
}

test_no_duplication() {
    log "info" "Testing for code duplication..."
    
    # Check that Docker cleanup is not duplicated in uninstall_preflight
    local docker_in_preflight=$(sed -n '/def uninstall_preflight/,/^  end$/p' "$FORMULA_FILE" | grep -c "docker" || echo "0")
    
    if [[ $docker_in_preflight -eq 0 ]]; then
        log "ok" "No Docker cleanup duplication in uninstall_preflight"
    else
        log "warn" "Docker cleanup might be duplicated in uninstall_preflight"
    fi
    
    # Check that service cleanup is minimal in preflight
    local service_cleanup_lines=$(sed -n '/def uninstall_preflight/,/^  end$/p' "$FORMULA_FILE" | grep -E "(launchctl|rm -rf)" | wc -l)
    
    if [[ $service_cleanup_lines -le 4 ]]; then
        log "ok" "Minimal fallback cleanup in uninstall_preflight ($service_cleanup_lines lines)"
    else
        log "warn" "Potentially excessive cleanup duplication ($service_cleanup_lines lines)"
    fi
}

show_uninstall_flow() {
    log "info" "Uninstall flow:"
    echo "1. User runs: brew uninstall sspserver"
    echo "2. Homebrew calls: uninstall_preflight"
    echo "3. uninstall_preflight sets SSPSERVER_UNINSTALL_FORCE=1"
    echo "4. uninstall_preflight calls: sspserver uninstall"
    echo "5. sspserver uninstall runs automatically (no confirmation)"
    echo "6. sspserver uninstall cleans up services, docker, files"
    echo "7. Homebrew removes package files"
    echo "8. Complete cleanup finished"
}

main() {
    log "info" "Testing SSP Server uninstall logic..."
    
    if [[ ! -f "$FORMULA_FILE" ]]; then
        log "error" "Formula file not found: $FORMULA_FILE"
        exit 1
    fi
    
    local failed_tests=0
    
    test_uninstall_logic || ((failed_tests++))
    test_environment_variable_handling || ((failed_tests++))
    test_fallback_logic || ((failed_tests++))
    test_no_duplication || ((failed_tests++))
    
    echo ""
    show_uninstall_flow
    echo ""
    
    if [[ $failed_tests -eq 0 ]]; then
        log "ok" "All uninstall logic tests passed!"
        return 0
    else
        log "error" "$failed_tests test(s) failed"
        return 1
    fi
}

main "$@"
