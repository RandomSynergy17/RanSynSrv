# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RanSynSrv is a containerized PHP web hosting environment built on Alpine Linux. It combines Nginx, PHP-FPM 8.4, GoAccess analytics, and ttyd web terminal, managed by s6-overlay process supervision.

## Architecture

### Service Stack
- **Nginx 1.26+** - Reverse proxy on port 80, serves static files and proxies PHP via Unix socket
- **PHP-FPM 8.4** - Application server running as `abc` user via `/run/php/php-fpm.sock`
- **GoAccess** - Real-time analytics dashboard with WebSocket on port 7890 (loopback only)
- **ttyd** - Web terminal on port 7681 (localhost only, proxied via Nginx at `/ttyd/`)

### Directory Structure
```
/data/
├── webroot/public_html/   # PHP application root (served at /)
├── webroot/goaccess/      # Analytics dashboard output
├── log/nginx/             # access.log and error.log
├── log/php/               # PHP error.log and slow.log
├── nginx/nginx.conf       # Primary Nginx configuration
├── goaccess-db/           # GoAccess analytics persistence (TokyoCabinet)
├── databases/             # Database storage
├── scripts/               # User scripts
└── claude/.claude/        # Claude Code configuration
```

### Service Management (s6-overlay)
Services are defined in `/etc/s6-overlay/s6-rc.d/svc-*/`. Dependency order:
- `init-ransynsrv` (oneshot) runs first and blocks everything else
- `svc-nginx`, `svc-php-fpm`, `svc-ttyd` start in parallel once init succeeds
- `svc-goaccess` waits for both init and nginx (so the access log path exists)

## Environment Variables

### Service Control
- `GOACCESS_ENABLED` - Enable analytics (default: true)
- `TTYD_ENABLED` - Enable web terminal (default: false)
- `DOCKER_LOGS` - Redirect logs to Docker stdout (default: false)

### Package Installation (applied at container startup)
- `INSTALL_PACKAGES` - Alpine apk packages to install (space-separated)
- `INSTALL_PIP_PACKAGES` - Python pip packages to install (space-separated)

### Authentication
- `GOACCESS_AUTH_ENABLED`, `GOACCESS_USERNAME`, `GOACCESS_PASSWORD`
- `TTYD_USERNAME`, `TTYD_PASSWORD`

### PHP Configuration
- `PHP_MEMORY_LIMIT` (default: 256M)
- `PHP_MAX_EXECUTION_TIME` (default: 300)
- `PHP_MAX_POST`, `PHP_MAX_UPLOAD` (default: 50M) — `PHP_MAX_UPLOAD` also controls nginx's `client_max_body_size` via auto-generated `/data/nginx/nginx-upload.conf`

### PHP Opcache (optional)
- `PHP_OPCACHE_ENABLE` (default: 1)
- `PHP_OPCACHE_VALIDATE_TIMESTAMPS` (default: 1 — set to 0 for peak production throughput; requires restart after code changes)
- `PHP_OPCACHE_MEMORY_MB` (default: 128)
- `PHP_OPCACHE_MAX_FILES` (default: 10000)
- `PHP_OPCACHE_REVALIDATE_FREQ` (default: 2)
- `PHP_OPCACHE_INTERNED_STRINGS_MB` (default: 16)

### PHP-FPM Pool (optional)
- `PHP_PM_MAX_CHILDREN` (default: 10) — raise if you have spare RAM (each worker ≈ PHP_MEMORY_LIMIT)
- `PHP_PM_START_SERVERS` (default: 2)
- `PHP_PM_MIN_SPARE` (default: 1)
- `PHP_PM_MAX_SPARE` (default: 3)
- `PHP_PM_MAX_REQUESTS` (default: 500) — workers recycle after N requests to cap memory leaks

## Key Configuration Files

- `/data/nginx/nginx.conf` - Nginx configuration (user-editable; **must include `/data/nginx/nginx-upload.conf`** in the `http{}` block)
- `/data/nginx/nginx-upload.conf` - Auto-generated from `$PHP_MAX_UPLOAD` (do not edit)
- `/data/nginx/php-timeout.conf` - Auto-generated from `$PHP_MAX_EXECUTION_TIME` (do not edit)
- `/etc/php84/conf.d/99-ransynsrv.ini` - PHP overrides (regenerated at every boot from env vars)
- `/etc/s6-overlay/s6-rc.d/init-ransynsrv/run` - Container initialization script
- `/etc/goaccess/goaccess.conf` - GoAccess configuration

## Common Commands

```bash
# Check service status
s6-rc -a list

# View logs
tail -f /data/log/nginx/access.log
tail -f /data/log/nginx/error.log
tail -f /data/log/php/error.log

# Install packages at runtime
apk add --no-cache <package>
pip3 install <package>

# Test and reload Nginx — run from HOST, not inside the container when
# no-new-privileges:true is active (sudo is blocked inside the container):
#   docker exec ransynsrv nginx -t
#   docker exec ransynsrv nginx -s reload
```

## Security Notes

- **`clear_env=no`** in PHP-FPM means every env var on the container (including `ANTHROPIC_API_KEY`, `POSTGRES_PASSWORD`, etc.) is readable by every PHP request via `getenv()`. A PHP RCE can exfiltrate them. Don't host untrusted PHP here without switching to an explicit `env[...]` allowlist.
- **`no-new-privileges:true`** in compose blocks `sudo` escalation from inside the container. The zsh `nginx-test` / `nginx-reload` aliases won't work in ttyd sessions under this setting — use `docker exec ransynsrv nginx -t` from the host instead.
- **nginx auth htpasswd files** are `0644` (not 0600) so nginx workers (running as the `nginx` user) can read them. Content is SHA-512-crypt hashed, not plaintext.
- **GoAccess WebSocket** binds to `127.0.0.1:7890` (loopback only) and is only reachable via nginx's `/goaccess/ws` proxy.

## Conventions

- All application code runs as `abc` user (non-root)
- Persistent data lives under `/data/` (container volume mount)
- Shell scripts use POSIX-compliant sh syntax
- Service scripts access environment via `/command/with-contenv` wrapper
- Nginx uses COMBINED log format for GoAccess compatibility (with XFF 9th field)
- Health endpoint at `/health` returns 200 OK without logging
- Custom `nginx.conf` must `include /data/nginx/nginx-upload.conf;` in `http{}` and `include /data/nginx/php-timeout.conf;` inside `location ~ \.php$`
