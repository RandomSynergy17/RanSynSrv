# RanSynSrv

> **A production-ready, feature-rich web server built on Alpine Linux with Nginx, PHP 8.4, real-time analytics, Claude Code CLI, and comprehensive development tools.**

Designed to run behind a reverse proxy — handles HTTP traffic only (no SSL).

[![Alpine Linux](https://img.shields.io/badge/Alpine-3.21-0D597F?logo=alpine-linux)](https://alpinelinux.org/)
[![Nginx](https://img.shields.io/badge/Nginx-Latest-009639?logo=nginx)](https://nginx.org/)
[![PHP](https://img.shields.io/badge/PHP-8.4-777BB4?logo=php)](https://www.php.net/)
[![GoAccess](https://img.shields.io/badge/GoAccess-1.9.4-00A1E0)](https://goaccess.io/)
[![Claude Code](https://img.shields.io/badge/Claude_Code-2.1.12-5D3FD3)](https://claude.ai/)

---

## Table of Contents

- [What's New](#whats-new)
- [Features Overview](#features-overview)
- [Quick Start](#quick-start)
- [Detailed Installation](#detailed-installation)
- [Configuration Reference](#configuration-reference)
- [Directory Structure](#directory-structure)
- [Core Features](#core-features)
  - [Claude Code AI Assistant](#claude-code-ai-assistant)
  - [GoAccess Real-Time Analytics](#goaccess-real-time-analytics)
  - [Node Version Manager (NVM)](#node-version-manager-nvm)
  - [Runtime Package Installation](#runtime-package-installation)
  - [Docker Logging Integration](#docker-logging-integration)
- [Package Reference](#package-reference)
- [Shell Environment](#shell-environment)
- [Common Tasks](#common-tasks)
- [Deployment Guides](#deployment-guides)
- [Migration Guide](#migration-guide)
- [Security](#security)
- [Troubleshooting](#troubleshooting)
- [Advanced Usage](#advanced-usage)
- [File Reference](#file-reference)
- [License](#license)

---

## What's New

### Version 1.0.0 - Major Release

#### Architecture Improvements

- **Consolidated data structure**: All persistent data now under single `/data` mount point
- **Simplified volume management**: One volume instead of three (easier backups/migrations)
- **Enhanced Portainer compatibility**: Proper labels and GUI-configurable variables
- **New directory layout**: Renamed `www` to `webroot` with subfolders for better organization

#### Latest Stable Versions

| Component | Version | Notes |
|-----------|---------|-------|
| **Claude Code** | 2.1.12 | Latest, with Alpine musl libc support |
| **GoAccess** | 1.9.4 | Latest stable release with MMDB GeoIP |
| **s6-overlay** | 3.2.0.3 | Latest with Kubernetes compatibility |
| **NVM** | 0.40.3 | Latest Node Version Manager |
| **Alpine Linux** | 3.21 | Latest stable with security patches |
| **PHP** | 8.4 | Latest PHP with 45+ extensions |
| **git-delta** | 0.18.2 | Beautiful git diffs |

#### Security Fixes

- **ImageMagick**: Pinned to >= 7.1.1.13-r0 (patched CVE-2025-68469)
- **GoAccess**: Added MMDB GeoIP dependency for proper builds with geo-location support
- **All packages**: Latest compatible versions from Alpine 3.21 repositories

#### Feature Enhancements

- **GoAccess WebSocket**: Configurable URL for reverse proxy setups (`GOACCESS_WS_URL`)
- **Real-IP forwarding**: Proper client IP detection behind proxies
- **Error handling**: Improved package installation with failure detection
- **PHP configuration**: Runtime configuration via environment variables
- **Health check endpoint**: Available at `/health` for load balancers

#### Documentation

- Complete environment variable reference with detailed explanations
- Reverse proxy configuration examples for common scenarios
- Troubleshooting guide for WebSocket connectivity issues
- Security best practices and hardening recommendations
- Migration guide for directory structure changes

---

## Features Overview

### Core Stack

| Component | Version | Description | Purpose |
|-----------|---------|-------------|---------|
| **Alpine Linux** | 3.21 | Minimal, secure base (~5MB) | Foundation OS |
| **Nginx** | Latest | High-performance with Brotli | Web server |
| **PHP** | 8.4 | Latest PHP, 45+ extensions | Application runtime |
| **PHP-FPM** | 8.4 | FastCGI Process Manager | PHP execution |
| **GoAccess** | 1.9.4 | Real-time web analytics | Traffic monitoring |
| **s6-overlay** | 3.2.0.3 | Process supervision | Service management |
| **Claude Code** | 2.1.12 | AI coding assistant CLI | Development aid |
| **NVM** | 0.40.3 | Node version manager | Node.js versions |

### Integrated Mods

RanSynSrv integrates functionality from three universal mods:

| Mod | Feature | Environment Variable | Description |
|-----|---------|---------------------|-------------|
| **stdout-logs** | Docker logging driver support | `DOCKER_LOGS=true` | Send logs to Docker (for Loki, ELK, etc.) |
| **package-install** | Runtime package installation | `INSTALL_PACKAGES`, `INSTALL_PIP_PACKAGES` | Install packages on startup |
| **nvm** | Node Version Manager | `nvm use 20` | Switch Node.js versions dynamically |

### Nginx Modules

| Module | Feature | Use Case |
|--------|---------|----------|
| **http-brotli** | Brotli compression | Better compression than gzip |
| **http-headers-more** | Advanced headers | Security headers, CORS |
| **http-fancyindex** | Directory listing | File browser |
| **http-image-filter** | Image processing | Thumbnails, resizing |

---

## Quick Start

### 1. Extract and Navigate

```bash
unzip ransynsrv.zip
cd ransynsrv
```

### 2. Configure Environment

```bash
# Copy example configuration
cp .env.example .env

# Get your user/group IDs
id $USER
# Output: uid=1000(user) gid=1000(group)

# Edit .env file
nano .env
```

Set at minimum:
```env
PUID=1000              # Your user ID from 'id $USER'
PGID=1000              # Your group ID from 'id $USER'
TZ=America/New_York    # Your timezone
HTTP_PORT=8080         # Host port to bind
```

### 3. Start Container

```bash
# Build and start
docker compose up -d --build

# Watch logs (optional)
docker compose logs -f
```

### 4. Access Services

| Service | URL | Description |
|---------|-----|-------------|
| **Website** | http://localhost:8080 | Main web server |
| **Analytics** | http://localhost:8080/goaccess | Real-time dashboard |
| **Health Check** | http://localhost:8080/health | Container health |

### 5. Test It Works

```bash
# Generate some traffic
curl http://localhost:8080
curl http://localhost:8080/goaccess

# Check analytics update
open http://localhost:8080/goaccess
```

---

## Detailed Installation

### Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- 1GB free disk space
- Port 8080 available (or configure different port)

### System Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 1 core | 2+ cores |
| RAM | 512MB | 1GB+ |
| Disk | 500MB | 2GB+ |

### Step-by-Step Installation

#### 1. Download and Extract

```bash
# Method 1: From ZIP
unzip ransynsrv.zip -d /opt/
cd /opt/ransynsrv

# Method 2: From Git (if hosted)
git clone https://github.com/yourusername/ransynsrv.git /opt/ransynsrv
cd /opt/ransynsrv
```

#### 2. Configure Environment Variables

```bash
cp .env.example .env
nano .env
```

**Essential Configuration:**

```env
# User mapping (REQUIRED - prevents permission issues)
PUID=1000                           # Run: id -u
PGID=1000                           # Run: id -g

# Timezone (affects logs and PHP)
TZ=America/New_York                 # Your timezone

# Network
HTTP_PORT=8080                      # Host port to bind

# Data storage
DATA_PATH=./data                    # Or absolute path: /srv/ransynsrv/data
```

**Optional Configuration:**

```env
# PHP tuning
PHP_MEMORY_LIMIT=512M               # Increase for heavy apps
PHP_MAX_UPLOAD=100M                 # Larger file uploads
PHP_MAX_EXECUTION_TIME=600          # Longer scripts

# Claude Code (get key from https://console.anthropic.com/)
ANTHROPIC_API_KEY=sk-ant-...        # Your API key

# GoAccess (if behind reverse proxy)
GOACCESS_WS_URL=wss://domain.com/goaccess/ws

# Runtime packages
INSTALL_PACKAGES=mc tig ncdu        # Alpine packages
INSTALL_PIP_PACKAGES=pandas numpy   # Python packages

# Docker logging
DOCKER_LOGS=true                    # Send logs to Docker
```

#### 3. Build and Start

```bash
# Build image
docker compose build --no-cache

# Start container
docker compose up -d

# Verify startup
docker compose logs -f ransynsrv
```

Expected output:
```
==========================================
 RanSynSrv - Initializing
==========================================
[init] Installing default nginx.conf
[init] Installing default index.html
[init] Using file-based logging
==========================================
 RanSynSrv - Ready
==========================================
```

#### 4. Verify Installation

```bash
# Check container status
docker compose ps

# Test web server
curl http://localhost:8080

# Test health endpoint
curl http://localhost:8080/health
# Expected: OK

# Test analytics
curl http://localhost:8080/goaccess
```

#### 5. Access Shell

```bash
# Enter container (Zsh with Powerlevel10k)
docker exec -it ransynsrv zsh

# Test Claude Code (if API key configured)
claude --version
# Expected: @anthropic-ai/claude-code@2.1.12

# Test NVM
nvm --version
# Expected: 0.40.3

# Exit
exit
```

---

## Configuration Reference

### Environment Variables

#### User and System

| Variable | Default | Description | Example |
|----------|---------|-------------|---------|
| `PUID` | `1000` | User ID for file ownership. Run `id -u` to get yours. | `1000` |
| `PGID` | `1000` | Group ID for file ownership. Run `id -g` to get yours. | `1000` |
| `TZ` | `Asia/Dubai` | Timezone for logs and PHP date functions. Use TZ database names. | `America/New_York` |
| `COMPOSE_PROJECT_NAME` | (folder name) | Unique name for multi-instance deployments. Affects network names. | `ransynsrv_prod` |

#### Network and Storage

| Variable | Default | Description | Example |
|----------|---------|-------------|---------|
| `HTTP_PORT` | `8080` | Host port to bind web server to. | `8080`, `80`, `9000` |
| `DATA_PATH` | `./data` | Path to persistent data directory. Can be relative or absolute. | `./data`, `/srv/ransynsrv/data` |

#### PHP Configuration

| Variable | Default | Description | Valid Range |
|----------|---------|-------------|-------------|
| `PHP_MEMORY_LIMIT` | `256M` | Maximum memory per PHP process. | `128M` - `2G` |
| `PHP_MAX_UPLOAD` | `50M` | Maximum file upload size. | `1M` - `1G` |
| `PHP_MAX_POST` | `50M` | Maximum POST data size. Should be >= `PHP_MAX_UPLOAD`. | `1M` - `1G` |
| `PHP_MAX_EXECUTION_TIME` | `300` | Maximum script execution time in seconds. | `30` - `3600` |

**PHP Configuration Notes:**
- Changes require container restart: `docker compose restart`
- Set `PHP_MAX_POST` equal to or larger than `PHP_MAX_UPLOAD`
- For heavy applications, increase `PHP_MEMORY_LIMIT` to 512M or 1G
- Long-running scripts may need higher `PHP_MAX_EXECUTION_TIME`

#### GoAccess Analytics

| Variable | Default | Description | Example |
|----------|---------|-------------|---------|
| `GOACCESS_ENABLED` | `true` | Enable/disable GoAccess analytics dashboard. | `true`, `false` |
| `GOACCESS_WS_URL` | (empty) | WebSocket URL for real-time updates. Leave empty for auto-detection. Required when behind reverse proxy. | `wss://domain.com/goaccess/ws` |

**GoAccess WebSocket Configuration:**

- **Local development**: Leave `GOACCESS_WS_URL` empty
- **Behind Traefik/NPM**: Set to `wss://yourdomain.com/goaccess/ws`
- **Custom port**: Include port if needed: `wss://domain.com:8080/goaccess/ws`

#### Claude Code

| Variable | Default | Description | How to Get |
|----------|---------|-------------|------------|
| `ANTHROPIC_API_KEY` | (empty) | API key for Claude Code CLI. Required for AI features. | Get from https://console.anthropic.com/ |

**Claude Code Setup:**
1. Visit https://console.anthropic.com/
2. Create an API key
3. Add to `.env`: `ANTHROPIC_API_KEY=sk-ant-...`
4. Restart container: `docker compose restart`
5. Test: `docker exec -it ransynsrv claude --version`

#### Runtime Package Installation

| Variable | Default | Description | Example |
|----------|---------|-------------|---------|
| `INSTALL_PACKAGES` | (empty) | Space-separated Alpine packages to install on startup. | `mc tig ncdu tmux` |
| `INSTALL_PIP_PACKAGES` | (empty) | Space-separated Python packages to install on startup. | `pandas numpy matplotlib` |

**Package Installation Notes:**
- Packages install before services start
- Installation errors will prevent container startup
- Packages don't persist across rebuilds (add to Dockerfile for permanent install)
- Useful for: testing packages, one-off tools, temporary dependencies

**Example:**
```env
INSTALL_PACKAGES=mc tig ncdu                    # File managers and disk usage
INSTALL_PIP_PACKAGES=pandas numpy matplotlib    # Data science
```

#### Docker Logging

| Variable | Default | Description | Use Case |
|----------|---------|-------------|----------|
| `DOCKER_LOGS` | `false` | Redirect logs to Docker stdout/stderr. | Loki, ELK, Splunk, CloudWatch |

**How It Works:**
- `false`: Logs written to `/data/log/nginx/` and `/data/log/php/`
- `true`: Log files symlinked to `/proc/1/fd/1` (stdout) and `/proc/1/fd/2` (stderr)

**View Docker Logs:**
```bash
docker compose logs -f                  # All logs
docker compose logs -f ransynsrv        # Container only
docker compose logs --tail=100          # Last 100 lines
```

### docker-compose.yml Configuration

#### Basic Configuration

```yaml
services:
  ransynsrv:
    image: ransynsrv:latest
    container_name: ransynsrv

    environment:
      - PUID=${PUID:-1000}
      - PGID=${PGID:-1000}
      - TZ=${TZ:-Asia/Dubai}

    volumes:
      - ${DATA_PATH:-./data}:/data

    ports:
      - "${HTTP_PORT:-8080}:80"

    restart: unless-stopped
```

#### Multi-Instance Configuration

To run multiple instances (e.g., staging + production):

**1. Uncomment in `.env`:**
```env
COMPOSE_PROJECT_NAME=ransynsrv_prod
```

**2. Uncomment in `docker-compose.yml`:**
```yaml
services:
  ransynsrv:
    # ... existing config ...

    networks:
      - ransynsrv

networks:
  ransynsrv:
    name: ${COMPOSE_PROJECT_NAME:-ransynsrv}_network
```

**3. Start each instance:**
```bash
# Production
cd /opt/ransynsrv_prod
echo "COMPOSE_PROJECT_NAME=ransynsrv_prod" >> .env
docker compose up -d

# Staging
cd /opt/ransynsrv_staging
echo "COMPOSE_PROJECT_NAME=ransynsrv_staging" >> .env
docker compose up -d
```

---

## Directory Structure

### Overview

All persistent data is consolidated under the `/data` mount point for simplified backups, migrations, and Portainer deployments.

```
data/
├── nginx/                      ← Nginx configuration
│   └── nginx.conf              → Main config (editable, survives restarts)
│
├── webroot/                    ← Web content (document root)
│   ├── public_html/            → Frontend files (HTML, CSS, JS) + API endpoints
│   │   ├── index.html          → Default homepage
│   │   ├── index.php           → PHP entry point (if used)
│   │   ├── api/                → API endpoints
│   │   ├── assets/             → CSS, JS, images
│   │   └── uploads/            → User uploads
│   │
│   ├── goaccess/               → Real-time analytics dashboard
│   │   └── index.html          → Auto-generated by GoAccess
│   │
│   └── src/                    → Backend PHP classes (not web-accessible)
│       ├── Database.php        → Example: Database class
│       ├── Auth.php            → Example: Authentication
│       └── ...                 → Your PHP classes
│
├── databases/                  ← SQLite databases
│   ├── app.db                  → Application database
│   └── analytics.db            → Analytics data
│
├── log/                        ← Application logs
│   ├── nginx/                  → Nginx logs
│   │   ├── access.log          → HTTP access log
│   │   └── error.log           → Nginx errors
│   └── php/                    → PHP logs
│       └── error.log           → PHP errors and warnings
│
├── claude/                     ← Claude Code configuration
│   └── .claude/                → Claude CLI config (API key, settings)
│
├── commandhistory/             ← Shell history (persistent)
│   ├── .bash_history           → Bash command history
│   └── .zsh_history            → Zsh command history
│
├── ssh/                        ← SSH keys (700 permissions)
│   ├── id_rsa                  → Private key
│   ├── id_rsa.pub              → Public key
│   ├── id_ed25519              → Modern key
│   └── known_hosts             → Known SSH hosts
│
├── scripts/                    ← Custom scripts
│   ├── backup.sh               → Example: Backup script
│   ├── deploy.sh               → Example: Deployment
│   └── ...                     → Your scripts
│
└── crontabs/                   ← Cron jobs
    └── abc                     → Crontab for 'abc' user
```

### Directory Descriptions

| Directory | Purpose | Web Accessible | Persistent |
|-----------|---------|----------------|------------|
| `/data/nginx/` | Nginx configuration files | No | Yes |
| `/data/webroot/public_html/` | Main website files (HTML, PHP, JS, CSS) | Yes | Yes |
| `/data/webroot/goaccess/` | Real-time analytics dashboard | Yes | Yes |
| `/data/webroot/src/` | Backend PHP classes (autoload) | No | Yes |
| `/data/databases/` | SQLite database files | No | Yes |
| `/data/log/nginx/` | Nginx access and error logs | No | Yes |
| `/data/log/php/` | PHP error log | No | Yes |
| `/data/claude/.claude/` | Claude Code configuration | No | Yes |
| `/data/commandhistory/` | Shell command history | No | Yes |
| `/data/ssh/` | SSH keys and config | No | Yes (700 perms) |
| `/data/scripts/` | Custom automation scripts | No | Yes |
| `/data/crontabs/` | Scheduled tasks | No | Yes |

### File Permissions

The init script automatically sets correct permissions:

```bash
# All persistent data owned by 'abc' user
chown -R abc:abc /data

# SSH directory secured (required for SSH keys)
chmod 700 /data/ssh
```

**Important:** Always set `PUID` and `PGID` to match your host user to avoid permission issues.

### Backup and Restore

**Backup all data:**
```bash
tar -czf ransynsrv-backup-$(date +%Y%m%d).tar.gz data/
```

**Restore all data:**
```bash
tar -xzf ransynsrv-backup-20260121.tar.gz
docker compose restart
```

**Selective backup:**
```bash
# Just website files
tar -czf webroot-backup.tar.gz data/webroot/

# Just databases
tar -czf databases-backup.tar.gz data/databases/

# Just logs
tar -czf logs-backup.tar.gz data/log/
```

---

## Core Features

### Claude Code AI Assistant

Claude Code is Anthropic's official CLI for Claude, providing AI-powered coding assistance directly in your container.

#### Setup

**1. Get API Key:**
Visit https://console.anthropic.com/ and create an API key.

**2. Configure:**
```bash
# Add to .env
echo 'ANTHROPIC_API_KEY=sk-ant-your-key-here' >> .env

# Restart container
docker compose restart
```

**3. Verify:**
```bash
docker exec -it ransynsrv claude --version
# Expected: @anthropic-ai/claude-code@2.1.12
```

#### Usage

**Enter container:**
```bash
docker exec -it ransynsrv zsh
```

**One-shot commands:**
```bash
# Ask questions
claude "how do I optimize this nginx config?"

# Code analysis
claude "explain /data/webroot/public_html/api.php"

# Generate code
claude "write a PHP function to connect to SQLite database"

# Debug errors
claude "why is nginx giving 502 errors?"

# Using 'cc' alias
cc "summarize /data/log/nginx/error.log"
```

**Interactive mode:**
```bash
# Start interactive session
claude

# Now chat naturally
> analyze the nginx access log and find the most common endpoints
> create a backup script for /data/databases/
> help me debug this PHP error
> exit
```

#### Example Workflows

**1. Debug PHP Application:**
```bash
claude "find and fix the bug in /data/webroot/public_html/api.php"
```

**2. Generate Nginx Config:**
```bash
claude "create nginx config for WordPress with caching and security headers"
```

**3. Analyze Logs:**
```bash
claude "summarize errors from /data/log/nginx/error.log in the last 24 hours"
```

**4. Create Deployment Script:**
```bash
claude "write a bash script to backup /data/webroot and deploy from git repo"
```

**5. Database Migration:**
```bash
claude "generate SQL to migrate MySQL database to SQLite format"
```

**6. Security Audit:**
```bash
claude "audit /data/nginx/nginx.conf for security issues and suggest improvements"
```

**7. Performance Optimization:**
```bash
claude "analyze /data/log/nginx/access.log and suggest caching strategies"
```

#### Features

- **Agentic coding**: Claude can read, write, and execute code
- **Full environment access**: Git, Node.js, Python, databases all available
- **Persistent configuration**: Config stored in `/data/claude/.claude`
- **Project workspace**: `/workspace` directory for development
- **Shell access**: Can run commands, install packages, modify files
- **Context awareness**: Understands your project structure

#### Tips

- Use descriptive prompts for better results
- Reference specific file paths: `/data/webroot/public_html/index.php`
- Ask Claude to explain its reasoning: "explain why you chose this approach"
- Use for learning: "explain what this Nginx directive does"
- Combine with other tools: "use ripgrep to find all TODO comments, then create a task list"

---

### GoAccess Real-Time Analytics

GoAccess provides beautiful, real-time web analytics without external services or tracking scripts.

#### Access Dashboard

| URL | Description |
|-----|-------------|
| http://localhost:8080/goaccess | Main dashboard |
| ws://localhost:7890 | WebSocket (real-time updates) |

#### Features

| Feature | Description |
|---------|-------------|
| **Real-time updates** | See visitors as they browse (via WebSocket) |
| **No tracking scripts** | Server-side analysis of Nginx logs |
| **Privacy-focused** | No data sent to third parties |
| **Rich metrics** | Visitors, requests, bandwidth, referrers, OS, browsers |
| **Geo-location** | Country/city of visitors (MaxMind GeoIP) |
| **Fast** | Processes millions of log lines per second |

#### Dashboard Panels

1. **Unique Visitors**: Daily/hourly unique visitors
2. **Requested Files**: Most popular pages and resources
3. **Static Requests**: CSS, JS, images, fonts
4. **Not Found URLs**: 404 errors
5. **Visitor Hostnames & IPs**: Where visitors come from
6. **Operating Systems**: OS distribution
7. **Browsers**: Browser usage
8. **Time Distribution**: Traffic patterns by hour/day
9. **Referrers**: Where visitors came from
10. **HTTP Status Codes**: 200, 404, 500, etc.

#### Configuration

**Enable/Disable:**
```env
GOACCESS_ENABLED=true    # Enable dashboard
GOACCESS_ENABLED=false   # Disable dashboard (saves resources)
```

**WebSocket URL (for reverse proxy):**
```env
# Local development (leave empty)
GOACCESS_WS_URL=

# Behind reverse proxy
GOACCESS_WS_URL=wss://yourdomain.com/goaccess/ws

# Custom port
GOACCESS_WS_URL=wss://yourdomain.com:8080/goaccess/ws
```

#### Behind Reverse Proxy

**Traefik:**
```yaml
labels:
  - "traefik.http.routers.ransynsrv.rule=Host(`example.com`)"
  - "traefik.http.routers.ransynsrv.entrypoints=websecure"
  - "traefik.http.routers.ransynsrv.tls.certresolver=letsencrypt"
```

**Nginx Proxy Manager:**
1. Create proxy host for `example.com`
2. Forward to `ransynsrv:80`
3. Enable WebSocket support
4. Set `GOACCESS_WS_URL=wss://example.com/goaccess/ws`

**Caddy:**
```caddy
example.com {
    reverse_proxy ransynsrv:80
}
```

---

### Node Version Manager (NVM)

NVM allows you to install and switch between multiple Node.js versions without rebuilding the container.

#### Usage

**Enter container:**
```bash
docker exec -it ransynsrv zsh
```

**List available versions:**
```bash
nvm ls-remote                   # All versions
nvm ls-remote --lts             # LTS versions only
nvm ls-remote 20                # All v20.x versions
```

**Install Node.js versions:**
```bash
nvm install node                # Latest version
nvm install --lts               # Latest LTS
nvm install 20                  # Latest v20.x
nvm install 18.19.0             # Specific version
```

**Switch between versions:**
```bash
nvm use 20                      # Use v20.x
nvm use 18                      # Use v18.x
nvm use node                    # Use latest installed
nvm use --lts                   # Use latest LTS
```

**Set default version:**
```bash
nvm alias default 20            # Default to v20.x
nvm alias default node          # Default to latest
```

**Check current version:**
```bash
node --version
npm --version
```

**List installed versions:**
```bash
nvm ls
```

**Uninstall version:**
```bash
nvm uninstall 18
```

#### Notes

- NVM is installed at `/usr/local/share/nvm`
- System Node.js (from Alpine) remains available as fallback
- Installed versions persist in container (not across rebuilds)
- Each Node.js version has isolated global packages

---

### Runtime Package Installation

Install additional packages at container startup without rebuilding the image.

#### Alpine Packages

**Configure in `.env`:**
```env
INSTALL_PACKAGES=mc tig ncdu tmux htop glances
```

**What happens:**
- Packages install during init phase (before services start)
- Uses Alpine's `apk` package manager
- Installation errors prevent container startup (safe)

**Common packages:**
```env
# File managers and utilities
INSTALL_PACKAGES=mc ranger vifm ncdu

# Monitoring tools
INSTALL_PACKAGES=htop atop iotop glances

# Network tools
INSTALL_PACKAGES=nmap tcpdump iftop mtr

# Development tools
INSTALL_PACKAGES=tig lazygit neovim emacs

# Database tools
INSTALL_PACKAGES=sqlite-analyzer postgresql-contrib
```

#### Python Packages

**Configure in `.env`:**
```env
INSTALL_PIP_PACKAGES=pandas numpy matplotlib seaborn
```

**What happens:**
- Packages install using `pip3`
- System-wide installation (PIP_BREAK_SYSTEM_PACKAGES=1)
- Installation errors prevent container startup

**Common packages:**
```env
# Data science
INSTALL_PIP_PACKAGES=pandas numpy scipy scikit-learn

# Web scraping
INSTALL_PIP_PACKAGES=beautifulsoup4 scrapy selenium

# Automation
INSTALL_PIP_PACKAGES=fabric paramiko ansible

# Testing
INSTALL_PIP_PACKAGES=pytest pytest-cov pytest-asyncio
```

---

### Docker Logging Integration

Send logs to Docker's logging driver for centralized log management.

#### Enable Docker Logs

```env
DOCKER_LOGS=true
```

#### How It Works

**When `DOCKER_LOGS=false` (default):**
- Logs written to files:
  - `/data/log/nginx/access.log`
  - `/data/log/nginx/error.log`
  - `/data/log/php/error.log`
- View with: `tail -f /data/log/nginx/access.log`

**When `DOCKER_LOGS=true`:**
- Log files symlinked to:
  - `/proc/1/fd/1` (stdout) for access logs
  - `/proc/1/fd/2` (stderr) for error logs
- Logs captured by Docker logging driver
- View with: `docker compose logs -f`

---

## Package Reference

### Complete Package List (200+ packages)

#### Core System (26 packages)

| Package | Version | Description |
|---------|---------|-------------|
| **shadow** | Latest | User management (useradd, usermod) |
| **tzdata** | Latest | Timezone database |
| **bash** | Latest | Bourne Again Shell |
| **bash-completion** | Latest | Tab completion for bash |
| **zsh** | Latest | Z Shell |
| **zsh-vcs** | Latest | Version control integration |
| **coreutils** | Latest | Core utilities (ls, cat, cp, mv) |
| **findutils** | Latest | Find utilities (find, xargs) |
| **grep** | Latest | Pattern matching |
| **sed** | Latest | Stream editor |
| **gawk** | Latest | GNU AWK |
| **util-linux** | Latest | System utilities |
| **zip** | Latest | ZIP archiver |
| **unzip** | Latest | ZIP extractor |
| **xz** | Latest | XZ compression |
| **bzip2** | Latest | BZIP2 compression |
| **gzip** | Latest | GZIP compression |
| **tar** | Latest | Tape archiver |
| **nano** | Latest | Simple text editor |
| **vim** | Latest | Vi IMproved editor |
| **procps** | Latest | Process tools (ps, top, kill) |
| **htop** | Latest | Interactive process viewer |
| **curl** | Latest | HTTP client |
| **wget** | Latest | HTTP downloader |
| **tree** | Latest | Directory tree viewer |
| **file** | Latest | File type detection |

#### Nginx (5 packages)

| Package | Description |
|---------|-------------|
| **nginx** | High-performance web server |
| **nginx-mod-http-brotli** | Brotli compression module |
| **nginx-mod-http-headers-more** | Advanced header manipulation |
| **nginx-mod-http-fancyindex** | Enhanced directory listing |
| **nginx-mod-http-image-filter** | On-the-fly image processing |

#### PHP 8.4 (45 packages)

**Core:**
- **php84** - PHP 8.4 interpreter
- **php84-fpm** - FastCGI Process Manager

**Standard Extensions (28):**
- **php84-bcmath** - Arbitrary precision math
- **php84-bz2** - Bzip2 compression
- **php84-calendar** - Calendar functions
- **php84-ctype** - Character type checking
- **php84-curl** - cURL library
- **php84-dom** - DOM manipulation
- **php84-exif** - Image metadata
- **php84-fileinfo** - File information
- **php84-ftp** - FTP client
- **php84-gd** - Image manipulation
- **php84-gettext** - Internationalization
- **php84-gmp** - GNU Multiple Precision
- **php84-iconv** - Character encoding
- **php84-imap** - Email protocols
- **php84-intl** - Internationalization
- **php84-ldap** - LDAP protocol
- **php84-mbstring** - Multibyte strings
- **php84-mysqli** - MySQL improved
- **php84-mysqlnd** - MySQL native driver
- **php84-opcache** - Opcode cache
- **php84-openssl** - SSL/TLS support
- **php84-pcntl** - Process control
- **php84-phar** - PHP archives
- **php84-posix** - POSIX functions
- **php84-session** - Session handling
- **php84-simplexml** - Simple XML
- **php84-soap** - SOAP protocol
- **php84-sockets** - Socket communication

**Database Extensions (8):**
- **php84-pdo** - PHP Data Objects
- **php84-pdo_mysql** - PDO MySQL driver
- **php84-pdo_pgsql** - PDO PostgreSQL driver
- **php84-pdo_sqlite** - PDO SQLite driver
- **php84-pgsql** - PostgreSQL
- **php84-sqlite3** - SQLite3
- **php84-pecl-redis** - Redis client
- **php84-pecl-igbinary** - Binary serializer

**XML Extensions (4):**
- **php84-xml** - XML parser
- **php84-xmlreader** - XML reader
- **php84-xmlwriter** - XML writer
- **php84-xsl** - XSLT processor

**Other Extensions (5):**
- **php84-tokenizer** - PHP tokenizer
- **php84-zip** - ZIP archives
- **php84-zlib** - Zlib compression
- **php84-pecl-apcu** - User cache
- **php84-sodium** - Modern cryptography

#### Python 3 (9 packages + 5 pip packages)

**System Packages:**
- **python3** - Python 3 interpreter
- **py3-pip** - Package installer
- **py3-setuptools** - Package builder
- **py3-wheel** - Binary packages
- **py3-virtualenv** - Virtual environments
- **py3-cryptography** - Cryptography library
- **py3-openssl** - OpenSSL bindings
- **py3-requests** - HTTP library
- **py3-yaml** - YAML parser
- **py3-jinja2** - Template engine

**Pip Packages:**
- **plyvel** - LevelDB bindings
- **python-snappy** - Snappy compression
- **ccl_chromium_reader** - Chrome data reader
- **httpie** - Modern HTTP client
- **glances** - System monitor

#### Node.js (5 packages)

| Package | Description |
|---------|-------------|
| **nodejs** | JavaScript runtime |
| **npm** | Package manager |
| **yarn** | Alternative package manager |
| **libgcc** | GCC runtime library |
| **libstdc++** | C++ standard library |

#### Development Tools (16 packages)

| Package | Version | Description |
|---------|---------|-------------|
| **git** | Latest | Version control |
| **git-lfs** | Latest | Large file storage |
| **git-perl** | Latest | Git Perl scripts |
| **github-cli** | Latest | GitHub CLI |
| **git-delta** | 0.18.2 | Beautiful git diffs |
| **fzf** | Latest | Fuzzy finder |
| **ripgrep** | Latest | Fast text search |
| **rsync** | Latest | File synchronization |
| **rclone** | Latest | Cloud sync |
| **openssh-client** | Latest | SSH client |
| **openssh-keygen** | Latest | SSH key generation |
| **ffmpeg** | Latest | Media processing |
| **imagemagick** | ≥7.1.1.13-r0 | Image processing |
| **graphicsmagick** | Latest | Image processing |
| **perl** | Latest | Perl interpreter |
| **bc** | Latest | Calculator |

#### Databases (7 packages)

| Package | Description |
|---------|-------------|
| **sqlite** | SQLite CLI |
| **sqlite-libs** | SQLite libraries |
| **mariadb-client** | MySQL/MariaDB client |
| **postgresql-client** | PostgreSQL client |
| **redis** | Redis CLI |
| **leveldb** | LevelDB library |
| **snappy** | Snappy compression |

#### Network Tools (8 packages)

| Package | Description |
|---------|-------------|
| **bind-tools** | DNS utilities (dig, nslookup) |
| **iputils** | IP utilities (ping) |
| **iproute2** | Advanced routing (ip, ss) |
| **iptables** | Firewall |
| **ipset** | IP set management |
| **ca-certificates** | SSL certificates |
| **openssl** | SSL/TLS toolkit |
| **httpie** | Modern HTTP client |

#### System Tools (9 packages)

| Package | Description |
|---------|-------------|
| **jq** | JSON processor |
| **yq** | YAML processor |
| **less** | File pager |
| **bc** | Calculator |
| **sudo** | Superuser access |
| **libcap** | Capabilities library |
| **libcap-utils** | Capability tools |
| **man-pages** | Manual pages |
| **mandoc** | Manual reader |

#### Special Components

| Component | Version | Installation Method |
|-----------|---------|---------------------|
| **s6-overlay** | 3.2.0.3 | GitHub release |
| **GoAccess** | 1.9.4 | Built from source |
| **Claude Code** | 2.1.12 | npm global |
| **NVM** | 0.40.3 | GitHub install script |

---

## Shell Environment

### Zsh with Powerlevel10k

RanSynSrv includes a fully configured Zsh environment.

#### Features

- **Powerlevel10k**: Fast, customizable prompt
- **Oh-My-Zsh**: Plugin framework
- **Auto-suggestions**: Command suggestions as you type
- **Syntax highlighting**: Color-coded commands
- **50,000 command history**: Persistent across restarts
- **FZF integration**: Fuzzy search (Ctrl+R)

#### Plugins

- git, docker, docker-compose, node, npm, fzf, rsync, sudo
- zsh-autosuggestions, zsh-syntax-highlighting, zsh-completions

#### Aliases

| Alias | Command |
|-------|---------|
| `ll` | `ls -alF` |
| `cc` | `claude` |
| `nginx-test` | `sudo nginx -t` |
| `nginx-reload` | `sudo nginx -s reload` |
| `logs` | `tail -f /data/log/nginx/access.log` |
| `errors` | `tail -f /data/log/nginx/error.log` |
| `phplogs` | `tail -f /data/log/php/error.log` |

---

## Common Tasks

### Nginx Management

```bash
# Test configuration
docker exec ransynsrv nginx -t

# Reload configuration
docker exec ransynsrv nginx -s reload

# Check Nginx status
docker exec ransynsrv ps aux | grep nginx
```

### PHP Management

```bash
# Check PHP version
docker exec ransynsrv php -v

# View loaded extensions
docker exec ransynsrv php -m

# Test PHP syntax
docker exec ransynsrv php -l /data/webroot/public_html/index.php
```

### Log Management

```bash
# Follow access log
docker exec ransynsrv tail -f /data/log/nginx/access.log

# Follow error log
docker exec ransynsrv tail -f /data/log/nginx/error.log

# Search logs
docker exec ransynsrv grep "404" /data/log/nginx/access.log
```

### Backup and Restore

```bash
# Full backup
tar -czf ransynsrv-backup-$(date +%Y%m%d).tar.gz data/

# Restore
tar -xzf ransynsrv-backup-20260121.tar.gz
docker compose restart
```

---

## Deployment Guides

### Portainer Deployment

1. **Stacks** → **Add stack**
2. Name: `ransynsrv`
3. Upload `docker-compose.yml`
4. Add environment variables:

| Name | Value |
|------|-------|
| PUID | 1000 |
| PGID | 1000 |
| TZ | America/New_York |
| HTTP_PORT | 8080 |
| DATA_PATH | /srv/ransynsrv/data |
| ANTHROPIC_API_KEY | sk-ant-... |
| GOACCESS_WS_URL | wss://domain.com/goaccess/ws |

5. **Deploy**
6. Check **Logs** tab

### Traefik Integration

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.ransynsrv.rule=Host(`example.com`)"
  - "traefik.http.routers.ransynsrv.entrypoints=websecure"
  - "traefik.http.routers.ransynsrv.tls.certresolver=letsencrypt"
```

---

## Migration Guide

### From Previous Versions

#### Previous Structure
```
nginx/ → nginx.conf
www/html/ → website files
log/ → logs
```

#### New Structure
```
data/
├── nginx/ → nginx.conf
├── webroot/public_html/ → website files (renamed from html)
├── webroot/goaccess/ → analytics
├── webroot/src/ → backend classes (NEW)
├── databases/ → SQLite files (NEW)
└── log/ → logs
```

#### Migration Steps

**1. Stop old container:**
```bash
docker compose stop
```

**2. Create new structure:**
```bash
mkdir -p data/{nginx,webroot/{public_html,goaccess,src},databases,log/{nginx,php},claude/.claude,commandhistory,ssh,scripts,crontabs}
```

**3. Copy existing data:**
```bash
# Copy Nginx config
cp nginx/nginx.conf data/nginx/

# Copy website files (html → public_html)
cp -r www/html/* data/webroot/public_html/

# Copy GoAccess
cp -r www/goaccess/* data/webroot/goaccess/

# Copy logs
cp -r log/nginx/* data/log/nginx/
cp -r log/php/* data/log/php/
```

**4. Update docker-compose.yml:**
```yaml
volumes:
  - ./data:/data
```

**5. Start new container:**
```bash
docker compose up -d --build
```

**6. Verify:**
```bash
curl http://localhost:8080
curl http://localhost:8080/goaccess
```

---

## Security

### Hardened Dependencies

- **ImageMagick**: ≥7.1.1.13-r0 (CVE-2025-68469 patched)
- **All packages**: Latest from Alpine 3.21
- **Claude Code**: Latest v2.1.12
- **GoAccess**: Latest v1.9.4 with MMDB GeoIP

### Running Behind Reverse Proxy

- **No SSL/TLS**: Proxy handles HTTPS
- **Real-IP forwarding**: X-Forwarded-For support
- **Health check**: `/health` endpoint
- **WebSocket support**: GoAccess real-time updates

### Best Practices

1. **User mapping**: Set PUID/PGID to match host user
2. **API keys**: Store in .env, not version control
3. **File permissions**: SSH directory secured (700)
4. **Log rotation**: Enable Docker logging with rotation

---

## Troubleshooting

### Permission Denied

```bash
id $USER                          # Get PUID/PGID
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

```bash
curl http://localhost:8080        # Generate traffic
docker exec ransynsrv cat /data/log/nginx/access.log
```

### GoAccess WebSocket Not Updating

Behind reverse proxy? Set WebSocket URL:
```env
GOACCESS_WS_URL=wss://yourdomain.com/goaccess/ws
```

### Container Logs

```bash
docker compose logs -f            # Follow all logs
docker compose logs ransynsrv     # Just container
```

---

## Advanced Usage

### Custom Nginx Configuration

Create `/data/nginx/custom.conf`:
```nginx
server {
    listen 80;
    server_name api.example.com;
    location / {
        proxy_pass http://backend:8000;
    }
}
```

Include in main config:
```nginx
http {
    include /data/nginx/*.conf;
}
```

### Cron Jobs

```bash
# Edit crontab
docker exec -it ransynsrv crontab -e

# Backup database daily at 2am
0 2 * * * tar -czf /data/databases/backup.tar.gz /data/databases/*.db
```

### Git Deployment

```bash
# Generate SSH key
docker exec -it ransynsrv ssh-keygen -t ed25519

# Clone repository
docker exec -it ransynsrv git clone git@github.com:user/repo.git /workspace/repo

# Deploy to webroot
docker exec ransynsrv rsync -av /workspace/repo/ /data/webroot/public_html/
```

---

## File Reference

```
ransynsrv/
├── Dockerfile                          ← Container build
├── docker-compose.yml                  ← Orchestration
├── .env.example                        ← Environment template
├── README.md                           ← This documentation
├── .gitignore                          ← Git ignore rules
├── .dockerignore                       ← Docker ignore rules
│
└── root/                               ← Files copied to container
    ├── defaults/                       ← Default files
    │   ├── nginx/nginx.conf            ← Default Nginx config
    │   └── webroot/
    │       ├── public_html/index.html  ← Default homepage
    │       └── goaccess/index.html     ← Analytics dashboard
    │
    └── etc/                            ← System configuration
        ├── goaccess/goaccess.conf      ← GoAccess settings
        └── s6-overlay/s6-rc.d/         ← Service definitions
            ├── init-ransynsrv/         ← Init (oneshot)
            ├── svc-nginx/              ← Nginx (longrun)
            ├── svc-php-fpm/            ← PHP-FPM (longrun)
            ├── svc-goaccess/           ← GoAccess (longrun)
            └── user/                   ← Service bundle
```

---

## License

MIT License

Copyright (c) 2025 Random Synergy

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---

**Built with** Alpine Linux, Nginx, PHP, GoAccess, Claude Code, and dedication.
