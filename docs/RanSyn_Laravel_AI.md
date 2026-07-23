# RanSyn + Laravel AI Stack

Private reference for Randolph's self-hosted platform. Two complementary pieces, documented together because they share conventions (GHCR namespace, `/docker/appdata` layout, Claude Max Proxy gateway, Langfuse tracing):

- **RanSynSrv** — general-purpose PHP hosting container. Alpine + Nginx + PHP-FPM 8.4 + Claude Code CLI + GoAccess analytics + ttyd web terminal. Good for admin tools, experiments, static-plus-PHP sites.
- **Laravel AI Stack** — production template for Laravel Octane apps with AI. FrankenPHP + Laravel 13 + Laravel AI SDK (`laravel/ai`) + Postgres/pgvector + Redis + Reverb + Claude Max Proxy + TEI/BGE embeddings + Langfuse. Good for OSINT dashboards, internal tools, content platforms, small-team SaaS.

Source specs consolidated here: `README.md` (RanSynSrv root) and `docs/laravel-ai-stack.md` (Laravel AI stack detail).

---

# Part 1 — RanSynSrv Hosting Container

> Production-ready PHP 8.4 hosting on Alpine Linux. Nginx, real-time analytics, Claude Code CLI, web terminal. Runs behind a reverse proxy (no SSL in-container).

## 1.1 Component versions

| Component | Version | Role |
|---|---|---|
| Alpine Linux | 3.21 | Base OS |
| Nginx | latest | Web server (Brotli, headers-more, fancyindex, image-filter) |
| PHP | 8.4 | 45+ extensions |
| PHP-FPM | 8.4 | FastCGI via `/run/php/php-fpm.sock` |
| GoAccess | 1.9.4 | Real-time analytics (MMDB GeoIP) |
| s6-overlay | 3.2.0.3 | Process supervision |
| Claude Code | 2.1.12 | AI CLI (Alpine musl build) |
| NVM | 0.40.3 | Node version switching |
| git-delta | 0.18.2 | Diff rendering |

**Image:** `ghcr.io/randomsynergy17/ransynsrv:latest` — amd64 + arm64.

## 1.2 Quick start (GHCR)

```bash
mkdir ransynsrv && cd ransynsrv
curl -LO https://raw.githubusercontent.com/RandomSynergy17/RanSynSrv/main/docker-compose.deploy.yml
curl -LO https://raw.githubusercontent.com/RandomSynergy17/RanSynSrv/main/.env.example
cp .env.example .env
# edit .env — set PUID/PGID (id $USER), TZ, HTTP_PORT, ANTHROPIC_API_KEY
docker compose -f docker-compose.deploy.yml up -d
open http://localhost:8080
```

## 1.3 Essential env vars

| Var | Default | Notes |
|---|---|---|
| `PUID` / `PGID` | 1000 | Match host user — `id $USER` |
| `TZ` | Asia/Dubai | IANA timezone |
| `HTTP_PORT` | 8080 | Host port bound |
| `DATA_PATH` | `./data` | Persistent data root |
| `ANTHROPIC_API_KEY` | — | Required for Claude Code CLI |
| `GOACCESS_WS_URL` | `ws://localhost:8080/goaccess/ws` | Must match browser's access scheme/host/port |
| `GOACCESS_AUTH_ENABLED` / `_USERNAME` / `_PASSWORD` | false / admin / — | Basic auth on `/goaccess` |
| `TTYD_ENABLED` / `_USERNAME` / `_PASSWORD` | false / admin / — | Enables `/ttyd` web shell |
| `DOCKER_LOGS` | false | `true` → logs to Docker stdout (Loki/ELK) |
| `INSTALL_PACKAGES` | — | Space-separated apk packages installed at startup |
| `INSTALL_PIP_PACKAGES` | — | Space-separated pip packages installed at startup |
| `PHP_MEMORY_LIMIT` | 256M | |
| `PHP_MAX_UPLOAD` | 50M | Keep `PHP_MAX_POST` ≥ this |
| `PHP_MAX_POST` | 50M | |
| `PHP_MAX_EXECUTION_TIME` | 300 | seconds |

## 1.4 Directory layout

All persistent data under one mount (`./data` → `/data`). Auto-created on first launch, owned by `abc:abc` (mapped to PUID:PGID).

```
data/
├── nginx/nginx.conf         symlinked → /etc/nginx/nginx.conf (editable)
├── webroot/
│   ├── public_html/         Nginx root, PHP served here
│   └── goaccess/            Dashboard HTML (auto-regenerated)
├── databases/               SQLite files
├── log/
│   ├── nginx/{access,error}.log
│   └── php/error.log
├── claude/.claude/          Claude Code config (API keys, history)
├── commandhistory/          .bash_history / .zsh_history
├── ssh/                     700 perms
├── scripts/                 Your automation
└── crontabs/                Cron jobs for abc user
```

## 1.5 Services & endpoints

| Path | Purpose |
|---|---|
| `/` | PHP app root (`/data/webroot/public_html/`) |
| `/goaccess` | Real-time analytics dashboard |
| `/goaccess/ws` | WebSocket proxy (port 7890 internal) |
| `/ttyd` | Web terminal (port 7681 internal, requires `TTYD_ENABLED=true`) |
| `/health` | 200 OK, no logging — for LB healthchecks |

## 1.6 Core features

**Claude Code CLI** — `docker exec -it ransynsrv zsh` → `claude --help`. Config persists in `/data/claude/.claude`. `cc` is alias.

**GoAccess** — dashboard at `/goaccess`, updates in real time via WebSocket. Requires `GOACCESS_WS_URL` to match browser's access method. Disable with `GOACCESS_ENABLED=false`.

**ttyd web terminal** — browser shell at `/ttyd`, HTTP Basic Auth. Disabled by default — enable with `TTYD_ENABLED=true` + set user/pass. Binds 127.0.0.1 only; Nginx proxies.

**NVM** — installed at `/usr/local/share/nvm`. `nvm install 20 && nvm use 20`. System Node (Alpine) remains as fallback.

**Runtime packages** — `INSTALL_PACKAGES=mc tig ncdu` or `INSTALL_PIP_PACKAGES=pandas numpy` install at container init, before services start. No image rebuild needed. Doesn't persist across rebuilds.

**Docker logging** — `DOCKER_LOGS=true` symlinks logs to `/proc/1/fd/{1,2}`, so `docker compose logs -f` captures Nginx + PHP. Use with Loki/ELK.

## 1.7 Shell environment

Zsh + Oh-My-Zsh + Powerlevel10k. Auto-suggestions, syntax highlighting, 50k history. FZF integrated (Ctrl+R).

Aliases: `ll`, `cc` (claude), `nginx-test`, `nginx-reload`, `logs`, `errors`, `phplogs`.

## 1.8 Package categories (200+ total)

- **Nginx modules**: brotli, headers-more, fancyindex, image-filter
- **PHP 8.4 extensions**: 45+ incl. pdo_{pgsql,mysql,sqlite}, pecl-redis, pecl-apcu, sodium, intl, gd, imap, ldap, soap, opcache
- **Databases**: sqlite, mariadb-client, postgresql-client, redis-cli, leveldb
- **Dev tools**: git, git-lfs, github-cli, git-delta, fzf, ripgrep, rsync, rclone, openssh-client, ffmpeg, imagemagick (≥7.1.1.13-r0 — CVE-2025-68469 patched), graphicsmagick
- **Network**: bind-tools, iputils, iproute2, iptables, openssl, httpie
- **Python 3**: pip, setuptools, wheel, virtualenv, requests, yaml, jinja2, cryptography + pip: plyvel, python-snappy, ccl_chromium_reader, httpie, glances

## 1.9 Security posture

- User `abc` runs all services — no root
- Sudo restricted to `nginx -t` only
- `/data/ssh/` is 700
- Real-IP trust disabled by default — configure `set_real_ip_from` only for your specific proxy IP
- SHA256-verified installs for NVM and s6-overlay
- `INSTALL_PACKAGES` inputs sanitized

## 1.10 Troubleshooting quick reference

```bash
# Permission issues
id $USER && sudo chown -R 1000:1000 data/

# Nginx
docker exec ransynsrv nginx -t && docker exec ransynsrv nginx -s reload
docker exec ransynsrv tail -50 /data/log/nginx/error.log

# PHP-FPM
docker exec ransynsrv ps aux | grep php-fpm
docker exec ransynsrv ls -la /run/php/php-fpm.sock   # srw-rw---- abc abc

# Claude Code
docker exec ransynsrv env | grep ANTHROPIC
docker exec ransynsrv claude --version

# GoAccess empty / WebSocket failing
curl http://localhost:8080                  # generate traffic
# Then fix GOACCESS_WS_URL to match browser access (ws vs wss, host, port)

# Container won't start
sudo lsof -i :8080                          # port in use?
docker logs ransynsrv                       # read errors
```

---

# Part 2 — Laravel AI Stack

Blade-first, server-rendered, AI-native. Reusable template for new Laravel projects.

- **Base image:** `ghcr.io/randomsynergy17/frankenphp-laravel:latest`
- **Per-project image:** `ghcr.io/randomsynergy17/{project}:latest`
- **Data root on darktower:** `/docker/appdata/{project-slug}/{postgres,redis,tei-models,scripts}`
- **LLM gateway (shared, single instance):** [claudeMax-OpenAI-HTTP-Proxy](https://github.com/RandomSynergy17/claudeMax-OpenAI-HTTP-Proxy) at `127.0.0.1:4000` — FastAPI proxy exposing `/openai/v1/*` and `/anthropic/v1/*`, backed by Claude Code CLI + Claude Max subscription (no per-token API spend)
- **Log aggregation:** Loki on darktower
- **LLM traces:** Langfuse on darktower

## 2.1 TL;DR

| # | Layer | Pick | Role |
|--:|---|---|---|
| 1 | Runtime | FrankenPHP + Laravel Octane | Worker mode, HTTP/2+3, single binary |
| 2 | Language | PHP 8.4 | JIT, property hooks, asymm. visibility |
| 3 | Framework | Laravel 13 | |
| 4 | Database | Postgres 16 (`pgvector/pgvector:pg16`) | Relational + vector in one engine |
| 5 | Vector | pgvector HNSW, 384-dim, cosine | |
| 6 | Cache / queue / session | Redis 7-alpine | Also Octane table cache |
| 7 | Realtime | Laravel Reverb | First-party WebSockets |
| 8 | Auth | Laravel Sanctum | Session cookies + API tokens |
| 9 | Mail | Resend | `noreply-{project}@randomsynergy.xyz` |
| 10 | Templating | Blade | |
| 11 | Components | OAT UI (CDN) | Tailwind components |
| 12 | Interactivity | Alpine.js (CDN) | Small reactive state |
| 13 | Reactive escape hatch | Livewire 3 + Volt | When Alpine hits ceiling |
| 14 | Icons | Blade Icons (Heroicons) | Compile-time, no JS |
| 15 | Build step | None | Add Vite later if truly needed |
| 16 | AI SDK | **Laravel AI SDK** (`laravel/ai`) | Agents, tools, streaming, structured output, native pgvector, conversation memory |
| 17 | LLM | Claude Sonnet 4.6 via Claude Max Proxy | `claude-sonnet-4-6` at `:4000/anthropic/v1` |
| 18 | Embeddings | BGE-small-en-v1.5 via TEI (manual HTTP — SDK has no TEI driver) | 384-dim, 512 ctx, MIT, ~130 MB |
| 19 | Observability | Langfuse (hooked via SDK events) | LLM traces, prompts, costs |
| 20 | Logging | Monolog (Laravel default) → stderr → Loki | Structured app logs |
| 21 | Orchestration | Docker Compose, host networking | |
| 22 | Deploy | Portainer stacks from GHCR | |

## 2.2 Topology

```
Browser
   │ HTTP/2+3, WebSocket
   ▼
FrankenPHP + Octane (19xxx) ──────┐
   │ Blade render                  │
   │ Livewire / Alpine AJAX ───────┤
   │                               │
   ├── Redis (63xx)        cache / queue / session
   ├── Postgres (54xx)     relational + pgvector
   ├── Reverb (80xx)       WebSocket broadcast
   ├── TEI (81xx)          BGE embeddings → 384-dim
   └── Claude Max Proxy (4000) ──── claude -p CLI ──► Claude Sonnet 4.6
       /anthropic/v1/*              (Max subscription)
       /openai/v1/*

   Langfuse traces emitted from Laravel via langfuse-php SDK
```

## 2.3 Runtime layer

- **FrankenPHP + Octane** in worker mode. HTTP/2 and HTTP/3 out of the box, static files served by the same binary, no separate web server.
  - **Why FrankenPHP over php-fpm:** single process, Octane worker mode without bolting on a front server, HTTP/3 free, `OCTANE_SERVER=frankenphp` already baked into the base image's `ENV`.
- **PHP 8.4** with JIT, property hooks, asymmetric visibility — used in models/DTOs where it pays off.
- **Laravel 13.x** — current line as of 2026. Required for native Laravel AI SDK support (`Schema::vector()`, `whereVectorSimilarTo()`, agent classes) — the 12.x SDK has the same surface but we standardize on 13 going forward to stay aligned with the framework's AI roadmap.

**Critical env:** `OCTANE_SERVER=frankenphp` (already set in the base image — do NOT redeclare in project `.env`). Tune `OCTANE_WORKERS` to host CPU (`--workers=auto` usually fine).

## 2.4 Data layer

- **Postgres 16** using the `pgvector/pgvector:pg16` image — the extension is pre-installed; Laravel AI SDK's `Schema::ensureVectorExtensionExists()` handles `CREATE EXTENSION vector;` automatically. Use `$table->vector('embedding', dimensions: 384)` + `$table->index()` in migrations — the SDK generates the HNSW index with cosine distance by default.
  - **Why Postgres + pgvector over a dedicated vector DB (Qdrant, Weaviate, Pinecone):** one engine, one backup strategy, transactional joins between relational rows and embeddings, HNSW is production-ready, Laravel AI SDK has **native query builder support** (`whereVectorSimilarTo()`, `orderByVectorDistance()`, `selectVectorDistance()`) — no extra package needed.
  - **Why HNSW over IVFFlat:** better recall at comparable speed; no training step on index build. SDK picks HNSW by default when you call `$table->index()`.
  - **Why 384-dim:** matches BGE-small output; keeps index memory small (~1.5 KB/row × rowcount).
- **Redis 7-alpine** — single instance per project, backs cache + queue + session + Octane table cache.
  - **Why Redis over DynamoDB/Memcached:** Laravel first-class support across all four roles, and Horizon needs it.

## 2.5 Frontend layer

Blade-first, zero-build. Priority: ship fast, iterate server-side, no Vite unless forced.

| Layer | Tech | Role |
|---|---|---|
| Templating | Blade | Server-rendered HTML |
| Routing (optional) | Laravel Folio | File-based Blade page routing |
| Component library | OAT UI (CDN) | Polished Tailwind components |
| Micro-interactivity | Alpine.js (CDN) | Dropdowns, modals, toggles |
| Reactive escape hatch | Livewire 3 + Volt | When Alpine hits its ceiling |
| Partial updates | Alpine AJAX or HTMX (optional) | Server-fragment swaps |
| Icons | Blade Icons (Heroicons) | Compile-time, no runtime JS |
| Build step | **None (CDN-only)** | Add Vite later only if necessary |

- **Why Blade + Alpine + Livewire over Inertia+Vue:** no Vite build, no hydration step, SSR by default, faster change-to-browser loop. Sanctum session cookies work without CORS dances.
- **Ceiling:** if a page needs heavy SPA-like client state (drag-and-drop canvases, complex forms with deep local state, offline), swap to Inertia+Vue or React — and accept the Vite build.
- **When to reach for Livewire vs stay in Alpine:** stay in Alpine for anything that fits in ~50 lines of `x-data`. Move to Livewire when you need server state changes to re-render fragments, or when two Alpine components need to talk across the DOM.

## 2.6 AI layer

The AI layer is a three-tier stack: Laravel AI SDK as the application-level abstraction, Claude Max Proxy as the local LLM gateway, and TEI as the embeddings sidecar.

| Piece | Pick | Role |
|---|---|---|
| **AI SDK** | [Laravel AI SDK](https://laravel.com/docs/13.x/ai-sdk) (`laravel/ai`) | Agent classes, tools, streaming, structured output, native pgvector query builder, conversation memory |
| LLM | Claude Sonnet 4.6 | `claude-sonnet-4-6` at `127.0.0.1:4000/anthropic/v1` (or `/openai/v1`) |
| LLM gateway | **[claudeMax-OpenAI-HTTP-Proxy](https://github.com/RandomSynergy17/claudeMax-OpenAI-HTTP-Proxy)** | FastAPI proxy, single shared instance on `:4000`, backed by Claude Code CLI + Max subscription |
| Available models | `claude-opus-4-6`, `claude-sonnet-4-6`, `claude-haiku-4-5` | Also accepts OpenAI aliases (`gpt-4o`, `gpt-4`, `o1`, etc.) that route to Claude tiers |
| Embeddings model | BGE-small-en-v1.5 (BAAI) | 384-dim, 512 ctx, MIT, ~130 MB |
| Embeddings runtime | HuggingFace TEI | Sidecar container on `81xx`. Called via manual HTTP — SDK's embedding providers (OpenAI, Cohere, Voyage, Jina, Mistral, Gemini, Azure) don't include TEI or Ollama. |
| Tracing | Langfuse | Wired via SDK event listeners (`AgentPrompted`, `ToolInvoked`, `EmbeddingsGenerated`, etc.) |

**Model ID check:** Claude model strings change. As of 2026-04, `claude-sonnet-4-6` is current. Verify against the latest Anthropic docs (or this assistant's system context) before each new project — don't copy-paste blindly from older projects.

### Why this three-tier arrangement

- **Why Laravel AI SDK over hand-rolling HTTP clients + `pgvector/pgvector-php`:** first-party Laravel, agent abstraction with conversation memory + tools + structured output out of the box, native `Schema::vector()` and `whereVectorSimilarTo()` query builder, testable via `SalesCoach::fake()` + assertion helpers, streaming via SSE (optionally Vercel AI SDK protocol), queued prompts via `->queue()->then()`. Replaces the custom `Llm.php` service, replaces `pgvector/pgvector-php`, replaces most RAG boilerplate.
- **Why Claude Max Proxy over direct Anthropic API / LiteLLM:** flat-fee Claude Max subscription (no per-token billing), zero API spend, local (no egress for LLM traffic), drop-in OpenAI *and* Anthropic API compatibility on one port, no external auth to manage — subscription auth handled by the `claude` CLI. SDK's `ANTHROPIC_BASE_URL` points directly at the proxy; nothing else needs to change.
- **Tradeoffs accepted:** ~1–2s subprocess overhead per request (spawns `claude -p`); no per-project virtual keys — all projects share one Max pool; rate-limited by Max subscription caps (429 backpressure with `rate_limit_exceeded`); proxy ignores `temperature` / `top_p` / `max_tokens` (not forwarded by CLI); `n=1` only; no native image/audio/embedding endpoints (501 stubs).
- **Why BGE-small over nomic-embed-text / OpenAI text-embedding-3-small:** MIT license, 384-dim (smaller index), 130 MB (fits RAM easily), top-of-class on MTEB for its size, no egress cost, self-hosted. (Also: the Claude proxy has no embeddings endpoint and the SDK has no TEI driver — we'd need a bypass path regardless.)
- **Why TEI (HuggingFace Text Embeddings Inference) over sentence-transformers direct in Python:** HTTP sidecar, batching, hot-reload, identical CPU/GPU runtime so moving to Burj Hikma (future GPU node) is a compose flag not a rewrite.
- **Why Langfuse via SDK events instead of per-call wrapping:** SDK dispatches `PromptingAgent` / `AgentPrompted` / `ToolInvoked` / `EmbeddingsGenerated` / `StreamingAgent` events — a single `EventServiceProvider` listener can push all of them to Langfuse without touching agent classes. Cleaner than the old "wrap every LLM call in langfuse-php" pattern.

### Proxy deployment notes

The proxy runs as a **single shared instance on the same host as the app containers** (darktower), started via its own `install.sh` which sets up a systemd user service. It is not part of any project's `compose.yml` — projects only point `ANTHROPIC_BASE_URL` at `127.0.0.1:4000/anthropic/v1`.

Auth modes:
- **No auth (default):** `CLAUDE_PROXY_API_KEY` unset on the proxy, projects leave `ANTHROPIC_API_KEY` empty or set to any placeholder. Fine for a single-tenant home lab.
- **Shared-key auth:** set `CLAUDE_PROXY_API_KEY` on the proxy and the same value as `ANTHROPIC_API_KEY` in every project `.env`. Use when the proxy is exposed beyond localhost.

Concurrency: default `--workers 1 --max-concurrent 10`. For multi-project load, bump to `--workers 4 --max-concurrent 5` (total 20 concurrent) or tune per Max subscription limits.

Health: `curl http://127.0.0.1:4000/health` returns CLI availability + active/max concurrent counts.

### What the AI SDK replaces from the old stack

| Old piece | Replaced by | Notes |
|---|---|---|
| Hand-written `Llm.php` with `Http::post()` | Agent classes (`php artisan make:agent`) or `agent()` helper | Unified prompt/stream/queue API, testable |
| `pgvector/pgvector-php` composer package | SDK's native `Schema::vector()`, `$table->index()`, `whereVectorSimilarTo()`, `orderByVectorDistance()` | One fewer dependency |
| Manual `langfuse-php` wrappers around every LLM call | Single event listener on SDK events | Zero per-call code |
| Custom conversation-history table + loader | `RemembersConversations` trait + auto `agent_conversations` / `agent_conversation_messages` tables | Free |
| Custom RAG retrieval orchestration | `SimilaritySearch::usingModel()` tool + `FileSearch` tool (for OpenAI/Gemini vector stores) | Tool auto-invokes |

## 2.7 Auth, mail, realtime, logging

- **Sanctum** — session cookies for Blade pages, API tokens for headless.
  - **Why Sanctum over Passport:** no OAuth server needed for internal/single-domain apps, handles Blade + API out of the box.
- **Resend** for all outbound mail. API key per project. From-address standard: `noreply-{project}@randomsynergy.xyz`.
  - **Why Resend over SES/Mailgun:** first-party React-email support, simple DX, one consistent provider across projects.
- **Reverb** for WebSockets.
  - **Why Reverb over Pusher/Soketi:** first-party Laravel, no SaaS cost, unique app id/key/secret per project.
- **Monolog** — Laravel's default logger. Use a `stderr` handler so the container emits JSON lines that Docker's json-file driver picks up, which Loki then scrapes from darktower.
  - **Why Monolog over `error_log()`:** structured channels, processors, formatters; Laravel already depends on it (`illuminate/log` wraps it); Loki-friendly JSON output with one handler swap.
  - **Why stderr → Docker → Loki (vs. pushing to Loki directly from PHP):** single log pipeline shared with every other container; no PHP-side retry/buffering logic; works identically in dev (`docker logs`) and prod (Loki queries); survives app crashes.

## 2.8 Laravel packages

**Core runtime**
- `laravel/octane` — worker runtime
- `laravel/sanctum` — auth
- `laravel/reverb` — WebSockets
- `laravel/horizon` — queue dashboard
  - **Why Horizon:** needed once background jobs go past toy scale — retries, failed-job inspection, supervisor process tuning. Also backs Laravel AI SDK's `->queue()->then()` agent invocations.

**UI**
- `laravel/folio` — file-based Blade page routing (optional, great for content-heavy apps)
- `livewire/livewire` — reactive server components
- `livewire/volt` — single-file Livewire components (colocated markup + logic)
- `blade-ui-kit/blade-icons` — icon components

**AI / data**
- `laravel/ai` — **primary AI abstraction**. Agents, tools, streaming, structured output, native pgvector (`Schema::vector()` / `whereVectorSimilarTo()`), conversation memory, embedding helpers, vector-store abstractions. Replaces both a manual `Llm.php` service and `pgvector/pgvector-php`.
- ~~`pgvector/pgvector-php`~~ — **removed**. Laravel AI SDK ships native pgvector query builder methods and migration helpers; the separate composer package is redundant.
- `langfuse/langfuse-php` — trace/span emitter. Wired once via an event listener on the SDK's `AgentPrompted` / `ToolInvoked` / `EmbeddingsGenerated` events (not per-call).

**Dev / ops**
- `laravel/boost` — MCP server for Claude Code
- `laravel/pail` — real-time log tail
- `laravel/telescope` (dev only) — request/query debugging

## 2.9 Infrastructure & ops

| Concern | Convention |
|---|---|
| Orchestration | Docker Compose, host networking |
| Deployment | Portainer stacks from GHCR |
| Base image | `ghcr.io/randomsynergy17/frankenphp-laravel:latest` |
| Per-project image | `ghcr.io/randomsynergy17/{project}:latest` |
| Data root | `/docker/appdata/{project-slug}` |
| Sub-paths | `/postgres`, `/redis`, `/tei-models`, `/scripts` |
| Entrypoint | `/app/data/scripts/entrypoint.sh` |
| Logging | json-file, rotated 3–5 files, 10–50 MB |
| Restart | `unless-stopped` |
| Health | `/up` (Laravel), `pg_isready`, `redis-cli ping`, `/health` (TEI) |
| Log aggregation | Grafana Loki on darktower |
| LLM tracing | Langfuse on darktower |

**Host networking note:** every service binds to `127.0.0.1:<port>` on the host and reaches neighbors via `127.0.0.1` — no Docker network needed. Exposes naturally via a reverse proxy (Nginx Proxy Manager or Traefik) on the same host.

## 2.10 Port allocation

Pick a project index **N** (monotonically increasing across all projects). Then:

| Service | Formula | N=1 | N=2 |
|---|---|---|---|
| App (FrankenPHP) | `19000 + N*50` | 19050 | 19100 |
| PostgreSQL | `5432 + N` | 5433 | 5434 |
| Redis | `6379 + N` | 6380 | 6381 |
| Reverb | `8080 + N` | 8081 | 8082 |
| TEI embeddings | `8090 + N` | 8091 | 8092 |
| Claude Max Proxy | **4000** (shared, single instance) | 4000 | 4000 |

Keep a `ports.md` in your personal notes mapping N → project — collisions are the main failure mode.

## 2.11 Resource baseline (per project)

| Service | Memory | Notes |
|---|---|---|
| App | 1024 MB | Tune `OCTANE_WORKERS` to CPU |
| Postgres | 512 MB | Bump for large vector corpora |
| Redis | 256 MB | Cache + queue |
| TEI | 2048 MB | CPU; ~512 MB on GPU |
| **Total** | **~3.8 GB** | Comfortable on darktower |

## 2.12 Pre-deploy checklist

- [ ] `composer require laravel/ai` + `php artisan vendor:publish --provider="Laravel\Ai\AiServiceProvider"` + `php artisan migrate` (creates `agent_conversations`, `agent_conversation_messages`)
- [ ] `Schema::ensureVectorExtensionExists();` runs in your first migration (or manually: `CREATE EXTENSION vector;` in project DB)
- [ ] Generate unique Reverb app id / key / secret
- [ ] Claude Max Proxy reachable on host: `curl http://127.0.0.1:4000/health`
- [ ] If proxy auth enabled: set `ANTHROPIC_API_KEY` in project `.env` to match `CLAUDE_PROXY_API_KEY` on proxy host
- [ ] Set `EMBEDDINGS_URL` to the project's TEI sidecar (manual HTTP client — SDK doesn't drive TEI)
- [ ] Pre-pull BGE model into shared `tei-models` volume (first pull takes ~2 min)
- [ ] Confirm port block (index **N**) has no collisions
- [ ] Set Resend API key + `MAIL_FROM_ADDRESS=noreply-{project}@randomsynergy.xyz`
- [ ] Verify `ANTHROPIC_MODEL` string against proxy's supported models (`claude-opus-4-6`, `claude-sonnet-4-6`, `claude-haiku-4-5`)
- [ ] Portainer stack created, env vars set, volumes bind-mounted to `/docker/appdata/{slug}`
- [ ] Langfuse project created; public/secret keys in `.env`; event listener registered in `EventServiceProvider`
- [ ] Resend domain verified for `randomsynergy.xyz`

## 2.13 Concrete examples

### 2.13.1 `compose.yml` (new project)

```yaml
name: {project-slug}

services:
  app:
    image: ghcr.io/randomsynergy17/{project}:latest
    restart: unless-stopped
    network_mode: host
    env_file: .env
    volumes:
      - /docker/appdata/{project-slug}/scripts:/app/data/scripts:ro
      - /docker/appdata/{project-slug}/storage:/app/storage
    depends_on: [postgres, redis, tei]
    healthcheck:
      test: ["CMD", "curl", "-fsS", "http://127.0.0.1:${APP_PORT}/up"]
      interval: 15s
      timeout: 5s
      retries: 5
    logging:
      driver: json-file
      options: { max-size: "20m", max-file: "5" }

  postgres:
    image: pgvector/pgvector:pg16
    restart: unless-stopped
    network_mode: host
    command: ["postgres", "-p", "${DB_PORT}"]
    environment:
      POSTGRES_DB: ${DB_DATABASE}
      POSTGRES_USER: ${DB_USERNAME}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - /docker/appdata/{project-slug}/postgres:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USERNAME} -p ${DB_PORT}"]

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    network_mode: host
    command: ["redis-server", "--port", "${REDIS_PORT}", "--appendonly", "yes"]
    volumes:
      - /docker/appdata/{project-slug}/redis:/data
    healthcheck:
      test: ["CMD", "redis-cli", "-p", "${REDIS_PORT}", "ping"]

  tei:
    image: ghcr.io/huggingface/text-embeddings-inference:cpu-1.5
    restart: unless-stopped
    network_mode: host
    command:
      - --model-id=BAAI/bge-small-en-v1.5
      - --port=${TEI_PORT}
      - --hostname=127.0.0.1
    volumes:
      - /docker/appdata/tei-models:/data  # shared across projects
    healthcheck:
      test: ["CMD", "curl", "-fsS", "http://127.0.0.1:${TEI_PORT}/health"]
```

Reverb runs inside the `app` container via `php artisan reverb:start` (spawned by the entrypoint or a supervisor), not as a separate service.

### 2.13.2 `.env` template

```ini
# ── App ──────────────────────────────────────────────────
APP_NAME={Project}
APP_ENV=production
APP_KEY=                         # php artisan key:generate
APP_URL=https://{project}.randomsynergy.xyz
APP_PORT=19050                   # 19000 + N*50

# ── Database ─────────────────────────────────────────────
DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5433                     # 5432 + N
DB_DATABASE={project}
DB_USERNAME={project}
DB_PASSWORD=                     # openssl rand -base64 32

# ── Redis ────────────────────────────────────────────────
REDIS_HOST=127.0.0.1
REDIS_PORT=6380                  # 6379 + N
REDIS_PASSWORD=null

CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis
BROADCAST_CONNECTION=reverb

# ── Reverb ───────────────────────────────────────────────
REVERB_APP_ID=                   # uuid
REVERB_APP_KEY=                  # 32 random bytes
REVERB_APP_SECRET=               # 32 random bytes
REVERB_HOST=127.0.0.1
REVERB_PORT=8081                 # 8080 + N
REVERB_SCHEME=http

# ── AI ───────────────────────────────────────────────────
# Claude Max Proxy exposes Anthropic-compatible API on /anthropic/v1
# (and OpenAI-compatible on /openai/v1 if you prefer that SDK).
# Laravel AI SDK reads ANTHROPIC_BASE_URL / ANTHROPIC_API_KEY directly
# via config/ai.php 'providers.anthropic'.
ANTHROPIC_BASE_URL=http://127.0.0.1:4000/anthropic/v1
ANTHROPIC_API_KEY=                # empty OK when proxy has no CLAUDE_PROXY_API_KEY;
                                  # otherwise set to the proxy's shared key

# Laravel AI SDK defaults
AI_TEXT_MODEL=claude-sonnet-4-6   # or claude-opus-4-6 / claude-haiku-4-5
# AI_EMBEDDING_MODEL is unused — we bypass the SDK's embedding providers
# and hit TEI directly (no TEI driver in laravel/ai as of 13.x).

# TEI embeddings (manual HTTP client, not via Laravel AI SDK)
EMBEDDINGS_URL=http://127.0.0.1:8091   # 8090 + N
EMBEDDINGS_DIM=384

# ── Langfuse (tracing, wired via SDK event listeners) ────
LANGFUSE_HOST=https://langfuse.darktower.internal
LANGFUSE_PUBLIC_KEY=
LANGFUSE_SECRET_KEY=

# ── Mail ─────────────────────────────────────────────────
MAIL_MAILER=resend
RESEND_KEY=
MAIL_FROM_ADDRESS=noreply-{project}@randomsynergy.xyz
MAIL_FROM_NAME="${APP_NAME}"

# NOTE: do NOT set OCTANE_SERVER — baked into the base image as `frankenphp`.
```

### 2.13.3 `scripts/entrypoint.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

cd /app/data/app

# Wait for Postgres
until pg_isready -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USERNAME}" >/dev/null 2>&1; do
  echo "waiting for postgres..."; sleep 1
done

# Wait for Redis
until redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" ping | grep -q PONG; do
  echo "waiting for redis..."; sleep 1
done

# One-shot setup
php artisan migrate --force
php artisan storage:link || true

# Warm caches (worker mode requires restart to pick up new routes/config)
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan event:cache

# Reverb in background, Horizon in background, Octane in foreground (PID 1)
php artisan reverb:start --host=127.0.0.1 --port="${REVERB_PORT}" &
php artisan horizon &
exec php artisan octane:frankenphp --host=127.0.0.1 --port="${APP_PORT}" --workers=auto --max-requests=500
```

For production, run Reverb and Horizon as separate compose services or under s6-overlay instead of `&` — this sketch is the smallest-possible version.

### 2.13.4 pgvector migration (Laravel AI SDK native)

```php
// database/migrations/2026_01_01_000000_create_documents_table.php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\Schema;
use Illuminate\Database\Schema\Blueprint;

return new class extends Migration {
    public function up(): void
    {
        Schema::ensureVectorExtensionExists();   // CREATE EXTENSION IF NOT EXISTS vector

        Schema::create('documents', function (Blueprint $t) {
            $t->id();
            $t->text('content');
            $t->jsonb('metadata')->default('{}');
            $t->vector('embedding', dimensions: 384);
            $t->index();   // HNSW + cosine distance by default
            $t->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('documents');
    }
};
```

No more raw `DB::statement()` calls. `Schema::ensureVectorExtensionExists()` and `$table->vector(...)` + `$table->index()` come from `laravel/ai`.

### 2.13.5 Eloquent model + ANN query (SDK query builder)

```php
// app/Models/Document.php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Document extends Model
{
    protected $fillable = ['content', 'metadata', 'embedding'];

    protected function casts(): array
    {
        return [
            'metadata'  => 'array',
            'embedding' => 'array',   // stored as pgvector, returned as float[]
        ];
    }
}

// Retrieval — the SDK auto-generates an embedding from the string query
// using config('ai.embedding') + config('ai.providers.<default>').
// Since our embeddings come from TEI (not SDK), pass a pre-computed vector:

use App\Services\Embeddings;

$queryVector = app(Embeddings::class)->embed([$userQuery])[0];

$documents = Document::query()
    ->whereVectorSimilarTo('embedding', $queryVector, minSimilarity: 0.4)
    ->limit(10)
    ->get();

// Other SDK methods:
Document::query()
    ->select('*')
    ->selectVectorDistance('embedding', $queryVector, as: 'distance')
    ->whereVectorDistanceLessThan('embedding', $queryVector, maxDistance: 0.3)
    ->orderByVectorDistance('embedding', $queryVector)
    ->limit(10)
    ->get();
```

No more `pgvector/pgvector-php` — the query builder methods are native to `laravel/ai`.

### 2.13.6 LLM calls via Agent classes

No more hand-rolled `Llm.php`. Agents are the idiomatic unit.

```php
// config/ai.php (after vendor:publish)
return [
    'default' => env('AI_DEFAULT_PROVIDER', 'anthropic'),

    'providers' => [
        'anthropic' => [
            'driver' => 'anthropic',
            'key'    => env('ANTHROPIC_API_KEY', 'not-needed'),  // proxy-aware
            'url'    => env('ANTHROPIC_BASE_URL'),               // → Claude Max Proxy
        ],
    ],

    'text'      => env('AI_TEXT_MODEL', 'claude-sonnet-4-6'),
    // 'embedding' intentionally left at SDK default; we bypass it for TEI.
];
```

```bash
php artisan make:agent SalesCoach
# or with structured output scaffolding:
php artisan make:agent SalesCoach --structured
```

```php
// app/Ai/Agents/SalesCoach.php
namespace App\Ai\Agents;

use App\Models\User;
use Illuminate\Contracts\JsonSchema\JsonSchema;
use Illuminate\Support\Stringable;
use Laravel\Ai\Attributes\Model;
use Laravel\Ai\Attributes\Provider;
use Laravel\Ai\Attributes\Temperature;
use Laravel\Ai\Attributes\Timeout;
use Laravel\Ai\Concerns\RemembersConversations;
use Laravel\Ai\Contracts\Agent;
use Laravel\Ai\Contracts\Conversational;
use Laravel\Ai\Contracts\HasStructuredOutput;
use Laravel\Ai\Contracts\HasTools;
use Laravel\Ai\Enums\Lab;
use Laravel\Ai\Promptable;

#[Provider(Lab::Anthropic)]
#[Model('claude-sonnet-4-6')]
#[Temperature(0.7)]
#[Timeout(180)]  // ~1–2s proxy subprocess overhead + generation
class SalesCoach implements Agent, Conversational, HasTools, HasStructuredOutput
{
    use Promptable, RemembersConversations;

    public function __construct(public User $user) {}

    public function instructions(): Stringable|string
    {
        return 'You are a sales coach analyzing transcripts. '
             . 'Score 1–10 and give actionable feedback.';
    }

    public function tools(): iterable
    {
        return [new \App\Ai\Tools\RetrievePreviousTranscripts($this->user)];
    }

    public function schema(JsonSchema $schema): array
    {
        return [
            'feedback' => $schema->string()->required(),
            'score'    => $schema->integer()->min(1)->max(10)->required(),
        ];
    }
}
```

```php
// Usage
$response = (new SalesCoach($user))->prompt($transcript);
$response['score'];   // int
$response['feedback']; // string

// Continue conversation
$next = (new SalesCoach($user))
    ->continue($response->conversationId, as: $user)
    ->prompt('Expand on point 2.');
```

**Why this replaces the old `Llm.php`:** unified interface for chat / stream / queue, structured output validation, conversation memory via `RemembersConversations`, testable with `SalesCoach::fake()`, and the `Provider` + `Model` attributes make model swaps a one-line change.

**Retries on 429 from the proxy:** the SDK doesn't retry automatically. Wrap hot paths:

```php
$response = retry(3, fn() => (new SalesCoach($user))->prompt($transcript), 500);
```

### 2.13.7 TEI embedding client (manual — SDK bypass)

Laravel AI SDK's embedding providers are OpenAI / Gemini / Azure / Cohere / Mistral / Jina / VoyageAI — **none cover TEI or local models**. Keep a thin HTTP client for TEI.

```php
// app/Services/Embeddings.php
namespace App\Services;

use Illuminate\Support\Facades\Http;

class Embeddings
{
    /** @param string[] $texts  @return array<int, array<int, float>> */
    public function embed(array $texts): array
    {
        return Http::acceptJson()
            ->timeout(30)
            ->post(config('services.embeddings.url').'/embed', [
                'inputs'    => array_values($texts),
                'normalize' => true,  // unit vectors → cosine == dot product
            ])
            ->throw()
            ->json();  // -> [[0.01, -0.03, ...], ...]
    }
}
```

**Alternative:** HuggingFace TEI (≥1.2) exposes an OpenAI-compatible `/v1/embeddings` endpoint. You *could* point the SDK's `openai` provider at it:

```php
// config/ai.php
'providers' => [
    'openai' => [
        'driver' => 'openai',
        'key'    => 'not-needed',
        'url'    => env('EMBEDDINGS_URL').'/v1',
    ],
],
```

Then `Str::of($text)->toEmbeddings()` works. Skipped as the primary path because the manual client is one file, keeps the OpenAI provider slot free for real use, and avoids subtle response-shape differences between TEI's compat layer and OpenAI.

### 2.13.8 Reverb broadcast

```php
// app/Events/DocumentIndexed.php
namespace App\Events;

use App\Models\Document;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Queue\SerializesModels;

class DocumentIndexed implements ShouldBroadcast
{
    use SerializesModels;

    public function __construct(public Document $document) {}

    public function broadcastOn(): array
    {
        return [new PrivateChannel("user.{$this->document->user_id}")];
    }
}

// routes/channels.php
Broadcast::channel('user.{userId}', fn($user, int $userId) => (int) $user->id === $userId);
```

```html
<!-- Alpine + laravel-echo (CDN) -->
<script>
window.Echo.private(`user.{{ auth()->id() }}`)
    .listen('DocumentIndexed', (e) => {
        // append to UI; could drive Livewire via $wire.call('refresh')
    });
</script>
```

### 2.13.9 Horizon config stub

```php
// config/horizon.php  (snippet)
'environments' => [
    'production' => [
        'supervisor-1' => [
            'connection'  => 'redis',
            'queue'       => ['default', 'embeddings', 'llm'],
            'balance'     => 'auto',
            'processes'   => 10,
            'tries'       => 3,
            'timeout'     => 300,
        ],
    ],
],
```

### 2.13.10 Langfuse via SDK event listener

The Claude Max Proxy has no callback hook. Instead, subscribe to Laravel AI SDK events once — every agent/tool/embedding call traces automatically without touching per-agent code.

```bash
composer require langfuse/langfuse-php
```

```php
// app/Listeners/LangfuseTracer.php
namespace App\Listeners;

use Langfuse\Langfuse;
use Laravel\Ai\Events\AgentPrompted;
use Laravel\Ai\Events\EmbeddingsGenerated;
use Laravel\Ai\Events\PromptingAgent;
use Laravel\Ai\Events\ToolInvoked;

class LangfuseTracer
{
    public function __construct(protected Langfuse $langfuse) {}

    public function subscribe($events): array
    {
        return [
            PromptingAgent::class     => 'onPromptStart',
            AgentPrompted::class      => 'onPromptEnd',
            ToolInvoked::class        => 'onToolInvoked',
            EmbeddingsGenerated::class => 'onEmbeddings',
        ];
    }

    public function onPromptStart(PromptingAgent $event): void
    {
        $trace = $this->langfuse->trace([
            'name'   => class_basename($event->agent),
            'userId' => optional($event->agent->user ?? null)->id,
            'id'     => $event->promptId,
        ]);
        $trace->generation([
            'id'    => $event->promptId,
            'name'  => 'llm-call',
            'model' => $event->model,
            'input' => $event->prompt,
        ]);
    }

    public function onPromptEnd(AgentPrompted $event): void
    {
        $this->langfuse->generation($event->promptId)->end([
            'output' => $event->response->text,
            'usage'  => $event->response->usage ?? null,
        ]);
        $this->langfuse->flushAsync();
    }

    public function onToolInvoked(ToolInvoked $event): void
    {
        $this->langfuse->trace($event->promptId)->span([
            'name'   => 'tool:'.class_basename($event->tool),
            'input'  => $event->input,
            'output' => $event->output,
        ]);
    }

    public function onEmbeddings(EmbeddingsGenerated $event): void
    {
        // Only fires for SDK-driven embeddings; TEI calls are manual and traced
        // inside the Embeddings service if you want coverage there.
    }
}
```

```php
// app/Providers/EventServiceProvider.php
protected $subscribe = [
    \App\Listeners\LangfuseTracer::class,
];
```

```php
// config/services.php
'langfuse' => [
    'public_key' => env('LANGFUSE_PUBLIC_KEY'),
    'secret_key' => env('LANGFUSE_SECRET_KEY'),
    'host'       => env('LANGFUSE_HOST', 'https://langfuse.darktower.internal'),
],

// AppServiceProvider::register()
$this->app->singleton(Langfuse::class, fn() => new Langfuse(
    config('services.langfuse.public_key'),
    config('services.langfuse.secret_key'),
    config('services.langfuse.host'),
));
```

For **TEI embeddings** (which the SDK doesn't see), instrument `Embeddings::embed()` directly with a `$langfuse->span()` if you want retrieval-level traces in the same trace tree as the agent call — pass the parent `promptId` in.

### 2.13.11 Sanctum SPA auth (Blade)

```php
// Login flow — same-origin Blade app, no Vite
// 1. hit /sanctum/csrf-cookie to seed XSRF-TOKEN cookie
// 2. POST /login (standard Laravel auth)
// 3. subsequent requests carry session cookie

// config/sanctum.php
'stateful' => explode(',', env('SANCTUM_STATEFUL_DOMAINS', 'localhost,127.0.0.1,{project}.randomsynergy.xyz')),
'guard'    => ['web'],

// API-token routes (mobile / third-party)
Route::middleware('auth:sanctum')->get('/api/me', fn(Request $r) => $r->user());
```

### 2.13.12 Monolog → stderr → Loki

```php
// config/logging.php
use Monolog\Handler\StreamHandler;
use Monolog\Formatter\JsonFormatter;
use Monolog\Processor\PsrLogMessageProcessor;

return [
    'default' => env('LOG_CHANNEL', 'stderr'),

    'channels' => [
        // Primary: JSON to stderr → Docker json-file driver → Loki on darktower
        'stderr' => [
            'driver' => 'monolog',
            'level'  => env('LOG_LEVEL', 'info'),
            'handler' => StreamHandler::class,
            'handler_with' => ['stream' => 'php://stderr'],
            'formatter' => JsonFormatter::class,
            'processors' => [PsrLogMessageProcessor::class],
        ],

        // Dev fallback
        'single' => [
            'driver' => 'single',
            'path'   => storage_path('logs/laravel.log'),
            'level'  => 'debug',
        ],

        // Split stack: send errors to stderr AND to a dedicated channel if needed
        'stack' => [
            'driver' => 'stack',
            'channels' => ['stderr'],
            'ignore_exceptions' => false,
        ],
    ],
];
```

```ini
# .env
LOG_CHANNEL=stderr
LOG_LEVEL=info
```

Tagging logs with context (user id, request id, trace id for Langfuse correlation):

```php
// AppServiceProvider::boot()
Log::withContext([
    'request_id' => (string) Str::uuid(),
    'user_id'    => auth()->id(),
]);

Log::info('document.indexed', ['document_id' => $doc->id, 'embedding_dim' => 384]);
```

Promtail/Loki scrape config on darktower already pulls Docker container logs (`/var/lib/docker/containers/*/*-json.log`); no per-project setup needed beyond the stderr handler above.

### 2.13.13 Anonymous agents (one-off prompts)

For throwaway prompts that don't warrant an agent class:

```php
use function Laravel\Ai\agent;
use Illuminate\Contracts\JsonSchema\JsonSchema;

$summary = agent(
    instructions: 'Summarize the input in one sentence.',
)->prompt($longText);

// With structured output
$response = agent(
    schema: fn (JsonSchema $schema) => [
        'sentiment' => $schema->string()->enum(['positive','neutral','negative'])->required(),
        'score'     => $schema->integer()->min(-5)->max(5)->required(),
    ],
)->prompt("Analyze: {$review}");

return ['sentiment' => $response['sentiment']];
```

### 2.13.14 Streaming agent response (SSE)

```php
// routes/web.php
use App\Ai\Agents\SalesCoach;

Route::get('/coach/{user}', function (User $user) {
    return (new SalesCoach($user))->stream(request('q'));
});
```

Client-side with Alpine + EventSource:

```html
<div x-data="{ text: '' }">
  <button @click="stream()">Analyze</button>
  <pre x-text="text"></pre>
</div>

<script>
  function stream() {
    const es = new EventSource(`/coach/{{ auth()->id() }}?q=...`);
    es.onmessage = (e) => { this.text += e.data; };
  }
</script>
```

For React/Vue clients using Vercel AI SDK's `useChat`, use the Vercel data protocol:

```php
return (new SalesCoach($user))->stream($q)->usingVercelDataProtocol();
```

### 2.13.15 Queued agent prompt (background)

Pairs with Horizon. Use when prompts take long (agent loops, big tool calls) and you don't want to tie up an HTTP worker.

```php
use App\Ai\Agents\SalesCoach;
use Laravel\Ai\Responses\AgentResponse;
use Throwable;

(new SalesCoach($user))
    ->queue($request->input('transcript'))
    ->then(function (AgentResponse $response) use ($user) {
        // Runs on the queue worker
        DocumentAnalysis::create([
            'user_id'  => $user->id,
            'feedback' => $response['feedback'],
            'score'    => $response['score'],
        ]);
    })
    ->catch(function (Throwable $e) use ($user) {
        Log::error('coach.failed', ['user_id' => $user->id, 'error' => $e->getMessage()]);
    });

return back()->with('status', 'Analysis queued — refresh in a minute.');
```

### 2.13.16 RAG via SimilaritySearch tool

Replace hand-rolled retrieval logic with the SDK's `SimilaritySearch` tool. Still uses TEI for embedding generation (via a custom closure so we control the query-embedding step).

```php
// app/Ai/Agents/Librarian.php
namespace App\Ai\Agents;

use App\Models\Document;
use App\Services\Embeddings;
use Laravel\Ai\Attributes\Model;
use Laravel\Ai\Attributes\Provider;
use Laravel\Ai\Contracts\Agent;
use Laravel\Ai\Contracts\HasTools;
use Laravel\Ai\Enums\Lab;
use Laravel\Ai\Promptable;
use Laravel\Ai\Tools\SimilaritySearch;

#[Provider(Lab::Anthropic)]
#[Model('claude-sonnet-4-6')]
class Librarian implements Agent, HasTools
{
    use Promptable;

    public function instructions(): string
    {
        return 'Answer using only the retrieved documents. Cite doc IDs.';
    }

    public function tools(): iterable
    {
        return [
            new SimilaritySearch(using: function (string $query) {
                $vec = app(Embeddings::class)->embed([$query])[0];

                return Document::query()
                    ->whereVectorSimilarTo('embedding', $vec, minSimilarity: 0.4)
                    ->limit(10)
                    ->get(['id', 'title', 'content']);
            }),
        ];
    }
}

// Usage — agent auto-invokes the tool when it needs context
$answer = (new Librarian)->prompt('What did we ship in Q1?');
```

## 2.14 Base image Dockerfile

Published as `ghcr.io/randomsynergy17/frankenphp-laravel:latest`. Extensions are **baked in** — adding a new PHP extension means rebuild + repush the base image, then rebuild project images. That's the whole point — eliminates the 2+ minute first-boot extension install.

```dockerfile
# RandomSynergy17/frankenphp-laravel
# Pre-built FrankenPHP + PHP 8.4 image with all extensions for Laravel Octane projects

ARG PHP_VERSION=8.4
ARG FRANKENPHP_VERSION=1.11

FROM dunglas/frankenphp:${FRANKENPHP_VERSION}-php${PHP_VERSION}

LABEL org.opencontainers.image.source="https://github.com/RandomSynergy17/frankenphp-laravel"
LABEL org.opencontainers.image.description="FrankenPHP + PHP 8.4 with extensions for Laravel Octane"
LABEL org.opencontainers.image.licenses="MIT"

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    unzip \
    zip \
    libpq-dev \
    libzip-dev \
    libicu-dev \
    libonig-dev \
    && rm -rf /var/lib/apt/lists/*

# PHP extensions for Laravel + PostgreSQL + Redis
RUN install-php-extensions \
    pcntl \
    pdo_pgsql \
    pgsql \
    redis \
    zip \
    intl \
    mbstring \
    bcmath \
    opcache \
    exif \
    gd

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Marker so entrypoint scripts can detect extensions are baked in
RUN echo "image" > /etc/frankenphp-laravel-extensions

WORKDIR /app/data/app

ENV OCTANE_SERVER=frankenphp
```

**What's baked vs runtime:**

| | Baked into image | Runtime (per project) |
|---|---|---|
| PHP version | ✅ 8.4 | — |
| FrankenPHP | ✅ 1.11 | — |
| PHP extensions | ✅ pcntl, pdo_pgsql, pgsql, redis, zip, intl, mbstring, bcmath, opcache, exif, gd | Add new → rebuild base image |
| Composer | ✅ composer 2 | — |
| `OCTANE_SERVER` | ✅ `frankenphp` | Do NOT override |
| App code | — | Copied into project image at build |
| `.env` | — | Mounted / injected at runtime |
| Vendor dir | — | `composer install` during project image build |

## 2.15 Best used for

Blade-rendered Laravel 13 apps with AI features (RAG, agents, classification, summarization) where the stack should be:
- One Postgres as source of truth (relational + vector, via Laravel AI SDK's native query builder)
- Local embeddings (no egress cost, no external dependency)
- Flat-fee LLM access via Claude Max Proxy (no per-token billing, single shared instance)
- Realtime UI without SaaS (Reverb)
- Minimal frontend build chain (no Vite, no npm)
- Agent abstraction over raw HTTP (`laravel/ai` — conversation memory, tools, structured output, streaming, queueing built in)

Good fit: OSINT dashboards, internal tools, content platforms, product admin panels, small-team SaaS.

## 2.16 Ceiling — when to change

- **Heavy SPA interactivity** → swap Blade+Alpine for Inertia+Vue (accept the Vite build step).
- **>10k embeddings/sec sustained** → move TEI to GPU node (Burj Hikma — future dedicated GPU host, not yet live).
- **Multi-region / multi-box HA** → Portainer-on-darktower is single-host; graduate to Kamal (Rails-style deploy) or k8s.
- **Vector corpora >50M rows** → revisit pgvector limits; consider Qdrant as a side store while keeping Postgres as source of truth.
- **Strict SOC2 / compliance boundary on LLM traffic** → Claude Max Proxy sends prompts to Anthropic via the `claude` CLI under your Max subscription; verify that data handling meets the bar per project. If stricter controls are needed, swap the proxy for a direct Anthropic API integration (with DPA) or a self-hosted model — since `laravel/ai` abstracts the provider, this is a config change in `config/ai.php`, not an app rewrite.
- **Need per-project cost attribution / budgets** → Max subscription is a flat fee shared across projects. If you need per-project quotas or hard spend caps, swap the proxy for direct Anthropic API keys (SDK supports it natively) or attribute cost at the Langfuse trace level (soft visibility, not enforcement).
- **Sustained high throughput beyond Max subscription caps** → subprocess spawn + Max rate limits will bottleneck. Move to direct Anthropic API with parallel workers (via `#[Provider([Lab::Anthropic, Lab::Groq])]` failover), or host a local model that the SDK supports (Ollama).
- **Need a non-Claude model for a specific task** → add it to `config/ai.php` as another provider; agents can override per-call with `->prompt(..., provider: Lab::Gemini, model: '...')` or use failover attributes. Single SDK, no rewrite.

---

# Part 3 — How the two pieces relate

| | RanSynSrv | Laravel AI Stack |
|---|---|---|
| **Purpose** | General PHP hosting + dev box | Production Laravel + AI apps |
| **Runtime** | Nginx + PHP-FPM 8.4 | FrankenPHP + Octane (PHP 8.4) |
| **Base OS** | Alpine 3.21 | Debian (frankenphp official) |
| **Framework** | — (bring your own) | Laravel 13 |
| **AI framework** | — | Laravel AI SDK (`laravel/ai`) |
| **Supervisor** | s6-overlay | Compose `depends_on` + healthchecks |
| **DB** | SQLite (local, optional external) | Postgres 16 + pgvector (via SDK query builder) |
| **Cache** | None (unless you install) | Redis 7 |
| **Realtime** | — | Reverb |
| **LLM access** | Claude Code CLI (interactive, human-typed) | Laravel AI SDK → Claude Max Proxy (`:4000`) → `claude -p` (programmatic, subscription-backed) |
| **Embeddings** | — | TEI + BGE-small (manual HTTP; SDK has no TEI driver) |
| **Observability** | GoAccess (web analytics) | Langfuse (LLM traces via SDK events) |
| **App logging** | Nginx + PHP-FPM logs → file or stdout | Monolog → stderr (JSON) → Loki |
| **Terminal** | ttyd at `/ttyd` | — (use SSH or `docker exec`) |
| **Deploy target** | Anywhere | darktower (single-host Portainer) |

**Shared conventions across both:**
- GHCR namespace: `ghcr.io/randomsynergy17/{image}`
- `PUID`/`PGID` user mapping, non-root service users
- Data under a single mount root (`/data` for RanSynSrv, `/docker/appdata/{slug}` for Laravel stack)
- Behind a reverse proxy (no SSL in-container)
- Docker Compose with `restart: unless-stopped`
- `DOCKER_LOGS=true` → stdout for Loki aggregation (RanSynSrv); Laravel stack uses json-file with rotation

**Crossover scenarios:**

- **RanSynSrv hosting a small Laravel admin tool** — drop a vanilla Laravel app into `/data/webroot/public_html/`, use SQLite, no queue, no vector store. Claude Code CLI at hand for edits. No Reverb/proxy/TEI complexity.
- **Laravel AI stack app with a RanSynSrv-adjacent terminal** — run RanSynSrv alongside on the same host purely for `/ttyd` and `/goaccess` on your main Nginx log. Different port, different data volume.
- **Claude Max Proxy shared by both** — any PHP code running inside RanSynSrv can hit `http://127.0.0.1:4000/anthropic/v1` (or `/openai/v1`) exactly the same way Laravel AI stack apps do, as long as the container has host networking or the gateway is proxied in. One Max subscription, many apps.

**When to pick which:**

- **Quick, one-off PHP:** RanSynSrv. You want the dev experience, not a framework.
- **Anything production, anything AI-heavy:** Laravel AI Stack. The queue, the vector store, the tracing, the Octane worker model all matter.
- **Both together on darktower:** fine — just keep port allocations (see 2.10) straight.
