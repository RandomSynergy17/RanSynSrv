<div align="center">

# 🌀 RanSynSrv

### Batteries-included PHP 8.4 hosting container with real-time analytics, a web terminal, Claude Code CLI, and an optional pgvector-powered RAG sidecar.

[![GHCR](https://img.shields.io/badge/ghcr.io-randomsynergy17%2Fransynsrv-24292f?logo=github&logoColor=white&style=flat-square)](https://github.com/RandomSynergy17/RanSynSrv/pkgs/container/ransynsrv)
[![Build](https://img.shields.io/github/actions/workflow/status/RandomSynergy17/RanSynSrv/docker-publish.yml?branch=main&logo=github&style=flat-square)](https://github.com/RandomSynergy17/RanSynSrv/actions/workflows/docker-publish.yml)
[![Image Size](https://img.shields.io/docker/image-size/randomsynergy17/ransynsrv/latest?style=flat-square&logo=docker&logoColor=white)](https://github.com/RandomSynergy17/RanSynSrv/pkgs/container/ransynsrv)
[![Platforms](https://img.shields.io/badge/platforms-amd64_%7C_arm64-0db7ed?style=flat-square&logo=docker&logoColor=white)](#-architecture)
[![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](LICENSE)

[![Alpine Linux](https://img.shields.io/badge/Alpine-3.21-0D597F?logo=alpine-linux&logoColor=white&style=flat-square)](https://alpinelinux.org/)
[![Nginx](https://img.shields.io/badge/Nginx-mainline-009639?logo=nginx&logoColor=white&style=flat-square)](https://nginx.org/)
[![PHP](https://img.shields.io/badge/PHP-8.4-777BB4?logo=php&logoColor=white&style=flat-square)](https://www.php.net/)
[![GoAccess](https://img.shields.io/badge/GoAccess-1.9.4-00A1E0?style=flat-square)](https://goaccess.io/)
[![s6-overlay](https://img.shields.io/badge/s6--overlay-3.2-f77f00?style=flat-square)](https://github.com/just-containers/s6-overlay)
[![Claude Code](https://img.shields.io/badge/Claude_Code-2.1.118-5D3FD3?style=flat-square)](https://claude.ai/code)
[![pgvector](https://img.shields.io/badge/pgvector-0.8_%E2%80%A2_pg17-336791?logo=postgresql&logoColor=white&style=flat-square)](https://github.com/pgvector/pgvector)
[![TEI](https://img.shields.io/badge/HF_TEI-BGE--small-FFD21E?style=flat-square)](https://github.com/huggingface/text-embeddings-inference)

**[Quick Start](#-quick-start) • [Features](#-features) • [Configuration](#-configuration) • [AI Sidecar](#-ai-sidecar-overlay) • [Troubleshooting](CLAUDE.md#troubleshooting)**

</div>

---

## 🎯 Overview

RanSynSrv is a single-container PHP 8.4 hosting stack on Alpine Linux, wired with everything you need to run small-to-medium PHP apps in production *or* development:

- **Nginx** fronting **PHP-FPM 8.4** over a Unix socket, supervised by **s6-overlay v3**.
- **GoAccess** writing a live analytics dashboard from the access log.
- **ttyd** serving a browser-accessible zsh shell (optional, HTTP-Basic-auth protected).
- **Claude Code CLI** baked in so you can `docker exec` into an AI-assisted workflow.
- **45+ PHP extensions**, NVM, Python, Ripgrep, FZF, git-delta, and the usual dev tools pre-installed.
- An **optional AI sidecar overlay** ([`docker-compose.ai.yml`](docker-compose.ai.yml)) that adds pgvector-enabled Postgres 17 + a local text-embedding service (HuggingFace TEI serving BGE-small-en-v1.5) on the same compose network.

Designed to run **behind a reverse proxy** (Traefik, Caddy, Nginx Proxy Manager, etc.). HTTP only — the reverse proxy owns TLS.

---

## ✨ Features

<table>
<tr>
<td valign="top" width="50%">

### Core stack
| | |
|---|---|
| 🏔️ | Alpine 3.21, multi-arch (amd64 + arm64) |
| 🚦 | s6-overlay supervision, not systemd |
| 🐘 | PHP 8.4 with 45+ extensions |
| 🌐 | Nginx with Brotli / headers-more / fancyindex |
| 📊 | GoAccess 1.9.4 real-time dashboard |
| 🖥️ | ttyd web terminal (opt-in, Basic-Auth) |
| 🤖 | Claude Code CLI pre-installed |
| 🐙 | GitHub CLI (`gh`) pre-installed |
| 🔑 | HTTP Basic auth for `/goaccess` (env-toggled) |

</td>
<td valign="top" width="50%">

### Dev & ops
| | |
|---|---|
| 🧩 | Runtime `apk` + `pip` installs via env |
| 📁 | Single `/data` volume — trivial backups |
| 📦 | Optional pgvector + TEI AI sidecar overlay |
| 🩺 | Healthcheck at `/health` |
| 🔒 | `no-new-privileges`, non-root workers, 2G mem-cap |
| 🪵 | File-based **or** stdout logging |
| 🔁 | Zero-downtime nginx reload |
| 🧑‍💻 | PUID/PGID mapping, no root files in your volume |

</td>
</tr>
</table>

---

## 🏁 Quick Start

### From GHCR (recommended)

```bash
# 1. Grab the deploy compose + env template
mkdir ransynsrv && cd ransynsrv
curl -fsSLO https://raw.githubusercontent.com/RandomSynergy17/RanSynSrv/main/docker-compose.deploy.yml
curl -fsSL  https://raw.githubusercontent.com/RandomSynergy17/RanSynSrv/main/.env.example -o .env

# 2. Set your user/group and (optionally) an API key
printf "\nPUID=%s\nPGID=%s\n" "$(id -u)" "$(id -g)" >> .env
nano .env                    # set ANTHROPIC_API_KEY if you want Claude Code

# 3. Up
docker compose -f docker-compose.deploy.yml up -d

# 4. Visit
open http://localhost:8080           # welcome page
open http://localhost:8080/goaccess  # analytics
```

### From source

```bash
git clone https://github.com/RandomSynergy17/RanSynSrv && cd RanSynSrv
cp .env.example .env && nano .env
docker compose up -d --build
```

### With the AI sidecar

```bash
echo "POSTGRES_PASSWORD=$(openssl rand -hex 32)" >> .env
docker compose -f docker-compose.yml -f docker-compose.ai.yml up -d

# Enable the vector extension once per database
docker exec ransynsrv-postgres psql -U ransynsrv -d ransynsrv \
  -c "CREATE EXTENSION IF NOT EXISTS vector;"
```

See **[AI Sidecar Overlay](#-ai-sidecar-overlay)** below for the PHP-side usage pattern.

---

## 📖 Configuration

All tunables live in `.env`. Every variable has a safe default unless explicitly marked **required**.

### Core container

| Variable | Default | Purpose |
|---|---|---|
| `PUID` / `PGID` | `1000` | Host user/group mapping (run `id $USER` to check) |
| `TZ` | `Asia/Dubai` | Timezone |
| `HTTP_PORT` | `8080` | Published HTTP port on the host |
| `DATA_PATH` | `./data` | Host path for persistent data |
| `COMPOSE_PROJECT_NAME` | folder name | Unique name for multi-instance deployments |
| `ANTHROPIC_API_KEY` | *(empty)* | Required if you want Claude Code CLI |

### PHP settings *(runtime, applied at each boot)*

| Variable | Default | Purpose |
|---|---|---|
| `PHP_MEMORY_LIMIT` | `256M` | PHP `memory_limit` |
| `PHP_MAX_UPLOAD` | `50M` | `upload_max_filesize` |
| `PHP_MAX_POST` | `50M` | `post_max_size` |
| `PHP_MAX_EXECUTION_TIME` | `300` | `max_execution_time` (seconds) |

### Logging & analytics

| Variable | Default | Purpose |
|---|---|---|
| `DOCKER_LOGS` | `false` | `true` routes nginx + PHP logs to `docker logs` (disables GoAccess real-time updates — pick one) |
| `GOACCESS_ENABLED` | `true` | Set `false` to disable the dashboard |
| `GOACCESS_WS_URL` | *(empty)* | **Match your deployment URL** — e.g. `ws://localhost:8080/goaccess/ws` locally or `wss://yourdomain.com/goaccess/ws` behind HTTPS |
| `GOACCESS_AUTH_ENABLED` | `false` | `true` gates `/goaccess` behind HTTP Basic auth |
| `GOACCESS_USERNAME` / `GOACCESS_PASSWORD` | `admin` / — | Basic auth credentials when auth is enabled |

### Optional services

| Variable | Default | Purpose |
|---|---|---|
| `TTYD_ENABLED` | `false` | `true` enables the `/ttyd` web terminal |
| `TTYD_USERNAME` / `TTYD_PASSWORD` | `admin` / — | Required when ttyd is on |
| `INSTALL_PACKAGES` | *(empty)* | Space-separated apk packages installed at init (e.g. `mc tig ncdu`) |
| `INSTALL_PIP_PACKAGES` | *(empty)* | Space-separated pip packages installed at init |

### AI sidecar overlay

| Variable | Default | Purpose |
|---|---|---|
| `POSTGRES_USER` | `ransynsrv` | Postgres superuser for the app DB |
| `POSTGRES_PASSWORD` | — | **Required** when the overlay is active |
| `POSTGRES_DB` | `ransynsrv` | Initial database |
| `POSTGRES_HOST_PORT` | `5432` | Host port (bound to `127.0.0.1` by default) |
| `POSTGRES_BIND_ADDR` | `127.0.0.1` | Set to `0.0.0.0` to expose Postgres on all interfaces |
| `POSTGRES_MEM_LIMIT` | `1g` | Container memory cap |
| `EMBEDDER_MODEL` | `BAAI/bge-small-en-v1.5` | HuggingFace model id served by TEI |
| `EMBEDDER_HOST_PORT` | `7997` | Host port for direct embedder access |
| `EMBEDDER_BIND_ADDR` | `127.0.0.1` | Set to `0.0.0.0` to expose the embedder |
| `EMBEDDER_MEM_LIMIT` | `2g` | Container memory cap (BGE-small ~500MB, BGE-M3 ~4GB — size accordingly) |

Full reference: [`.env.example`](.env.example).

---

## 🏗️ Architecture

```
╔══════════════════════════════ ransynsrv container ═══════════════════════════════╗
║                                                                                  ║
║                       ┌──[ s6-overlay v3 supervisor ]──┐                         ║
║                       └──┬────┬────┬────┬──────────────┘                         ║
║                          │    │    │    │                                        ║
║     ┌── init-ransynsrv ──┘    │    │    └── svc-ttyd ── lo:7681                  ║
║     │  (oneshot, blocks)      │    │        (no -c; auth at nginx layer)         ║
║     │                         │    │                                             ║
║     │  first-boot once:       │    └── svc-php-fpm ── /run/php/php-fpm.sock     ║
║     │  • mkdir /data tree     │        pool: abc   clear_env=no                  ║
║     │  • install defaults     │        99-ransynsrv.ini regen from PHP_* env     ║
║     │  • PUID/PGID chown -R   │                                                  ║
║     │    → sentinel .init-done│    ┌── svc-nginx ── :80                          ║
║     │                         └────┤   workers: nginx                            ║
║     │  every boot:                 │   proxies /health  /goaccess  /ttyd         ║
║     │  • INSTALL_PACKAGES (apk)    │   nginx Basic-auth on /goaccess + /ttyd     ║
║     │  • regen php-timeout.conf   ─┘                                             ║
║     │  • rewrite GOACCESS_AUTH                                                   ║
║     │    + TTYD_AUTH blocks        ┌── svc-goaccess ── :7890 (internal WS)       ║
║     │    in nginx.conf             │   reads access.log → writes index.html      ║
║     │  • bcrypt htpasswd → ────────┘                                             ║
║     │    /data/nginx/.{goaccess,ttyd}-htpasswd                                   ║
║     │  • DOCKER_LOGS=true → symlink logs to /proc/1/fd/{1,2}                     ║
║     └──────────────────┘                                                         ║
║                                                                                  ║
║     ┌──────────────────── /data volume (bind-mount) ───────────────────┐         ║
║     │  webroot/{public_html, src}          claude/.claude/             │         ║
║     │  nginx/nginx.conf   (user-editable)  commandhistory/             │         ║
║     │  nginx/.{goaccess,ttyd}-htpasswd     ssh/            (0700)      │         ║
║     │  nginx/php-timeout.conf              log/{nginx,php} (0640)      │         ║
║     │  databases/                          .ransynsrv-init-done        │         ║
║     └──────────────────────────────────────────────────────────────────┘         ║
╚══════════════════════════════════════════════════════════════════════════════════╝

      ▲ http://host:8080       ◆ /health     ◆ /goaccess    ◆ /ttyd
      │
 ┌── optional AI sidecar overlay — docker-compose.ai.yml ──────────────────────┐
 │                                                                             │
 │  ai-init ── oneshot ── chowns ./data/{postgres,tei-cache} to PUID:PGID      │
 │      │                                                                      │
 │      ├─► postgres    pgvector/pgvector:0.8.0-pg17    dns: postgres         │
 │      │               127.0.0.1:${POSTGRES_HOST_PORT:-5432}:5432             │
 │      │               runs as ${PUID}:${PGID} — host-readable PGDATA         │
 │      │                                                                      │
 │      └─► embedder    HF TEI cpu-1.5 / ${EMBEDDER_MODEL}    dns: embedder   │
 │                      127.0.0.1:${EMBEDDER_HOST_PORT:-7997}:80               │
 └─────────────────────────────────────────────────────────────────────────────┘
```

| Layer | Process | User | Port |
|---|---|---|---|
| Init (oneshot) | `init-ransynsrv` | root | — |
| Web server | `nginx` master | root | 80 |
| Web server | `nginx` workers | `nginx` | — |
| Application | `php-fpm` master | root | — |
| Application | `php-fpm` pool | `abc` | unix socket |
| Analytics | `goaccess` | root | 7890 (internal) |
| Terminal | `ttyd` | `abc` | 7681 (loopback) |

Services are defined under [`root/etc/s6-overlay/s6-rc.d/`](root/etc/s6-overlay/s6-rc.d/). All longruns `depends_on` the init oneshot so services never race ahead of first-boot setup.

---

## 🤖 AI Sidecar Overlay

Optional compose overlay that adds a semantic-search-ready stack alongside ransynsrv:

| Service | Image | Exposed on host |
|---|---|---|
| `postgres` | `pgvector/pgvector:0.8.0-pg17` | `127.0.0.1:${POSTGRES_HOST_PORT:-5432}` |
| `embedder` | `ghcr.io/huggingface/text-embeddings-inference:cpu-1.5` | `127.0.0.1:${EMBEDDER_HOST_PORT:-7997}` |
| `ai-init` | `alpine:3.21` *(oneshot)* | — (fixes bind-mount ownership) |

The services share the compose network, so PHP apps inside ransynsrv reach them via DNS: `postgres:5432` and `embedder:80`. Bind-mounted data lands under `${DATA_PATH}/postgres` and `${DATA_PATH}/tei-cache`, pre-chowned to your host UID/GID so backup scripts don't need `sudo`.

### Sample RAG query from PHP

```php
// 1. Embed a query via the internal embedder
$resp = file_get_contents('http://embedder/embed', false, stream_context_create([
    'http' => [
        'method'  => 'POST',
        'header'  => 'Content-Type: application/json',
        'content' => json_encode(['inputs' => $query]),
    ],
]));
$embedding = json_decode($resp, true);

// 2. Similarity search over documents
$pdo = new PDO(
    'pgsql:host=postgres;dbname=' . getenv('POSTGRES_DB'),
    getenv('POSTGRES_USER'),
    getenv('POSTGRES_PASSWORD')
);
$stmt = $pdo->prepare(
    'SELECT id, title FROM documents ORDER BY embedding <=> :q::vector LIMIT 5'
);
$stmt->execute([':q' => '[' . implode(',', $embedding) . ']']);
```

Full usage, model swap procedure, backup recipes and permissions notes: **[CLAUDE.md § AI Sidecar Overlay](CLAUDE.md#ai-sidecar-overlay-docker-composeaiyml)**.

---

## 🔒 Security

- **Workers run unprivileged.** PHP-FPM pool is `abc:abc`, nginx workers are `nginx`, ttyd is `abc`. Only the supervisor chain (s6, master processes) is root.
- **`no-new-privileges:true`** on every compose service — blocks post-init sudo / setuid escalation.
- **Sidecar host ports bound to `127.0.0.1`** by default. Flip `*_BIND_ADDR=0.0.0.0` if you need them on the network.
- **GoAccess + ttyd Basic auth at the nginx layer** — htpasswd files are generated from env at boot (bcrypt hash at rest). Credentials never land in service argv, so a compromised same-UID process can't read them from `/proc`.
- **`EXPOSE` is only port 80** — internal services (GoAccess WebSocket, ttyd) aren't advertised, so `docker run -P` can't publish them by accident.
- **Image-level ownership** of service scripts: runtime `abc` can't overwrite `/etc/s6-overlay/s6-rc.d/*/run` (closes the common PHP-RCE → root path).
- **Atomic config edits** — init writes nginx.conf edits through a `.tmp` file + rename so a crashed init can't leave nginx syntactically broken.
- **`Server:` response header stripped** (`more_clear_headers Server`) — no nginx fingerprint for scanners.
- **Editor-backup + database extensions denied at nginx** (`.bak`, `.swp`, `.sql`, `.db`, `.sqlite`, `.env`, etc.) — an accidentally-dropped `config.env` or `app.db` in `public_html` returns 404 instead of leaking.
- **Log files mode 0640**, SSH keys enforced to 0600, sentinel-guarded boot means a fresh deploy runs init once, not on every restart.

TLS stays at your reverse proxy. HSTS, rate limits, and WAF rules belong there.

---

## 🧰 Inside the container

<details>
<summary><b>PHP 8.4 extensions</b></summary>

```
bcmath   bz2       calendar  ctype    curl      dom       exif     fileinfo
ftp      gd        gettext   gmp      iconv     imap      intl     ldap
mbstring mysqli    mysqlnd   opcache  openssl   pcntl     pdo      pdo_mysql
pdo_pgsql pdo_sqlite pgsql     phar    posix     session   simplexml soap
sockets  sodium    sqlite3   tokenizer xml      xmlreader xmlwriter xsl
zip      zlib      apcu      igbinary  redis
```

Redis + APCu + igbinary included by default.
</details>

<details>
<summary><b>Dev toolchain</b></summary>

Shell: zsh + Oh-My-Zsh + Powerlevel10k (wizard auto-disabled).
Plugins: git, docker, docker-compose, node, npm, fzf, rsync, sudo, zsh-autosuggestions, zsh-syntax-highlighting, zsh-completions.

Tools: `git`, `git-delta`, `github-cli`, `fzf`, `ripgrep`, `rsync`, `rclone`, `jq`, `yq`, `mariadb-client`, `postgresql-client`, `redis-cli`, `ffmpeg`, `imagemagick`, `graphicsmagick`, `sqlite`, `ttyd`.

Languages: PHP 8.4, Python 3 (+pip, cryptography, requests, yaml, jinja2), Node via system + NVM (`nvm install`, `nvm use`).
</details>

<details>
<summary><b>Nginx modules</b></summary>

Brotli, headers-more, fancyindex, image-filter. All loaded via `/etc/nginx/modules/*.conf`.
</details>

---

## 🏃 Common tasks

```bash
# Shell into the container
docker exec -it ransynsrv zsh

# Tail logs
docker logs -f ransynsrv
docker exec ransynsrv tail -f /data/log/nginx/error.log

# Reload nginx after editing /data/nginx/nginx.conf
docker exec ransynsrv nginx -t && docker exec ransynsrv nginx -s reload

# Install a package at runtime (persists because INSTALL_PACKAGES re-runs on boot)
echo 'INSTALL_PACKAGES="mc ncdu"' >> .env
docker compose restart ransynsrv

# Back up the /data volume
tar -czf ransynsrv-$(date +%Y%m%d).tar.gz ./data

# Back up Postgres (AI sidecar)
docker exec ransynsrv-postgres pg_dump -U ransynsrv -Fc ransynsrv \
  > backups/db-$(date +%Y%m%d).dump
```

More scenarios: **[CLAUDE.md § Common Development Workflows](CLAUDE.md#common-development-workflows)**.

---

## 🐛 Troubleshooting

The in-repo troubleshooting guide covers the usual culprits — permission issues, nginx config errors, PHP-FPM not starting, GoAccess empty dashboard, `sudo` under `no-new-privileges`, `DOCKER_LOGS=true` + GoAccess interaction.

**[→ Full troubleshooting in CLAUDE.md](CLAUDE.md#troubleshooting)**

---

## 🗂️ Directory layout

```
ransynsrv/
├── Dockerfile
├── docker-compose.yml          # local dev (build from source)
├── docker-compose.deploy.yml   # pull from GHCR
├── docker-compose.ai.yml       # optional AI sidecar overlay
├── .env.example
├── root/                       # files copied into the image
│   ├── etc/
│   │   ├── nginx/nginx.conf    # image-level default (fixes first-boot race)
│   │   └── s6-overlay/s6-rc.d/{init-ransynsrv,svc-*}
│   └── defaults/               # user-overridable templates
│       ├── nginx/nginx.conf
│       ├── CLAUDE.md           # seed Claude Code with container-aware context
│       └── webroot/…
├── data/                       # created at runtime, your persistent volume
│   ├── webroot/public_html/    # your PHP app root
│   ├── webroot/src/            # your PHP library tree
│   ├── nginx/nginx.conf        # user-editable (symlinked to /etc/nginx)
│   ├── databases/              # SQLite files
│   ├── log/                    # nginx + php logs
│   ├── claude/.claude/         # Claude Code config
│   ├── ssh/                    # SSH keys (0700)
│   └── commandhistory/         # zsh/bash history
├── README.md                   # you are here
├── CLAUDE.md                   # deep architecture + ops reference
└── changelog.md
```

---

## 🤝 Contributing

PRs welcome — especially for new s6-overlay modules, PHP/Alpine extension requests, or sidecar-overlay compose files (e.g. ollama, redis, opensearch).

Please run `docker compose config` against any compose-file changes, and rebuild locally before pushing (`docker build -t ransynsrv:test .`).

---

## 📝 License

MIT — see [LICENSE](LICENSE).

---

<div align="center">

**Built with s6-overlay, PHP, Postgres, and too much coffee.**

If this saved you a weekend of container plumbing, ⭐ the repo.

</div>
