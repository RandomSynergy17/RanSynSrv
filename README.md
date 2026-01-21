# RanSynSrv

> **A production-ready, feature-rich web server built on Alpine Linux with Nginx, PHP 8.4, real-time analytics, Claude Code CLI, and comprehensive development tools.**

Designed to run behind a reverse proxy — handles HTTP traffic only (no SSL).

[![GHCR](https://img.shields.io/badge/GHCR-ghcr.io%2Frandomsynergy17%2Fransynsrv-blue?logo=github)](https://github.com/RandomSynergy17/RanSynSrv/pkgs/container/ransynsrv)
[![Alpine Linux](https://img.shields.io/badge/Alpine-3.21-0D597F?logo=alpine-linux)](https://alpinelinux.org/)
[![Nginx](https://img.shields.io/badge/Nginx-Latest-009639?logo=nginx)](https://nginx.org/)
[![PHP](https://img.shields.io/badge/PHP-8.4-777BB4?logo=php)](https://www.php.net/)
[![GoAccess](https://img.shields.io/badge/GoAccess-1.9.4-00A1E0)](https://goaccess.io/)
[![Claude Code](https://img.shields.io/badge/Claude_Code-2.1.12-5D3FD3)](https://claude.ai/)

---

## Table of Contents

- [Version](#version)
- [Features Overview](#features-overview)
- [Quick Start](#quick-start)
- [Detailed Installation](#detailed-installation)
- [Configuration Reference](#configuration-reference)
- [Directory Structure](#directory-structure)
- [Core Features](#core-features)
  - [Claude Code AI Assistant](#claude-code-ai-assistant)
  - [GoAccess Real-Time Analytics](#goaccess-real-time-analytics)
  - [ttyd Web Terminal](#ttyd-web-terminal)
  - [Node Version Manager (NVM)](#node-version-manager-nvm)
  - [Runtime Package Installation](#runtime-package-installation)
  - [Docker Logging Integration](#docker-logging-integration)
- [Package Reference](#package-reference)
- [Shell Environment](#shell-environment)
- [Common Tasks](#common-tasks)
- [Deployment Guides](#deployment-guides)
- [Security](#security)
- [Troubleshooting](#troubleshooting)
- [Advanced Usage](#advanced-usage)
- [File Reference](#file-reference)
- [License](#license)

---

## Version

### Version 1.0.0 - Initial Release

RanSynSrv is a production-ready Docker bundle featuring the latest stable versions of Alpine Linux, Nginx, PHP 8.4, GoAccess analytics, and Claude Code CLI.

**Testing Status**: ✅ Comprehensively tested with Chrome DevTools
- PHP 8.4.14 rendering confirmed
- GoAccess real-time analytics dashboard operational
- All services startup verified
- Security hardening applied and validated

#### Component Versions

| Component | Version | Description |
|-----------|---------|-------------|
| **Alpine Linux** | 3.21 | Minimal, secure base with latest security patches |
| **Nginx** | Latest | High-performance web server with Brotli compression |
| **PHP** | 8.4 | Latest PHP with 45+ extensions |
| **GoAccess** | 1.9.4 | Real-time web analytics with MMDB GeoIP support |
| **s6-overlay** | 3.2.0.3 | Process supervision with Kubernetes compatibility |
| **Claude Code** | 2.1.12 | AI coding assistant with Alpine musl libc support |
| **NVM** | 0.40.3 | Node Version Manager for dynamic Node.js versions |
| **git-delta** | 0.18.2 | Beautiful git diffs |

#### Architecture

- **Unified data structure**: All persistent data under single `/data` mount point for simplified backups and migrations
- **Portainer-ready**: Proper labels and GUI-configurable environment variables
- **Organized layout**: Frontend and database separation with `webroot/public_html` and `databases` directories
- **Real-IP forwarding**: Proper client IP detection when running behind reverse proxies
- **WebSocket support**: GoAccess real-time updates with configurable WebSocket URL
- **Runtime configuration**: PHP settings adjustable via environment variables
- **Health check endpoint**: Available at `/health` for load balancer integration
- **Flexible logging**: File-based or Docker stdout logging modes

#### Security

- **Hardened dependencies**: ImageMagick >= 7.1.1.13-r0 (CVE-2025-68469 patched)
- **Latest packages**: All packages from Alpine 3.21 stable repositories
- **Secure defaults**: Non-root user, restricted file permissions, security headers

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
| **ttyd** | Latest | Web-based terminal | Browser shell access |
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

Choose your deployment method:

### Option 1: Deploy from GHCR (Recommended)

Pull the pre-built image from GitHub Container Registry - fastest for end users.

```bash
# 1. Create project directory
mkdir ransynsrv && cd ransynsrv

# 2. Download configuration files
curl -LO https://raw.githubusercontent.com/RandomSynergy17/RanSynSrv/main/docker-compose.deploy.yml
curl -LO https://raw.githubusercontent.com/RandomSynergy17/RanSynSrv/main/.env.example

# 3. Configure environment
cp .env.example .env
nano .env  # Set PUID, PGID, TZ at minimum

# 4. Start container
docker compose -f docker-compose.deploy.yml up -d

# 5. Access services
open http://localhost:8080
```

**Image:** `ghcr.io/randomsynergy17/ransynsrv:latest`

**Available Tags:**
| Tag | Description |
|-----|-------------|
| `latest` | Latest stable release from main branch |
| `main` | Latest from main branch |
| `v1.0.0` | Specific version (when tagged) |
| `abc1234` | Specific commit SHA |

**Architectures:** `linux/amd64`, `linux/arm64`

---

### Option 2: Build from Source

Clone the repository and build locally - for developers who want to modify the image.

```bash
# 1. Clone repository
git clone https://github.com/RandomSynergy17/RanSynSrv.git
cd RanSynSrv

# 2. Configure environment
cp .env.example .env
nano .env  # Set PUID, PGID, TZ at minimum

# 3. Build and start
docker compose up -d --build

# 4. Access services
open http://localhost:8080
```

---

### Configure Environment

```bash
# Get your user/group IDs
id $USER
# Output: uid=1000(user) gid=1000(group)
```

Set at minimum in `.env`:
```env
PUID=1000              # Your user ID from 'id $USER'
PGID=1000              # Your group ID from 'id $USER'
TZ=America/New_York    # Your timezone
HTTP_PORT=8080         # Host port to bind
```

### Access Services

| Service | URL | Description |
|---------|-----|-------------|
| **Website** | http://localhost:8080 | PHP homepage with phpinfo() |
| **Analytics** | http://localhost:8080/goaccess | Real-time dashboard |
| **Terminal** | http://localhost:8080/ttyd | Web terminal (requires TTYD_ENABLED=true) |
| **Health Check** | http://localhost:8080/health | Container health |

### Test It Works

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

### Deployment Methods

| Method | Use Case | Compose File |
|--------|----------|--------------|
| **GHCR Pull** | End users, production deployments | `docker-compose.deploy.yml` |
| **Build from Source** | Developers, customization | `docker-compose.yml` |

### Step-by-Step Installation

#### Method A: Deploy from GHCR (Recommended)

```bash
# Create and navigate to project directory
mkdir -p /opt/ransynsrv && cd /opt/ransynsrv

# Download deployment files
curl -LO https://raw.githubusercontent.com/RandomSynergy17/RanSynSrv/main/docker-compose.deploy.yml
curl -LO https://raw.githubusercontent.com/RandomSynergy17/RanSynSrv/main/.env.example

# Rename compose file for convenience (optional)
mv docker-compose.deploy.yml docker-compose.yml
```

#### Method B: Build from Source

```bash
# Clone repository
git clone https://github.com/RandomSynergy17/RanSynSrv.git /opt/ransynsrv
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

# GoAccess WebSocket (REQUIRED for real-time updates)
GOACCESS_WS_URL=ws://localhost:8080/goaccess/ws     # Local development
# GOACCESS_WS_URL=wss://domain.com/goaccess/ws      # Production with SSL

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
[init] Installing default index.php
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
| `GOACCESS_WS_URL` | `ws://localhost:8080/goaccess/ws` | WebSocket URL for real-time updates. **MUST match how you access the container.** | See examples below |

**GoAccess WebSocket Configuration:**

The WebSocket URL must match the scheme (ws/wss), hostname, and port that your browser uses to access the container.

- **Local development**: `ws://localhost:8080/goaccess/ws` (default)
- **Behind Traefik/NPM with SSL**: `wss://yourdomain.com/goaccess/ws`
- **Behind reverse proxy without SSL**: `ws://yourdomain.com/goaccess/ws`
- **Custom port**: Include port: `ws://localhost:9000/goaccess/ws`

**Important**: Without proper configuration, the dashboard shows "Unable to authenticate WebSocket" and displays static analytics only (no real-time updates).

**HTTP Basic Authentication (Optional):**

| Variable | Default | Description | Example |
|----------|---------|-------------|---------|
| `GOACCESS_AUTH_ENABLED` | `false` | Enable/disable HTTP Basic Authentication for /goaccess dashboard. | `true`, `false` |
| `GOACCESS_USERNAME` | `admin` | Username for authentication (only used when GOACCESS_AUTH_ENABLED=true). | `admin`, `analytics_user` |
| `GOACCESS_PASSWORD` | (empty) | Password for authentication. **Required** when GOACCESS_AUTH_ENABLED=true. | `your_secure_password` |

To enable authentication:
```env
GOACCESS_AUTH_ENABLED=true
GOACCESS_USERNAME=admin
GOACCESS_PASSWORD=your_secure_password_here
```

Then restart: `docker compose down && docker compose up -d`

The dashboard will require login credentials when accessed. Authentication is disabled by default for ease of local development.

#### ttyd Web Terminal

| Variable | Default | Description | Example |
|----------|---------|-------------|---------|
| `TTYD_ENABLED` | `false` | Enable/disable web terminal at /ttyd. Disabled by default for security. | `true`, `false` |
| `TTYD_USERNAME` | `admin` | Username for terminal authentication. **Required** when TTYD_ENABLED=true. | `admin`, `developer` |
| `TTYD_PASSWORD` | (empty) | Password for terminal authentication. **Required** when TTYD_ENABLED=true. | `your_secure_password` |

**Security Warning**: The web terminal provides shell access to your container. Always:
- Set strong credentials (`TTYD_USERNAME` and `TTYD_PASSWORD`)
- Use behind HTTPS reverse proxy in production
- Consider IP whitelisting at the reverse proxy level

**To enable:**
```env
TTYD_ENABLED=true
TTYD_USERNAME=admin
TTYD_PASSWORD=your_secure_password_here
```

Then restart: `docker compose restart`

Access at: http://localhost:8080/ttyd

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

### Initial Structure (Created Automatically on First Launch)

The container automatically creates this directory structure and initial files:

```
data/
├── nginx/
│   └── nginx.conf              ✓ Copied from defaults (editable, persists)
│
├── webroot/
│   ├── public_html/
│   │   └── index.php           ✓ Default PHP homepage (editable, persists)
│   └── goaccess/
│       └── index.html          ✓ Analytics dashboard (auto-regenerated by GoAccess)
│
├── databases/                   ✓ Empty directory (ready for your SQLite files)
│
├── log/
│   ├── nginx/
│   │   ├── access.log          ✓ Created empty (populated as traffic arrives)
│   │   └── error.log           ✓ Created empty (populated if errors occur)
│   └── php/
│       └── error.log           ✓ Created empty (populated if PHP errors)
│
├── claude/
│   └── .claude/                ✓ Empty (populated when you use 'claude' CLI)
│
├── commandhistory/              ✓ Empty (history files created on first shell use)
│
├── ssh/                         ✓ Empty, chmod 700 (ready for your SSH keys)
│
├── scripts/                     ✓ Empty (ready for your custom scripts)
│
└── crontabs/                    ✓ Empty (ready for cron jobs)
```

**Legend:**
- ✓ = Automatically created by container
- All directories and files owned by `abc:abc` (mapped to your PUID:PGID)

### Optional Files (Created Conditionally)

```
data/nginx/.htpasswd             ✓ Only created if GOACCESS_AUTH_ENABLED=true
```

### After Regular Use (User-Created Content)

As you use the container, you'll add your own content:

```
data/
├── webroot/public_html/
│   ├── index.php               ← Default (already exists)
│   ├── api/                    ⊕ Your API endpoints
│   ├── assets/                 ⊕ Your CSS, JS, images
│   └── uploads/                ⊕ User file uploads
│
├── databases/
│   ├── app.db                  ⊕ Your application database
│   └── analytics.db            ⊕ Your analytics data
│
├── commandhistory/
│   ├── .bash_history           ⊕ Created when you use bash
│   └── .zsh_history            ⊕ Created when you use zsh
│
├── ssh/
│   ├── id_rsa                  ⊕ Your SSH keys (if generated)
│   ├── id_rsa.pub              ⊕ Public key
│   ├── id_ed25519              ⊕ Modern Ed25519 key
│   └── known_hosts             ⊕ Known SSH hosts
│
├── scripts/
│   ├── backup.sh               ⊕ Your custom scripts
│   ├── deploy.sh               ⊕ Your automation
│   └── ...                     ⊕ Your tools
│
└── crontabs/
    └── abc                     ⊕ Your cron jobs (if configured)
```

**Legend:**
- ⊕ = Created by you or your applications

### Directory Reference

| Directory | Purpose | Auto-Created | Web Accessible |
|-----------|---------|--------------|----------------|
| `/data/nginx/` | Nginx configuration files | ✓ | No |
| `/data/webroot/public_html/` | Main website files (HTML, PHP, JS, CSS) | ✓ (with index.php) | Yes |
| `/data/webroot/goaccess/` | Real-time analytics dashboard | ✓ (auto-generated) | Yes |
| `/data/databases/` | SQLite database files | ✓ (empty) | No |
| `/data/log/nginx/` | Nginx access and error logs | ✓ | No |
| `/data/log/php/` | PHP error log | ✓ | No |
| `/data/claude/.claude/` | Claude Code configuration | ✓ (empty) | No |
| `/data/commandhistory/` | Shell command history | ✓ (empty) | No |
| `/data/ssh/` | SSH keys and config | ✓ (empty, 700 perms) | No |
| `/data/scripts/` | Custom automation scripts | ✓ (empty) | No |
| `/data/crontabs/` | Scheduled tasks | ✓ (empty) | No |

**Notes:**
- All directories and files are created automatically on first container launch
- Empty directories are ready for your content
- All owned by `abc:abc` user (mapped to your PUID:PGID)
- SSH directory has strict 700 permissions for security

### File Permissions

The init script automatically sets correct permissions on first launch:

```bash
# All persistent data owned by 'abc' user
chown -R abc:abc /data /workspace

# SSH directory secured (required for SSH keys)
chmod 700 /data/ssh
```

**Important:** Always set `PUID` and `PGID` to match your host user to avoid permission issues.

**How It Works:**
1. You set `PUID=1000` and `PGID=1000` in `.env` (matching your host user)
2. Container creates user `abc` with UID 1000 and GID 1000
3. All files in `/data` are owned by `abc:abc` (UID 1000:GID 1000)
4. On host, these files appear owned by your user (UID 1000)
5. You can edit files directly on host without permission issues

### Verify Directory Structure

Check the actual structure after container launch:

```bash
# View directory tree (if tree is installed)
docker exec ransynsrv tree -L 3 /data

# Or use find command
docker exec ransynsrv find /data -maxdepth 3 -type d | sort

# Check file ownership
docker exec ransynsrv ls -la /data/

# Verify SSH directory permissions
docker exec ransynsrv stat -c '%a %n' /data/ssh
# Expected: 700 /data/ssh
```

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

# Set WebSocket URL in .env
environment:
  - GOACCESS_WS_URL=wss://example.com/goaccess/ws
```

**Nginx Proxy Manager:**
1. Create proxy host for `example.com`
2. Forward to `ransynsrv:80`
3. Enable WebSocket support
4. Set in `.env`: `GOACCESS_WS_URL=wss://example.com/goaccess/ws`
5. Restart container: `docker compose restart`

**Caddy:**
```caddy
example.com {
    reverse_proxy ransynsrv:80
}

# Set WebSocket URL in .env
# GOACCESS_WS_URL=wss://example.com/goaccess/ws
```

**Testing Real-Time Updates:**
1. Open GoAccess dashboard: `https://example.com/goaccess`
2. Generate traffic: `curl https://example.com`
3. Dashboard should update within 1-2 seconds
4. Look for "Last Updated" timestamp changing

---

### ttyd Web Terminal

ttyd provides secure, browser-based terminal access to your container's Zsh shell.

#### Access

| URL | Description |
|-----|-------------|
| http://localhost:8080/ttyd | Web terminal (requires authentication) |

#### Features

| Feature | Description |
|---------|-------------|
| **Browser-based** | No SSH client needed, works in any browser |
| **Zsh shell** | Full Zsh environment with Powerlevel10k |
| **HTTP Basic Auth** | Username/password protection |
| **WebSocket** | Real-time, low-latency terminal |
| **Lightweight** | ~2MB, minimal resource usage |
| **Copy/paste** | Full clipboard support |

#### Enable Terminal

**1. Configure in `.env`:**
```env
TTYD_ENABLED=true
TTYD_USERNAME=admin
TTYD_PASSWORD=your_secure_password
```

**2. Restart container:**
```bash
docker compose restart
```

**3. Access:**
Open http://localhost:8080/ttyd and enter your credentials.

#### Security Considerations

- **Disabled by default**: Must explicitly enable with `TTYD_ENABLED=true`
- **Authentication required**: Always set `TTYD_USERNAME` and `TTYD_PASSWORD`
- **Localhost only**: ttyd binds to 127.0.0.1, accessible only via nginx proxy
- **HTTPS in production**: Use reverse proxy with SSL for encrypted connections

#### Use Cases

- **Quick access**: Access container without SSH client or `docker exec`
- **Mobile/tablet**: Manage container from any device with a browser
- **Debugging**: Interactive troubleshooting in production
- **Demonstrations**: Show terminal sessions in presentations

#### Behind Reverse Proxy

The terminal works automatically behind reverse proxies since it's served through nginx at /ttyd.

**Traefik/NPM with SSL:**
- No additional configuration needed
- WebSocket upgrade handled by nginx
- Access at `https://yourdomain.com/ttyd`

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

### GHCR Deployment

**Image:** `ghcr.io/randomsynergy17/ransynsrv:latest`

```bash
# Pull latest image
docker pull ghcr.io/randomsynergy17/ransynsrv:latest

# Or use docker-compose.deploy.yml
docker compose -f docker-compose.deploy.yml up -d
```

**CI/CD Pipeline:** Images are automatically built and pushed to GHCR on:
- Push to `main` branch → Tagged as `latest` and `main`
- Version tags (e.g., `v1.0.0`) → Tagged with semantic versioning
- All builds → Tagged with commit SHA

### Portainer Deployment

1. **Stacks** → **Add stack**
2. Name: `ransynsrv`
3. Use `docker-compose.deploy.yml` (for GHCR) or `docker-compose.yml` (for building)
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

## Security

### Security Hardening (Version 1.0.0)

RanSynSrv has undergone comprehensive security hardening based on DevOps expert review:

**CRITICAL Fixes Applied:**
- ✅ **Restricted sudo access**: User `abc` limited to nginx config testing only (was: unrestricted root access)
- ✅ **Pinned Python packages**: All pip packages version-locked (plyvel 1.5.1, python-snappy 0.7.3, httpie 3.2.4, glances 4.2.0)
- ✅ **Verified NVM installation**: SHA256 checksum verification prevents script injection
- ✅ **s6-overlay integrity**: SHA256 checksum verification on all downloaded archives
- ✅ **Input validation**: INSTALL_PACKAGES/INSTALL_PIP_PACKAGES sanitized against command injection

**Security Configuration:**
- ✅ **Real-IP trust**: Disabled by default (must explicitly configure proxy IP to prevent spoofing)
- ✅ **Non-root execution**: All services run as user `abc` (UID 1000)
- ✅ **No hardcoded secrets**: ANTHROPIC_API_KEY via environment only

### Hardened Dependencies

- **ImageMagick**: ≥7.1.1.13-r0 (CVE-2025-68469 patched)
- **All packages**: Latest from Alpine 3.21
- **Claude Code**: Latest v2.1.12
- **GoAccess**: Latest v1.9.4 with MMDB GeoIP
- **s6-overlay**: v3.2.0.3 with checksum verification
- **NVM**: v0.40.3 with checksum verification

### Running Behind Reverse Proxy

- **No SSL/TLS**: Proxy handles HTTPS
- **Real-IP forwarding**: Commented out by default for security (configure `/data/nginx/nginx.conf` with your proxy IP)
- **Health check**: `/health` endpoint
- **WebSocket support**: GoAccess real-time updates

### Best Practices

1. **User mapping**: Set PUID/PGID to match host user
2. **API keys**: Store in .env, not version control
3. **File permissions**: SSH directory secured (700)
4. **Log rotation**: Enable Docker logging with rotation
5. **Real-IP configuration**: Only enable if behind trusted reverse proxy, specify exact proxy IP
6. **Sudo access**: Limited to `nginx -t` for config testing only

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

**Symptoms**: Dashboard shows "Unable to authenticate WebSocket" or no real-time updates

**Solution**: Configure `GOACCESS_WS_URL` to match your access method:

```env
# Local development (default)
GOACCESS_WS_URL=ws://localhost:8080/goaccess/ws

# Production with SSL
GOACCESS_WS_URL=wss://yourdomain.com/goaccess/ws

# Production without SSL
GOACCESS_WS_URL=ws://yourdomain.com/goaccess/ws
```

**Important**: The URL must match the scheme (ws/wss), hostname, and port that your browser uses.

After changing, restart the container:
```bash
docker compose restart
```

### Container Logs

```bash
docker compose logs -f            # Follow all logs
docker compose logs ransynsrv     # Just container
```

### PHP Page Not Loading

**Symptoms**: 502 Bad Gateway or PHP files download instead of executing

**Solution**: Check PHP-FPM socket permissions
```bash
docker exec ransynsrv ps aux | grep php-fpm    # Verify PHP-FPM running
docker exec ransynsrv ls -la /run/php/         # Check socket exists
docker logs ransynsrv 2>&1 | grep -i php       # Check for errors
```

If issues persist, restart container:
```bash
docker compose restart
```

### Nginx Config Not Applied

**Symptoms**: Changes to `/data/nginx/nginx.conf` not taking effect

**Solution**: The init script creates a symlink at startup. If the symlink is broken:
```bash
docker exec ransynsrv ls -la /etc/nginx/nginx.conf    # Check symlink
docker exec ransynsrv nginx -t                          # Test config
docker exec ransynsrv nginx -s reload                   # Reload if valid
```

Or restart container to recreate symlink:
```bash
docker compose restart
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
├── Dockerfile                          ← Container build definition
├── docker-compose.yml                  ← Build from source (developers)
├── docker-compose.deploy.yml           ← Pull from GHCR (end users)
├── .env.example                        ← Environment template
├── README.md                           ← This documentation
├── .gitignore                          ← Git ignore rules
├── .dockerignore                       ← Docker ignore rules
│
├── .github/
│   └── workflows/
│       └── docker-publish.yml          ← CI/CD: Build and push to GHCR
│
└── root/                               ← Files copied to container
    ├── defaults/                       ← Default files
    │   ├── nginx/nginx.conf            ← Default Nginx config
    │   └── webroot/
    │       ├── public_html/index.php   ← Default PHP homepage with phpinfo()
    │       └── goaccess/index.html     ← Analytics dashboard (auto-generated)
    │
    └── etc/                            ← System configuration
        ├── cont-init.d/                ← Legacy init scripts (ACTIVE)
        │   └── 00-init-ransynsrv       ← Initialization script (runs at startup)
        ├── goaccess/goaccess.conf      ← GoAccess settings
        └── s6-overlay/s6-rc.d/         ← Service definitions
            ├── init-ransynsrv/         ← Init (oneshot) - kept for reference
            ├── svc-nginx/              ← Nginx (longrun)
            ├── svc-php-fpm/            ← PHP-FPM (longrun)
            ├── svc-goaccess/           ← GoAccess (longrun)
            ├── svc-ttyd/               ← ttyd terminal (longrun)
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
