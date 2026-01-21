# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RanSynSrv is a containerized PHP web hosting environment built on Alpine Linux. It combines Nginx, PHP-FPM 8.4, GoAccess analytics, and ttyd web terminal, managed by s6-overlay process supervision.

## Architecture

### Service Stack
- **Nginx 1.26.3** - Reverse proxy on port 80, serves static files and proxies PHP via Unix socket
- **PHP-FPM 8.4** - Application server running as `abc` user via `/run/php/php-fpm.sock`
- **GoAccess** - Real-time analytics dashboard with WebSocket on port 7890
- **ttyd** - Web terminal on port 7681 (localhost only, proxied via Nginx at `/ttyd/`)

### Directory Structure
```
/data/
├── webroot/public_html/   # PHP application root (served at /)
├── webroot/goaccess/      # Analytics dashboard output
├── log/nginx/             # access.log and error.log
├── log/php/               # PHP error.log
├── nginx/nginx.conf       # Primary Nginx configuration
├── databases/             # Database storage
├── scripts/               # User scripts
└── claude/.claude/        # Claude Code configuration
```

### Service Management (s6-overlay)
Services are defined in `/etc/s6-overlay/s6-rc.d/svc-*/`. Startup order:
1. init-ransynsrv (one-shot setup)
2. svc-php-fpm
3. svc-nginx
4. svc-goaccess
5. svc-ttyd

## Environment Variables

### Service Control
- `GOACCESS_ENABLED` - Enable analytics (default: true)
- `TTYD_ENABLED` - Enable web terminal (default: false)
- `DOCKER_LOGS` - Redirect logs to Docker stdout (default: false)

### Package Installation (applied at container startup)
- `INSTALL_PACKAGES` - Alpine apk packages to install
- `INSTALL_PIP_PACKAGES` - Python pip packages to install

### Authentication
- `GOACCESS_AUTH_ENABLED`, `GOACCESS_USERNAME`, `GOACCESS_PASSWORD`
- `TTYD_USERNAME`, `TTYD_PASSWORD`

### PHP Configuration
- `PHP_MEMORY_LIMIT` (default: 256M)
- `PHP_MAX_EXECUTION_TIME` (default: 300)
- `PHP_MAX_POST`, `PHP_MAX_UPLOAD` (default: 50M)

## Key Configuration Files

- `/data/nginx/nginx.conf` - Nginx configuration (user-editable)
- `/etc/php84/conf.d/99-ransynsrv.ini` - PHP overrides
- `/etc/s6-overlay/s6-rc.d/init-ransynsrv/run` - Container initialization script
- `/etc/goaccess/goaccess.conf` - GoAccess configuration

## Common Commands

```bash
# Check service status
ps aux | grep -E "(nginx|php|goaccess|ttyd)"

# View logs
tail -f /data/log/nginx/access.log
tail -f /data/log/nginx/error.log
tail -f /data/log/php/error.log

# Install packages at runtime
apk add --no-cache <package>
pip3 install <package>

# Test Nginx configuration
nginx -t

# Reload Nginx
nginx -s reload
```

## Conventions

- All application code runs as `abc` user (non-root)
- Persistent data lives under `/data/` (container volume mount)
- Shell scripts use POSIX-compliant sh syntax
- Service scripts access environment via `/command/with-contenv` wrapper
- Nginx uses COMBINED log format for GoAccess compatibility
- Health endpoint at `/health` returns 200 OK without logging
