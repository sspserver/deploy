# SSP Server Modular Deployment

This directory contains a modular Docker Compose setup that allows you to use either containerized or external database services.

## Quick Start

### All-in-One (Default)

```bash
# Traditional approach - all services in containers
docker-compose up -d
```

### Modular Approach  

```bash
# Show current configuration
./ssp-compose.sh config

# Start with default configuration (all containers)
./ssp-compose.sh up

# Or customize which services run externally
```

## Configuration

### Service Modes

Edit `.deployment.env` to configure which services run as containers vs external:

```bash
# Database Services Configuration
POSTGRES_MODE=container    # or "external"
CLICKHOUSE_MODE=container  # or "external"  
REDIS_MODE=container       # or "external"
```

### External Service Configuration

When using `MODE=external`, configure connection settings in `.deployment.env`:

```bash
# PostgreSQL
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=sspserver
POSTGRES_USER=sspserver
POSTGRES_PASSWORD=changeme

# ClickHouse  
CLICKHOUSE_HOST=localhost
CLICKHOUSE_HTTP_PORT=8123
CLICKHOUSE_TCP_PORT=9000

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
```

## Usage Examples

### Using External PostgreSQL

1. Install PostgreSQL locally:

   ```bash
   # macOS
   brew install postgresql
   brew services start postgresql
   
   # Ubuntu
   sudo apt install postgresql postgresql-contrib
   sudo systemctl start postgresql
   ```

2. Create database and user:

   ```sql
   createdb sspserver
   createuser sspserver
   psql -c "ALTER USER sspserver WITH PASSWORD 'changeme';"
   psql -c "GRANT ALL PRIVILEGES ON DATABASE sspserver TO sspserver;"
   ```

3. Configure deployment:

   ```bash
   # Edit .deployment.env
   POSTGRES_MODE=external
   POSTGRES_HOST=localhost
   POSTGRES_PORT=5432
   ```

4. Start services:

   ```bash
   ./ssp-compose.sh up
   ```

### Using External ClickHouse

1. Install ClickHouse:

   ```bash
   # macOS
   brew install clickhouse
   brew services start clickhouse
   
   # Ubuntu
   sudo apt install clickhouse-server clickhouse-client
   sudo systemctl start clickhouse-server
   ```

2. Configure deployment:

   ```bash
   # Edit .deployment.env
   CLICKHOUSE_MODE=external
   CLICKHOUSE_HOST=localhost
   CLICKHOUSE_HTTP_PORT=8123
   ```

3. Start services:

   ```bash
   ./ssp-compose.sh up
   ```

### Mixed Configuration

You can mix containerized and external services:

```bash
# Use external PostgreSQL but containerized ClickHouse and Redis
POSTGRES_MODE=external
CLICKHOUSE_MODE=container
REDIS_MODE=container
```

## Commands

### ssp-compose.sh Commands

```bash
# Configuration and status
./ssp-compose.sh config              # Show current setup
./ssp-compose.sh check               # Test external service connections

# Service management  
./ssp-compose.sh up                  # Start all services
./ssp-compose.sh up ssp api          # Start specific services
./ssp-compose.sh down                # Stop all services
./ssp-compose.sh restart             # Restart all services
./ssp-compose.sh restart ssp         # Restart specific service

# Monitoring and debugging
./ssp-compose.sh ps                  # Show running containers
./ssp-compose.sh logs                # Show all logs
./ssp-compose.sh logs ssp            # Show specific service logs
./ssp-compose.sh exec api bash       # Open shell in container
```

### Traditional Docker Compose

You can still use traditional docker-compose commands:

```bash
docker-compose up -d                 # Start all services (containers only)
docker-compose down                  # Stop all services
docker-compose logs -f ssp           # Show SSP server logs
docker-compose exec api bash         # Open shell in API container
```

## Architecture

### File Structure

```sh
├── docker-compose.yml              # All-in-one configuration
├── docker-compose.base.yml         # Core SSP services only
├── docker-compose.postgres.yml     # PostgreSQL container
├── docker-compose.clickhouse.yml   # ClickHouse container
├── docker-compose.redis.yml        # Redis container
├── .deployment.env                 # Deployment configuration
├── ssp-compose.sh                  # Modular management script
└── README-MODULAR.md               # This file
```

### Service Dependencies

```sh
┌─────────────────┐
│ Nginx Proxy     │ ← Always containerized
└─────────────────┘
         │
    ┌────┴─────┐
    │          │
┌───▼───┐  ┌───▼──┐ ┌─────────┐
│  SSP  │  │ API  │ │ Control │ ← Always containerized
└───┬───┘  └───┬──┘ └─────────┘
    │          │
    └──┬───────┘
       │
┌──────▼───────┐
│   Database   │ ← Configurable: container or external
│   Services   │
│ ┌──────────┐ │
│ │PostgreSQL│ │
│ │ClickHouse│ │
│ │  Redis   │ │
│ └──────────┘ │
└──────────────┘
```

## Advantages

### Containerized Services

- ✅ Easy setup and teardown
- ✅ Consistent environment
- ✅ No host system dependencies
- ✅ Version isolation

### External Services  

- ✅ Better performance (no container overhead)
- ✅ Persistent data beyond container lifecycle
- ✅ Integration with existing infrastructure
- ✅ Advanced configuration options
- ✅ Shared across multiple applications

## Troubleshooting

### Check Service Connectivity

```bash
# Test all external service connections
./ssp-compose.sh check
```

### Common Issues

1. **External service not accessible**

   ```bash
   # Check if service is running
   systemctl status postgresql
   systemctl status clickhouse-server
   systemctl status redis
   
   # Check network connectivity
   telnet localhost 5432   # PostgreSQL
   telnet localhost 8123   # ClickHouse
   telnet localhost 6379   # Redis
   ```

2. **Permission issues**

   ```bash
   # Ensure proper database permissions
   psql -h localhost -U sspserver -d sspserver -c "SELECT version();"
   ```

3. **Configuration conflicts**

   ```bash
   # Verify generated environment file
   cat .services.env
   
   # Check container environment
   ./ssp-compose.sh exec ssp env | grep -E "(POSTGRES|CLICKHOUSE|REDIS)"
   ```

### Environment Files

The system uses multiple environment files:

- `.deployment.env` - Your deployment configuration
- `.init.env` - Base SSP Server configuration  
- `.services.env` - Generated service connections (auto-generated)
- `postgres/.env` - PostgreSQL specific settings
- `api/.env` - API service settings
- `sspserver/.env` - SSP Server settings
- `control/.env` - Control panel settings

## Migration

### From All-Container to Mixed

1. Stop current deployment:

   ```bash
   docker-compose down
   ```

2. Install external services (PostgreSQL, ClickHouse, Redis)

3. Configure `.deployment.env`:

   ```bash
   cp .deployment.env.example .deployment.env
   # Edit configuration
   ```

4. Start with new configuration:

   ```bash
   ./ssp-compose.sh up
   ```

### From Mixed to All-Container

1. Stop current deployment:

   ```bash
   ./ssp-compose.sh down
   ```

2. Reset configuration:

   ```bash
   # Edit .deployment.env
   POSTGRES_MODE=container
   CLICKHOUSE_MODE=container
   REDIS_MODE=container
   ```

3. Start with containerized services:

   ```bash
   ./ssp-compose.sh up
   ```

## Performance Considerations

### External Services (Recommended for Production)

- Better I/O performance
- More memory available to databases
- Persistent storage independent of containers
- Easier backup and maintenance

### Containerized Services (Recommended for Development)

- Faster setup and teardown
- Consistent development environment
- Easy version switching
- No host system pollution
