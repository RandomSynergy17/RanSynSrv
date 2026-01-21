# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Container Lifecycle Commands

```bash
# Build & Start
docker compose build              # Build image
docker compose build --no-cache   # Rebuild from scratch
docker compose up -d              # Start in background

# Configuration
cp .env.example .env              # First time setup
nano .env                         # Edit configuration

# Access container shell
docker exec -it ransynsrv zsh     # Recommended (Oh-My-Zsh + Powerlevel10k)
docker exec -it ransynsrv bash    # Alternative

# View logs
docker compose logs -f                                    # All services
docker exec ransynsrv tail -f /data/log/nginx/access.log  # Nginx access
docker exec ransynsrv tail -f /data/log/nginx/error.log   # Nginx errors
docker exec ransynsrv tail -f /data/log/php/error.log     # PHP errors

# Stop & cleanup
docker compose down               # Stop container
docker compose down -v            # Stop and remove volumes (WARNING: deletes all data)
```

## Development Workflow

```bash
# Web files locations
./data/webroot/public_html/       # Frontend (HTML, CSS, JS) + API (mounted to /data/webroot/public_html)
./data/webroot/src/               # Backend PHP classes (autoloaded, mounted to /data/webroot/src)
./data/databases/                 # SQLite databases (mounted to /data/databases)

# Nginx configuration
./data/nginx/nginx.conf           # Edit Nginx config

# Test and reload Nginx
docker exec ransynsrv nginx -t           # Test config syntax
docker exec ransynsrv nginx -s reload    # Reload (zero-downtime)

# Access analytics
open http://localhost:8080               # Website
open http://localhost:8080/goaccess      # Real-time analytics dashboard
```

## Claude Code Integration

```bash
# Inside container
docker exec -it ransynsrv zsh
claude --help                            # Claude Code CLI
claude "analyze /data/nginx/nginx.conf"  # AI-powered code analysis
cc "refactor this PHP function"          # 'cc' is alias for 'claude'

# Pre-configured with access to:
# - Full development environment (Git, Node.js, Python, databases)
# - All project files in /data/ and /workspace
# - Configuration persists in: /data/claude/.claude (part of data volume)
```

## Architecture & Patterns

### Process Supervision (s6-overlay)

This container uses **s6-overlay** (not systemd/supervisord) for process management:

**Service startup order:**
```
init-ransynsrv (oneshot)
    ├─→ svc-nginx (longrun)
    │       └─→ svc-goaccess (longrun, requires nginx)
    └─→ svc-php-fpm (longrun)
```

**Key characteristics:**
- Services auto-restart on failure
- Dependencies enforced: GoAccess waits for both init AND Nginx
- Service scripts: [root/etc/s6-overlay/s6-rc.d/](root/etc/s6-overlay/s6-rc.d/)
- Init script ([init-ransynsrv/run](root/etc/s6-overlay/s6-rc.d/init-ransynsrv/run)) handles: directory setup, default configs, log configuration, runtime package installation

### Configuration Layering

**Three-layer system:**
1. **Build-time defaults**: Copied from `root/defaults/` into Docker image at `/defaults/`
2. **Runtime initialization**: Init script copies defaults to `/data/` if files don't exist
3. **User overrides**: Edit files in `./data/` (persists across container restarts)

**Key insight:** Nginx config at `./data/nginx/nginx.conf` is symlinked to `/etc/nginx/nginx.conf` during initialization. Changes to the volume-mounted file affect the running configuration immediately after reload.

### Configuration Files

| Location | Purpose | Persistence | Notes |
|----------|---------|-------------|-------|
| `./data/nginx/nginx.conf` | Nginx config | Volume | Editable, symlinked to /etc/nginx/nginx.conf |
| `./data/webroot/public_html/` | Frontend web root | Volume | HTML, CSS, JS, API endpoints |
| `./data/webroot/src/` | Backend PHP classes | Volume | For autoloaded PHP business logic |
| `./data/webroot/goaccess/` | Analytics dashboard | Volume | Generated HTML by GoAccess |
| `./data/databases/` | SQLite databases | Volume | Persistent database storage |
| `./data/log/` | Log files | Volume | Nginx/PHP logs |
| `./data/claude/.claude/` | Claude Code config | Volume | API keys, preferences |
| `./data/commandhistory/` | Shell history | Volume | Bash/Zsh command history |
| `./data/ssh/` | SSH keys | Volume | Private keys (chmod 700) |
| `./data/scripts/` | Custom scripts | Volume | User automation scripts |
| `./data/crontabs/` | Cron jobs | Volume | Scheduled tasks |
| `/etc/php84/php-fpm.d/www.conf` | PHP-FPM pool | Ephemeral | **Generated at runtime** by [svc-php-fpm/run](root/etc/s6-overlay/s6-rc.d/svc-php-fpm/run) |
| `/etc/goaccess/goaccess.conf` | GoAccess config | In image | Not editable without rebuild |

### Volume Mounts

| Host Path | Container Path | Purpose |
|-----------|----------------|---------|
| `./data` | `/data` | All persistent files (configs, web files, logs, databases, claude config, history) |

**Important:** This container uses a single consolidated data volume. All persistent data (including Claude Code configuration and shell history) is stored under `/data/` and symlinked to their expected locations. This simplifies backups, migrations, and Portainer deployments.

### Environment Variables

**Critical variables in `.env`:**

| Variable | Default | Purpose |
|----------|---------|---------|
| `PUID`/`PGID` | 1000 | User/group mapping (run `id $USER` to get yours) |
| `TZ` | Asia/Dubai | Timezone |
| `HTTP_PORT` | 8080 | Published HTTP port |
| `DATA_PATH` | ./data | Host path for persistent data |
| `COMPOSE_PROJECT_NAME` | (folder name) | Unique name for multi-instance deployments |
| `ANTHROPIC_API_KEY` | (empty) | **Required** for Claude Code |
| `PHP_MEMORY_LIMIT` | 256M | PHP memory limit |
| `PHP_MAX_UPLOAD` | 50M | Maximum upload file size |
| `PHP_MAX_POST` | 50M | Maximum POST data size |
| `PHP_MAX_EXECUTION_TIME` | 300 | Maximum script execution time (seconds) |
| `INSTALL_PACKAGES` | (empty) | Runtime Alpine package installation (space-separated) |
| `INSTALL_PIP_PACKAGES` | (empty) | Runtime Python package installation (space-separated) |
| `DOCKER_LOGS` | false | When `true`, redirects logs to Docker stdout/stderr |
| `GOACCESS_ENABLED` | true | When `false`, disables analytics dashboard |
| `GOACCESS_WS_URL` | (empty) | WebSocket URL for reverse proxy setups (e.g., wss://domain.com/goaccess/ws) |

**Runtime Package Installation:**
```bash
# In .env
INSTALL_PACKAGES=mc tig ncdu                    # Alpine packages
INSTALL_PIP_PACKAGES=pandas numpy matplotlib    # Python packages

# Packages install during init phase, before services start
# Useful for adding dev tools without rebuilding image
```

### Logging Architecture

**Two modes controlled by `DOCKER_LOGS` environment variable:**

**File mode (default):**
- Logs written to `./data/log/nginx/` and `./data/log/php/`
- Persistent, can be analyzed with external tools
- View with: `docker exec ransynsrv tail -f /data/log/nginx/access.log`

**Docker mode (`DOCKER_LOGS=true`):**
- Log files symlinked to `/proc/1/fd/1` (stdout) and `/proc/1/fd/2` (stderr)
- Captured by Docker logging driver
- View with: `docker compose logs -f`
- Compatible with log aggregators (Loki, ELK, etc.)

**Implementation:** [init-ransynsrv/run](root/etc/s6-overlay/s6-rc.d/init-ransynsrv/run):47-55 removes log files and creates symlinks when `DOCKER_LOGS=true`.

## Service Architecture

### Nginx

- **User:** `abc` (unprivileged, UID from `PUID` env var)
- **Port:** Listens on 80 inside container (mapped to `HTTP_PORT` on host)
- **Web root:** `/data/webroot/public_html` (serves index.php or index.html)
- **PHP requests:** Forwarded to `/run/php/php-fpm.sock` (Unix socket)
- **Special endpoints:**
  - `/health` → Returns 200 OK (healthcheck)
  - `/goaccess` → Analytics dashboard (alias to `/data/webroot/goaccess`)
  - `/goaccess/ws` → WebSocket proxy to port 7890
- **Compression:** Gzip + Brotli enabled (level 6)
- **Real IP:** Configured to respect X-Forwarded-For from private networks
- **Config:** [./data/nginx/nginx.conf](root/defaults/nginx/nginx.conf) (symlinked to /etc/nginx/nginx.conf)
- **Additional configs:** Place in `./data/nginx/*.conf` (automatically included)

### PHP-FPM

**Key insight:** PHP-FPM pool configuration is **generated dynamically at runtime** by [svc-php-fpm/run](root/etc/s6-overlay/s6-rc.d/svc-php-fpm/run), not a static file.

- **PHP Version:** 8.4 with 45+ extensions (see [README](README.md) for full list)
- **Communication:** Unix socket at `/run/php/php-fpm.sock` (not TCP)
- **Process pool:** Dynamic with 2-10 children, max 500 requests per child before respawn
- **User:** `abc:abc`
- **Error logs:** `/data/log/php/error.log`
- **Runtime config:** Environment variables control PHP settings:
  - `PHP_MEMORY_LIMIT` (default: 256M)
  - `PHP_MAX_UPLOAD` (default: 50M)
  - `PHP_MAX_POST` (default: 50M)
  - `PHP_MAX_EXECUTION_TIME` (default: 300 seconds)
- **INI file:** `/etc/php84/conf.d/99-ransynsrv.ini` (generated at build time with env var defaults)
- **Extensions config:** Place additional INI files in `/etc/php84/conf.d/`

### PHP Application Structure

**Recommended architecture:**

```
/data/webroot/
├── public_html/              (Web-accessible, Nginx root)
│   ├── index.php            Entry point (handles routing)
│   ├── .htaccess            (Not used, configure in nginx.conf)
│   ├── assets/              Static files
│   └── api/                 API endpoints
│       └── users.php        Example: include '../src/Controllers/UserController.php'
└── src/                     (Not web-accessible, PHP classes only)
    ├── autoload.php         PSR-4 autoloader or Composer autoload
    ├── Database/
    │   └── Connection.php   Database singleton
    ├── Models/
    │   └── User.php         Data models
    ├── Controllers/
    │   └── UserController.php  Business logic
    └── Utils/
        └── Logger.php       Helper functions
```

**Example entry point (`/data/webroot/public_html/index.php`):**

```php
<?php
// Load autoloader
require_once __DIR__ . '/../src/autoload.php';

// Route handling
$uri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);

if ($uri === '/api/users') {
    $controller = new Controllers\UserController();
    $controller->handleRequest();
} else {
    // Serve static HTML or 404
    http_response_code(404);
    echo "Not Found";
}
```

**Database access example:**

```php
<?php
namespace Database;

class Connection {
    private static $instance = null;
    private $pdo;

    private function __construct() {
        $this->pdo = new \PDO('sqlite:/data/databases/app.db');
        $this->pdo->setAttribute(\PDO::ATTR_ERRMODE, \PDO::ERRMODE_EXCEPTION);
    }

    public static function getInstance() {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }

    public function query($sql, $params = []) {
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute($params);
        return $stmt;
    }
}
```

### GoAccess

- **Purpose:** Real-time web analytics dashboard
- **Version:** 1.9.4 (built from source with MMDB GeoIP support)
- **Source:** Monitors `/data/log/nginx/access.log`
- **Output:** Generates HTML at `/data/webroot/goaccess/index.html`
- **WebSocket:** Runs on port 7890 (internal, proxied by Nginx at `/goaccess/ws`)
- **Live updates:** Dashboard refreshes automatically as logs are written
- **Configuration:** [/etc/goaccess/goaccess.conf](root/etc/goaccess/goaccess.conf)
  - Log format: COMBINED
  - Real-time HTML: enabled
  - Theme: dark-purple
  - Anonymize IP: true
  - Ignore crawlers: true
- **Disable:** Set `GOACCESS_ENABLED=false` in `.env`
- **Startup:** Waits up to 30 seconds for log file to exist ([svc-goaccess/run](root/etc/s6-overlay/s6-rc.d/svc-goaccess/run):10-11)
- **Reverse proxy:** Set `GOACCESS_WS_URL=wss://yourdomain.com/goaccess/ws` when behind HTTPS proxy

## Troubleshooting

### Permission Issues

```bash
# Symptom: "Permission denied" errors in container
# Cause: PUID/PGID mismatch between host and container

# Solution:
id $USER                          # Note your uid and gid (e.g., uid=1000 gid=1000)
nano .env                         # Update PUID=1000 and PGID=1000
sudo chown -R 1000:1000 ./data/   # Fix existing files (use your actual UID:GID)
docker compose down && docker compose up -d

# Verify permissions inside container
docker exec ransynsrv ls -la /data/webroot/public_html/
# Should show: drwxr-xr-x abc abc
```

### Nginx Configuration Errors

```bash
# Always test config before reloading
docker exec ransynsrv nginx -t

# Common error: "could not open error log"
# Solution: Check log file permissions
docker exec ransynsrv ls -la /data/log/nginx/
docker exec ransynsrv chown -R abc:abc /data/log/

# View detailed errors
docker exec ransynsrv tail -50 /data/log/nginx/error.log

# If nginx won't start, check syntax and permissions
docker logs ransynsrv

# Reload after fixing config
docker exec ransynsrv nginx -s reload
```

### PHP Errors

```bash
# View PHP errors
docker exec ransynsrv tail -f /data/log/php/error.log

# Common error: "Unable to open primary script"
# Solution: Check file exists and permissions
docker exec ransynsrv ls -la /data/webroot/public_html/index.php

# Test PHP-FPM is running
docker exec ransynsrv ps aux | grep php-fpm

# Check socket exists
docker exec ransynsrv ls -la /run/php/php-fpm.sock
# Should show: srw-rw---- abc abc

# Test PHP syntax
docker exec ransynsrv php -l /data/webroot/public_html/index.php
```

### Database Issues

```bash
# SQLite permission errors
docker exec ransynsrv ls -la /data/databases/
# Should show: -rw-r--r-- abc abc app.db

# Fix database permissions
docker exec ransynsrv chown abc:abc /data/databases/*.db
docker exec ransynsrv chmod 644 /data/databases/*.db

# Test database access
docker exec ransynsrv sqlite3 /data/databases/app.db ".tables"

# Check database locks
docker exec ransynsrv lsof /data/databases/app.db
```

### Service Not Starting

```bash
# Check all service logs
docker logs ransynsrv

# Inside container, list all services and their states
docker exec ransynsrv s6-rc -a list

# Check specific service status
docker exec ransynsrv s6-rc -u list svc-nginx
docker exec ransynsrv s6-rc -u list svc-php-fpm
docker exec ransynsrv s6-rc -u list svc-goaccess

# Check if processes are running
docker exec ransynsrv ps aux | grep nginx
docker exec ransynsrv ps aux | grep php-fpm
docker exec ransynsrv ps aux | grep goaccess

# Manual service control (advanced)
docker exec ransynsrv s6-rc -d change svc-nginx    # Stop nginx
docker exec ransynsrv s6-rc -u change svc-nginx    # Start nginx
```

### Claude Code Not Working

```bash
# Verify API key is set
docker exec ransynsrv env | grep ANTHROPIC
# Should show: ANTHROPIC_API_KEY=sk-ant-...

# Test CLI
docker exec ransynsrv claude --version
# Should show: Claude Code v2.1.12

# Check configuration directory
docker exec ransynsrv ls -la /data/claude/.claude/
docker exec ransynsrv cat /data/claude/.claude/config.json

# Test API connectivity
docker exec ransynsrv curl -s https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" | jq .

# Reinitialize Claude Code
docker exec -it ransynsrv claude --reset
```

### GoAccess Dashboard Empty

```bash
# Generate some traffic
curl http://localhost:8080
curl http://localhost:8080/health
curl http://localhost:8080/nonexistent

# Verify log file exists and has content
docker exec ransynsrv cat /data/log/nginx/access.log

# Check GoAccess service is running
docker exec ransynsrv ps aux | grep goaccess

# Check WebSocket port
docker exec ransynsrv netstat -tlnp | grep 7890

# Manually regenerate dashboard
docker exec ransynsrv goaccess /data/log/nginx/access.log \
  --log-format=COMBINED \
  -o /data/webroot/goaccess/test.html

# Check browser console for WebSocket errors
# Open http://localhost:8080/goaccess → DevTools → Console
```

### Container Won't Start

```bash
# Check Docker logs for errors
docker logs ransynsrv

# Common issues:
# 1. Port already in use
sudo lsof -i :8080
# Solution: Change HTTP_PORT in .env

# 2. Data directory permissions
ls -la ./data/
sudo chown -R $(id -u):$(id -g) ./data/

# 3. Corrupt volume
docker compose down -v    # WARNING: Deletes all data
docker compose up -d

# Start container in debug mode
docker compose up         # Run in foreground to see logs
```

## Directory Structure & Data Organization

### Complete Data Layout

```
./data/                                    (Host: ./data → Container: /data)
├── nginx/
│   └── nginx.conf                        Main Nginx configuration (editable)
│   └── *.conf                            Additional configs (auto-included)
├── webroot/
│   ├── public_html/                      Frontend web root
│   │   ├── index.html                    Default homepage
│   │   ├── index.php                     PHP entry point
│   │   ├── assets/                       Static files (CSS, JS, images)
│   │   └── api/                          API endpoints
│   ├── src/                              Backend PHP classes
│   │   ├── Database/                     Database access layer
│   │   ├── Models/                       Data models
│   │   ├── Controllers/                  Business logic
│   │   └── Utils/                        Helper functions
│   └── goaccess/
│       └── index.html                    Analytics dashboard (auto-generated)
├── databases/                            SQLite databases
│   ├── app.db                           Main application database
│   └── *.db                             Additional databases
├── log/
│   ├── nginx/
│   │   ├── access.log                   Web server access logs
│   │   └── error.log                    Web server error logs
│   └── php/
│       └── error.log                    PHP error logs
├── claude/
│   └── .claude/                         Claude Code configuration
│       ├── config.json                  API keys, preferences
│       └── history/                     Command history
├── commandhistory/
│   ├── .bash_history                    Bash command history
│   └── .zsh_history                     Zsh command history
├── ssh/                                 SSH keys (chmod 700)
│   ├── id_rsa                          Private keys
│   └── known_hosts                     Known hosts
├── scripts/                             Custom automation scripts
│   └── *.sh                            User scripts
└── crontabs/                            Scheduled tasks
    └── abc                             Cron jobs for user abc
```

### Database Management

**SQLite databases stored at `/data/databases/`:**

```bash
# Inside container
docker exec -it ransynsrv zsh

# Create new database
sqlite3 /data/databases/app.db

# Query database
sqlite3 /data/databases/app.db "SELECT * FROM users;"

# Backup database
cp /data/databases/app.db /data/databases/app.backup.db

# Use from PHP
$db = new PDO('sqlite:/data/databases/app.db');
```

**Python LevelDB access:**

```bash
# LevelDB support included (plyvel, python-snappy, ccl_chromium_reader)
python3 -c "import plyvel; db = plyvel.DB('/data/databases/leveldb')"
```

**MariaDB/PostgreSQL (external):**

```bash
# Clients included for remote database access
mysql -h external-host -u user -p database
psql -h external-host -U user -d database
```

## Common Development Workflows

### Creating a New API Endpoint

```bash
# 1. Create controller (backend logic)
docker exec -it ransynsrv zsh
nano /data/webroot/src/Controllers/ProductController.php

# 2. Create API endpoint (public-facing)
nano /data/webroot/public_html/api/products.php

# 3. Test endpoint
curl http://localhost:8080/api/products

# 4. Check logs if errors occur
tail -f /data/log/php/error.log
```

### Setting Up Database Schema

```bash
# 1. Enter container
docker exec -it ransynsrv zsh

# 2. Create database
sqlite3 /data/databases/app.db

# 3. Create schema
sqlite> CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL UNIQUE,
  email TEXT NOT NULL UNIQUE,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

# 4. Verify
sqlite> .tables
sqlite> .schema users

# 5. Insert test data
sqlite> INSERT INTO users (username, email) VALUES ('admin', 'admin@example.com');
sqlite> SELECT * FROM users;
```

### Adding Runtime Packages

```bash
# 1. Edit .env file on host
nano .env

# Add packages (space-separated)
INSTALL_PACKAGES=mc tig ncdu htop
INSTALL_PIP_PACKAGES=pandas numpy requests

# 2. Restart container
docker compose restart

# 3. Verify installation
docker exec ransynsrv mc --version
docker exec ransynsrv python3 -c "import pandas; print(pandas.__version__)"
```

### Deploying Code Updates

```bash
# Option 1: Direct file editing
nano ./data/webroot/public_html/index.php
# Changes take effect immediately (PHP is interpreted)

# Option 2: Git deployment
docker exec -it ransynsrv zsh
cd /workspace
git clone https://github.com/user/project.git
cp -r project/* /data/webroot/public_html/

# Option 3: rsync from host
rsync -av ./local-project/ ./data/webroot/public_html/

# Always test after deployment
curl http://localhost:8080
docker exec ransynsrv tail -f /data/log/nginx/error.log
```

### Nginx Configuration Changes

```bash
# 1. Edit config
nano ./data/nginx/nginx.conf

# 2. Test syntax
docker exec ransynsrv nginx -t

# 3. Reload if test passes
docker exec ransynsrv nginx -s reload

# 4. View logs for errors
docker exec ransynsrv tail -f /data/log/nginx/error.log
```

### Backup and Restore

```bash
# Full backup (recommended)
tar -czf ransynsrv-backup-$(date +%Y%m%d).tar.gz ./data/

# Selective backup (databases only)
tar -czf databases-backup-$(date +%Y%m%d).tar.gz ./data/databases/

# Selective backup (code only)
tar -czf webroot-backup-$(date +%Y%m%d).tar.gz ./data/webroot/

# Restore
docker compose down
tar -xzf ransynsrv-backup-20260121.tar.gz
docker compose up -d

# Database-only restore
cp backup/app.db ./data/databases/
docker exec ransynsrv chown abc:abc /data/databases/app.db
```

### Multi-Instance Deployment

```bash
# Deploy multiple instances on same host

# Instance 1 (production)
cd /srv/ransynsrv-prod
nano .env
# COMPOSE_PROJECT_NAME=ransynsrv_prod
# HTTP_PORT=8080
# DATA_PATH=/srv/ransynsrv-prod/data
docker compose up -d

# Instance 2 (staging)
cd /srv/ransynsrv-staging
nano .env
# COMPOSE_PROJECT_NAME=ransynsrv_staging
# HTTP_PORT=8081
# DATA_PATH=/srv/ransynsrv-staging/data
docker compose up -d

# Instance 3 (development)
cd /srv/ransynsrv-dev
nano .env
# COMPOSE_PROJECT_NAME=ransynsrv_dev
# HTTP_PORT=8082
# DATA_PATH=/srv/ransynsrv-dev/data
docker compose up -d

# Each instance has:
# - Separate container (ransynsrv_prod, ransynsrv_staging, ransynsrv_dev)
# - Separate network (ransynsrv_prod_default, etc.)
# - Separate data directory
# - Different port (8080, 8081, 8082)
```

### Using Claude Code for Development

```bash
# Enter container
docker exec -it ransynsrv zsh

# Analyze existing code
claude "review the PHP code in /data/webroot/public_html/api/ for security issues"

# Generate new code
claude "create a RESTful API endpoint for CRUD operations on users table"

# Debug issues
claude "analyze why /data/log/php/error.log shows connection refused errors"

# Refactor code
claude "refactor /data/webroot/src/Controllers/UserController.php to use dependency injection"

# Generate database migrations
claude "create SQLite schema for a blog system with posts, comments, and users"

# Write tests
claude "create PHPUnit tests for the User model in /data/webroot/src/Models/User.php"
```

## Important Technical Details

### File Paths Reference

**Critical paths for AI agents:**

| Path | Type | Description |
|------|------|-------------|
| `/data/webroot/public_html/` | Directory | Web-accessible root (serves HTTP requests) |
| `/data/webroot/src/` | Directory | PHP backend classes (not web-accessible) |
| `/data/databases/` | Directory | SQLite database files |
| `/data/nginx/nginx.conf` | File | Main Nginx configuration (symlinked to /etc/nginx/nginx.conf) |
| `/data/log/nginx/access.log` | File | HTTP access logs |
| `/data/log/nginx/error.log` | File | Nginx error logs |
| `/data/log/php/error.log` | File | PHP error logs |
| `/run/php/php-fpm.sock` | Socket | PHP-FPM Unix socket |
| `/etc/php84/conf.d/99-ransynsrv.ini` | File | PHP configuration (generated at build) |
| `/etc/goaccess/goaccess.conf` | File | GoAccess configuration (in image) |
| `/defaults/` | Directory | Build-time default files |
| `/workspace/` | Directory | General workspace for development |

### Service Startup Sequence

**Detailed s6-overlay service tree:**

```
s6-rc initialization
│
├─→ init-ransynsrv (oneshot, type=oneshot)
│   │   Script: /etc/s6-overlay/s6-rc.d/init-ransynsrv/run
│   │   Actions:
│   │   - Install runtime packages (INSTALL_PACKAGES, INSTALL_PIP_PACKAGES)
│   │   - Create directory structure
│   │   - Copy default configs if missing
│   │   - Symlink nginx.conf
│   │   - Configure logging (file or Docker)
│   │   - Fix permissions
│   │
│   ├─→ svc-nginx (longrun, depends on init-ransynsrv)
│   │   │   Script: /etc/s6-overlay/s6-rc.d/svc-nginx/run
│   │   │   Command: nginx -g "daemon off;"
│   │   │
│   │   └─→ svc-goaccess (longrun, depends on init-ransynsrv + svc-nginx)
│   │       Script: /etc/s6-overlay/s6-rc.d/svc-goaccess/run
│   │       Command: goaccess with real-time HTML output
│   │       Note: Waits up to 30s for access.log to exist
│   │
│   └─→ svc-php-fpm (longrun, depends on init-ransynsrv)
│       Script: /etc/s6-overlay/s6-rc.d/svc-php-fpm/run
│       Actions:
│       - Generate /etc/php84/php-fpm.d/www.conf
│       - Start php-fpm -F (foreground)
```

### Environment Variable Processing

**Build-time (Dockerfile ARG → ENV):**
- `PUID`, `PGID`, `TZ` → Set as build args, become ENV
- Used during user creation and timezone setup
- Can be overridden at runtime via docker-compose.yml

**Runtime (docker-compose.yml environment):**
- All ENV vars available to init script and services
- `DOCKER_LOGS` → Controls log destination (init-ransynsrv)
- `GOACCESS_ENABLED` → Controls analytics service (svc-goaccess)
- `GOACCESS_WS_URL` → WebSocket URL for reverse proxy (svc-goaccess)
- `PHP_*` vars → Used in generated php-fpm pool config (svc-php-fpm)
- `INSTALL_*` vars → Trigger package installation (init-ransynsrv)

### Configuration Precedence

**Nginx:**
1. `/etc/nginx/nginx.conf` (symlink to `/data/nginx/nginx.conf`)
2. Additional configs via `include /data/nginx/*.conf;`
3. Changes require `nginx -s reload` or container restart

**PHP:**
1. `/etc/php84/php.ini` (Alpine default)
2. `/etc/php84/conf.d/*.ini` (alphabetically, 99-ransynsrv.ini last)
3. PHP-FPM pool: `/etc/php84/php-fpm.d/www.conf` (generated at service start)
4. Changes require container restart (FPM config cannot be reloaded)

**GoAccess:**
1. `/etc/goaccess/goaccess.conf` (baked into image)
2. Command-line args in svc-goaccess/run override config
3. Changes require container rebuild

### Symlinks and Generated Files

**Symlinks created at runtime (init-ransynsrv):**
- `/etc/nginx/nginx.conf` → `/data/nginx/nginx.conf`
- `/home/abc/.claude` → `/data/claude/.claude`
- If `DOCKER_LOGS=true`:
  - `/data/log/nginx/access.log` → `/proc/1/fd/1`
  - `/data/log/nginx/error.log` → `/proc/1/fd/2`
  - `/data/log/php/error.log` → `/proc/1/fd/2`

**Generated at runtime (svc-php-fpm):**
- `/etc/php84/php-fpm.d/www.conf` (written every time service starts)

**Generated continuously (svc-goaccess):**
- `/data/webroot/goaccess/index.html` (updated in real-time as logs arrive)

## Key Design Principles

1. **Single data volume**: All persistent data under `/data/` for simplified backups and migrations
2. **No SSL in container**: Designed to run behind a reverse proxy (Traefik, Nginx Proxy Manager, etc.) that handles HTTPS
3. **s6-overlay, not systemd**: Process supervision works differently from standard Linux systems
4. **Dynamic PHP-FPM config**: Generated at runtime, not a static file to edit
5. **Configuration is layered**: Build defaults → runtime init → user overrides
6. **Runtime package installation**: Use `INSTALL_PACKAGES`/`INSTALL_PIP_PACKAGES` env vars instead of modifying Dockerfile
7. **User mapping matters**: Set `PUID`/`PGID` to match your host user to avoid permission issues
8. **Services have dependencies**: Init must complete before Nginx/PHP-FPM start; GoAccess waits for Nginx
9. **Separation of concerns**: Frontend in `public_html/`, backend classes in `src/`, databases in `databases/`
10. **Symlinks are critical**: Nginx config and logs use symlinks; breaking them breaks the system
