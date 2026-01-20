# RanSynSrv

A lightweight, feature-rich web server built on Alpine Linux with Nginx, PHP 8.4, real-time analytics, Claude Code CLI, and comprehensive development tools.

**Designed to run behind a reverse proxy** — handles HTTP traffic only (no SSL).

---

## Features

### Core Stack

| Component | Version | Description |
|-----------|---------|-------------|
| Alpine Linux | 3.21 | Minimal, secure base (~5MB) |
| Nginx | Latest | High-performance with Brotli |
| PHP | 8.4 | Latest PHP, 45+ extensions |
| GoAccess | 1.9.3 | Real-time web analytics |
| s6-overlay | 3.2.0 | Process supervision |

### Integrated Mods

| Mod | Feature | Environment Variable |
|-----|---------|---------------------|
| **stdout-logs** | Docker logging driver support | `DOCKER_LOGS=true` |
| **package-install** | Runtime package installation | `INSTALL_PACKAGES`, `INSTALL_PIP_PACKAGES` |
| **nvm** | Node Version Manager | `nvm use 20` |

### Development Tools

| Category | Tools |
|----------|-------|
| **AI** | Claude Code CLI (`claude`, `cc`) |
| **Shells** | Zsh + Oh-My-Zsh + Powerlevel10k, Bash |
| **Version Control** | Git, Git-LFS, GitHub CLI, git-delta |
| **Languages** | Node.js + NVM + npm + yarn, Python 3 + pip |
| **Databases** | SQLite, MySQL client, PostgreSQL client, Redis, LevelDB |
| **Media** | FFmpeg, ImageMagick, GraphicsMagick |
| **Network** | curl, wget, httpie, bind-tools, iptables, ipset |
| **Sync** | rsync, rclone, SSH client |
| **Utilities** | jq, yq, htop, fzf, tree, bc, glances |

### PHP Extensions

```
bcmath, bz2, calendar, ctype, curl, dom, exif, fileinfo, ftp, gd, gettext,
gmp, iconv, imap, intl, ldap, mbstring, mysqli, mysqlnd, opcache, openssl,
pcntl, pdo, pdo_mysql, pdo_pgsql, pdo_sqlite, pgsql, phar, posix, session,
simplexml, soap, sockets, sodium, sqlite3, tokenizer, xml, xmlreader,
xmlwriter, xsl, zip, zlib, apcu, igbinary, redis
```

---

## Quick Start

```bash
# Extract
unzip ransynsrv.zip && cd ransynsrv

# Configure
cp .env.example .env
# Edit .env: set PUID/PGID from 'id $USER'

# Start
docker compose up -d --build

# Access
open http://localhost:8080          # Website
open http://localhost:8080/goaccess # Analytics
```

---

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PUID` | `1000` | User ID (run `id -u`) |
| `PGID` | `1000` | Group ID (run `id -g`) |
| `TZ` | `Asia/Dubai` | Timezone |
| `HTTP_PORT` | `8080` | Web server port |
| `DATA_PATH` | `./data` | Data directory |
| `PHP_MEMORY_LIMIT` | `256M` | PHP memory limit |
| `PHP_MAX_UPLOAD` | `50M` | Max upload size |
| `GOACCESS_ENABLED` | `true` | Analytics dashboard |
| `ANTHROPIC_API_KEY` | | Claude Code API key |
| `INSTALL_PACKAGES` | | Alpine packages to install |
| `INSTALL_PIP_PACKAGES` | | Python packages to install |
| `DOCKER_LOGS` | `false` | Send logs to Docker |

---

## Claude Code

### Setup

1. Get API key: https://console.anthropic.com/
2. Add to `.env`:
   ```env
   ANTHROPIC_API_KEY=sk-ant-...
   ```
3. Restart: `docker compose restart`

### Usage

```bash
# Enter container
docker exec -it ransynsrv zsh

# Use Claude Code
claude --help
claude "explain this nginx config"
cc "refactor this PHP function"

# Interactive mode
claude
```

### Features

- **Agentic coding**: Claude can read, write, and execute code
- **Full environment access**: Git, Node.js, Python, databases
- **Persistent config**: Stored in Docker volume

### Example Workflows

```bash
# Debug PHP application
claude "find and fix the bug in /data/www/html/api.php"

# Generate nginx config
claude "create nginx config for WordPress with caching"

# Analyze logs
claude "summarize errors from /data/log/nginx/error.log"

# Create deployment script
claude "write a bash script to backup /data/www and deploy from git"
```

---

## Node Version Manager (NVM)

### Usage

```bash
# Enter container
docker exec -it ransynsrv zsh

# List available versions
nvm ls-remote

# Install specific version
nvm install 20
nvm install 18

# Switch versions
nvm use 20
nvm use 18

# Set default
nvm alias default 20

# Check version
node --version
```

### Notes

- NVM is installed at `/usr/local/share/nvm`
- System Node.js remains available as fallback
- Installed versions persist in the container (not across rebuilds)

---

## Runtime Package Installation

### Alpine Packages

```env
INSTALL_PACKAGES=mc tig ncdu
```

### Python Packages

```env
INSTALL_PIP_PACKAGES=pandas numpy matplotlib
```

### Both

```env
INSTALL_PACKAGES=mc tig
INSTALL_PIP_PACKAGES=pandas numpy
```

Packages install on container startup before services start.

---

## Docker Logging (stdout-logs)

### Enable

```env
DOCKER_LOGS=true
```

### View Logs

```bash
# All logs
docker compose logs -f

# Just access logs
docker compose logs -f 2>&1 | grep -v "error"
```

### How It Works

When `DOCKER_LOGS=true`:
- Log files symlink to `/proc/1/fd/1` (stdout) and `/proc/1/fd/2` (stderr)
- Logs captured by Docker logging driver
- Compatible with log aggregators (Loki, ELK, etc.)

---

## Directory Structure

```
data/
├── nginx/
│   └── nginx.conf        ← Nginx config (editable)
├── www/
│   ├── html/             ← YOUR WEB FILES
│   └── goaccess/         ← Analytics dashboard
├── log/
│   ├── nginx/            ← Web server logs
│   └── php/              ← PHP errors
├── ssh/                  ← SSH keys
├── scripts/              ← Custom scripts
└── crontabs/             ← Cron jobs
```

---

## Shell Access

### Enter Container

```bash
docker exec -it ransynsrv zsh    # Zsh (recommended)
docker exec -it ransynsrv bash   # Bash
```

### Pre-configured Aliases

| Alias | Command |
|-------|---------|
| `ll` | `ls -alF` |
| `cc` | `claude` |
| `nginx-test` | `sudo nginx -t` |
| `nginx-reload` | `sudo nginx -s reload` |
| `logs` | `tail -f /data/log/nginx/access.log` |
| `errors` | `tail -f /data/log/nginx/error.log` |
| `phplogs` | `tail -f /data/log/php/error.log` |

### Zsh Features

- Oh-My-Zsh with Powerlevel10k theme
- Plugins: git, docker, node, npm, fzf, autosuggestions, syntax-highlighting
- 50,000 command history
- FZF fuzzy finder (Ctrl+R)

---

## Common Tasks

### Test Nginx Config

```bash
docker exec ransynsrv nginx -t
```

### Reload Nginx

```bash
docker exec ransynsrv nginx -s reload
```

### View Logs

```bash
docker exec ransynsrv tail -f /data/log/nginx/access.log
docker exec ransynsrv tail -f /data/log/nginx/error.log
```

### Update Container

```bash
docker compose down
docker compose build --no-cache
docker compose up -d
```

### Backup

```bash
tar -czf ransynsrv-backup.tar.gz data/
```

---

## Portainer Deployment

1. **Stacks** → **Add stack**
2. Name: `ransynsrv`
3. Upload `docker-compose.yml`
4. Add environment variables:

| Name | Value |
|------|-------|
| PUID | 1000 |
| PGID | 1000 |
| TZ | Asia/Dubai |
| HTTP_PORT | 8080 |
| DATA_PATH | /srv/ransynsrv/data |
| ANTHROPIC_API_KEY | sk-ant-... |

5. **Deploy**

---

## Troubleshooting

### Permission Denied

```bash
id $USER                          # Get your PUID/PGID
sudo chown -R 1000:1000 data/     # Fix ownership
```

### Nginx Won't Start

```bash
docker exec ransynsrv nginx -t    # Test config
docker compose logs               # View errors
```

### Claude Code Not Working

```bash
docker exec ransynsrv env | grep ANTHROPIC  # Check key
docker exec ransynsrv claude --version      # Test CLI
```

### GoAccess Empty

1. Generate traffic: `curl http://localhost:8080`
2. Check log: `docker exec ransynsrv cat /data/log/nginx/access.log`

### Container Logs

```bash
docker compose logs -f            # Follow all logs
docker compose logs ransynsrv     # Just container
```

---

## File Reference

```
ransynsrv/
├── Dockerfile
├── docker-compose.yml
├── .env.example
├── README.md
├── .gitignore
├── .dockerignore
└── root/
    ├── defaults/
    │   ├── nginx/nginx.conf
    │   └── www/
    │       ├── html/index.html
    │       └── goaccess/index.html
    └── etc/
        ├── goaccess/goaccess.conf
        └── s6-overlay/s6-rc.d/
            ├── init-ransynsrv/    (oneshot)
            ├── svc-nginx/         (longrun)
            ├── svc-php-fpm/       (longrun)
            ├── svc-goaccess/      (longrun)
            └── user/              (bundle)
```

---

## License

MIT License
