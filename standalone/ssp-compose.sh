#!/bin/bash

# SSP Server Modular Docker Compose Manager
# This script manages modular deployment with external or containerized services

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_CONFIG="$SCRIPT_DIR/.deployment.env"
COMPOSE_FILES_DIR="$SCRIPT_DIR"

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

load_config() {
    if [[ -f "$DEPLOYMENT_CONFIG" ]]; then
        source "$DEPLOYMENT_CONFIG"
        log "ok" "Loaded deployment configuration"
    else
        log "warn" "Deployment config not found, using defaults"
        # Set defaults
        POSTGRES_MODE="${POSTGRES_MODE:-container}"
        CLICKHOUSE_MODE="${CLICKHOUSE_MODE:-container}"
        REDIS_MODE="${REDIS_MODE:-container}"
    fi
}

build_compose_command() {
    local compose_files=()
    local action="$1"
    
    # Always start with base services
    compose_files+=("-f" "docker-compose.base.yml")
    
    # Add database services based on configuration
    if [[ "$POSTGRES_MODE" == "container" ]]; then
        compose_files+=("-f" "docker-compose.postgres.yml")
        log "info" "Including PostgreSQL container"
    else
        log "info" "Using external PostgreSQL at $POSTGRES_HOST:$POSTGRES_PORT"
    fi
    
    if [[ "$CLICKHOUSE_MODE" == "container" ]]; then
        compose_files+=("-f" "docker-compose.clickhouse.yml")
        log "info" "Including ClickHouse container"
    else
        log "info" "Using external ClickHouse at $CLICKHOUSE_HOST:$CLICKHOUSE_HTTP_PORT"
    fi
    
    if [[ "$REDIS_MODE" == "container" ]]; then
        compose_files+=("-f" "docker-compose.redis.yml")
        log "info" "Including Redis container"
    else
        log "info" "Using external Redis at $REDIS_HOST:$REDIS_PORT"
    fi
    
    # Add dependencies file if we have any containerized services
    local has_containers=false
    [[ "$POSTGRES_MODE" == "container" || "$CLICKHOUSE_MODE" == "container" || "$REDIS_MODE" == "container" ]] && has_containers=true
    
    if [[ "$has_containers" == "true" ]]; then
        compose_files+=("-f" "docker-compose.dependencies.yml")
    fi
    
    # Use dynamic compose approach
    echo "docker compose" "${compose_files[@]}"
}

show_config() {
    log "info" "Current deployment configuration:"
    echo ""
    echo "Database Services:"
    echo "  PostgreSQL: $POSTGRES_MODE"
    if [[ "$POSTGRES_MODE" == "external" ]]; then
        echo "    Host: $POSTGRES_HOST:$POSTGRES_PORT"
        echo "    Database: $POSTGRES_DB"
        echo "    User: $POSTGRES_USER"
    fi
    echo ""
    echo "  ClickHouse: $CLICKHOUSE_MODE"
    if [[ "$CLICKHOUSE_MODE" == "external" ]]; then
        echo "    Host: $CLICKHOUSE_HOST:$CLICKHOUSE_HTTP_PORT"
        echo "    Database: $CLICKHOUSE_DB"
        echo "    User: $CLICKHOUSE_USER"
    fi
    echo ""
    echo "  Redis: $REDIS_MODE"
    if [[ "$REDIS_MODE" == "external" ]]; then
        echo "    Host: $REDIS_HOST:$REDIS_PORT"
    fi
    echo ""
    echo "SSP Services (always containerized):"
    echo "  SSP Server: localhost:$SSP_SERVER_PORT"
    echo "  SSP API: localhost:$SSP_API_PORT" 
    echo "  SSP Control: localhost:$SSP_CONTROL_PORT"
    echo "  Nginx Proxy: localhost:$NGINX_HTTP_PORT (HTTP), localhost:$NGINX_HTTPS_PORT (HTTPS)"
    
    # Show which compose files will be used
    echo ""
    local cmd_array=($(build_compose_command "config"))
    echo "Docker Compose Files:"
    for ((i=2; i<${#cmd_array[@]}; i+=2)); do
        if [[ "${cmd_array[i]}" == "-f" ]]; then
            echo "  - ${cmd_array[i+1]}"
        fi
    done
}

check_external_services() {
    local failed_checks=0
    
    if [[ "$POSTGRES_MODE" == "external" ]]; then
        log "info" "Checking external PostgreSQL connection..."
        if command -v pg_isready >/dev/null 2>&1; then
            if pg_isready -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" >/dev/null 2>&1; then
                log "ok" "PostgreSQL is accessible"
            else
                log "error" "Cannot connect to PostgreSQL at $POSTGRES_HOST:$POSTGRES_PORT"
                ((failed_checks++))
            fi
        else
            log "warn" "pg_isready not available, skipping PostgreSQL check"
        fi
    fi
    
    if [[ "$CLICKHOUSE_MODE" == "external" ]]; then
        log "info" "Checking external ClickHouse connection..."
        if command -v curl >/dev/null 2>&1; then
            if curl -s "http://$CLICKHOUSE_HOST:$CLICKHOUSE_HTTP_PORT/ping" >/dev/null 2>&1; then
                log "ok" "ClickHouse is accessible"
            else
                log "error" "Cannot connect to ClickHouse at $CLICKHOUSE_HOST:$CLICKHOUSE_HTTP_PORT"
                ((failed_checks++))
            fi
        else
            log "warn" "curl not available, skipping ClickHouse check"
        fi
    fi
    
    if [[ "$REDIS_MODE" == "external" ]]; then
        log "info" "Checking external Redis connection..."
        if command -v redis-cli >/dev/null 2>&1; then
            if redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping >/dev/null 2>&1; then
                log "ok" "Redis is accessible"
            else
                log "error" "Cannot connect to Redis at $REDIS_HOST:$REDIS_PORT"
                ((failed_checks++))
            fi
        else
            log "warn" "redis-cli not available, skipping Redis check"
        fi
    fi
    
    return $failed_checks
}

generate_env_file() {
    local env_file="$SCRIPT_DIR/.services.env"
    
    log "info" "Generating services environment file..."
    
    cat > "$env_file" << EOF
# Generated environment file for SSP Server services
# This file is automatically generated by ssp-compose.sh

# Database Connection Settings
POSTGRES_HOST=${POSTGRES_MODE:+${POSTGRES_HOST:-postgres-server}}
POSTGRES_PORT=${POSTGRES_PORT:-5432}
POSTGRES_DB=${POSTGRES_DB:-sspserver}
POSTGRES_USER=${POSTGRES_USER:-sspserver}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-changeme}

CLICKHOUSE_HOST=${CLICKHOUSE_MODE:+${CLICKHOUSE_HOST:-clickhouse-server}}
CLICKHOUSE_HTTP_PORT=${CLICKHOUSE_HTTP_PORT:-8123}
CLICKHOUSE_TCP_PORT=${CLICKHOUSE_TCP_PORT:-9000}
CLICKHOUSE_DB=${CLICKHOUSE_DB:-sspserver}
CLICKHOUSE_USER=${CLICKHOUSE_USER:-default}
CLICKHOUSE_PASSWORD=${CLICKHOUSE_PASSWORD:-}

REDIS_HOST=${REDIS_MODE:+${REDIS_HOST:-redis}}
REDIS_PORT=${REDIS_PORT:-6379}
REDIS_PASSWORD=${REDIS_PASSWORD:-}

# Service Ports
SSP_SERVER_PORT=${SSP_SERVER_PORT:-8080}
SSP_API_PORT=${SSP_API_PORT:-8081}
SSP_CONTROL_PORT=${SSP_CONTROL_PORT:-8082}
NGINX_HTTP_PORT=${NGINX_HTTP_PORT:-80}
NGINX_HTTPS_PORT=${NGINX_HTTPS_PORT:-443}

# Domain Configuration
SSP_SERVER_DOMAIN=${SSP_SERVER_DOMAIN:-localhost}
SSP_API_DOMAIN=${SSP_API_DOMAIN:-api.localhost}
SSP_CONTROL_DOMAIN=${SSP_CONTROL_DOMAIN:-control.localhost}
EOF
    
    # Override hosts for external services
    if [[ "$POSTGRES_MODE" == "external" ]]; then
        sed -i.bak "s/POSTGRES_HOST=.*/POSTGRES_HOST=$POSTGRES_HOST/" "$env_file"
    fi
    
    if [[ "$CLICKHOUSE_MODE" == "external" ]]; then
        sed -i.bak "s/CLICKHOUSE_HOST=.*/CLICKHOUSE_HOST=$CLICKHOUSE_HOST/" "$env_file"
    fi
    
    if [[ "$REDIS_MODE" == "external" ]]; then
        sed -i.bak "s/REDIS_HOST=.*/REDIS_HOST=$REDIS_HOST/" "$env_file"
    fi
    
    rm -f "$env_file.bak"
    log "ok" "Generated $env_file"
}

show_usage() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  config              Show current configuration"
    echo "  check               Check external service connectivity"
    echo "  up [services...]    Start services"
    echo "  down                Stop all services"
    echo "  restart [services...] Restart services"
    echo "  logs [service]      Show logs"
    echo "  ps                  Show running containers"
    echo "  exec <service> <cmd> Execute command in container"
    echo ""
    echo "Configuration:"
    echo "  Edit .deployment.env to configure which services run as containers"
    echo "  vs external services"
    echo ""
    echo "Examples:"
    echo "  $0 config           # Show current setup"
    echo "  $0 check            # Test external service connections"
    echo "  $0 up               # Start all configured services"
    echo "  $0 up ssp api       # Start only specific services"
    echo "  $0 logs ssp         # Show SSP server logs"
    echo "  $0 exec api bash    # Open shell in API container"
}

main() {
    local command="${1:-}"
    
    if [[ -z "$command" ]]; then
        show_usage
        exit 1
    fi
    
    load_config
    
    case "$command" in
        config)
            show_config
            ;;
        check)
            check_external_services
            if [[ $? -eq 0 ]]; then
                log "ok" "All external services are accessible"
            else
                log "error" "Some external services are not accessible"
                exit 1
            fi
            ;;
        up)
            log "info" "Starting SSP Server services..."
            generate_env_file
            if [[ "$2" ]]; then
                # Start specific services
                shift
                cmd_array=($(build_compose_command "up"))
                "${cmd_array[@]}" up -d "$@"
            else
                # Start all services
                cmd_array=($(build_compose_command "up"))
                "${cmd_array[@]}" up -d
            fi
            log "ok" "Services started"
            ;;
        down)
            log "info" "Stopping SSP Server services..."
            cmd_array=($(build_compose_command "down"))
            "${cmd_array[@]}" down
            log "ok" "Services stopped"
            ;;
        restart)
            log "info" "Restarting SSP Server services..."
            generate_env_file
            if [[ "$2" ]]; then
                shift
                cmd_array=($(build_compose_command "restart"))
                "${cmd_array[@]}" restart "$@"
            else
                cmd_array=($(build_compose_command "restart"))
                "${cmd_array[@]}" restart
            fi
            log "ok" "Services restarted"
            ;;
        logs)
            cmd_array=($(build_compose_command "logs"))
            if [[ "$2" ]]; then
                "${cmd_array[@]}" logs -f "$2"
            else
                "${cmd_array[@]}" logs -f
            fi
            ;;
        ps)
            cmd_array=($(build_compose_command "ps"))
            "${cmd_array[@]}" ps
            ;;
        exec)
            if [[ -z "$2" || -z "$3" ]]; then
                log "error" "Usage: $0 exec <service> <command>"
                exit 1
            fi
            cmd_array=($(build_compose_command "exec"))
            "${cmd_array[@]}" exec "$2" "${@:3}"
            ;;
        *)
            log "error" "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
