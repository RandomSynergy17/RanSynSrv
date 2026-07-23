# Randolph's Laravel AI Stack

Private reference. Blade-first, server-rendered, AI-native. Reusable template for new projects.

**Base image:** `ghcr.io/randomsynergy17/frankenphp-laravel:latest`
**Per-project image:** `ghcr.io/randomsynergy17/{project}:latest`
**Data root on darktower:** `/docker/appdata/{project-slug}/{postgres,redis,tei-models,scripts}`
**LLM gateway (shared, single instance):** [claudeMax-OpenAI-HTTP-Proxy](https://github.com/RandomSynergy17/claudeMax-OpenAI-HTTP-Proxy) at `127.0.0.1:4000` — FastAPI proxy exposing `/openai/v1/*` and `/anthropic/v1/*`, backed by Claude Code CLI + Claude Max subscription (no per-token API spend)
**Log aggregation:** Loki on darktower
**LLM traces:** Langfuse on darktower

---

## 1. TL;DR

| # | Layer | Pick | Role |
|--:|---|---|---|
| 1 | Runtime | FrankenPHP + Laravel Octane | Worker mode, HTTP/2+3, single binary |
| 2 | Language | PHP 8.4 | JIT, property hooks, asymm. visibility |
| 3 | Framework | Laravel 12 | |
| 4 | Database | Postgres 16 (`pgvector/pgvector:pg16`) | Relational + vector in one engine |
| 5 | Vector | pgvector HNSW, 384-dim, cosine | |
| 6 | Cache/queue/session | Redis 7-alpine | Also Octane table cache |
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

---

## 2. Topology

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

---

## 3. Runtime layer

- **FrankenPHP + Octane** in worker mode. HTTP/2 and HTTP/3 out of the box, static files served by the same binary, no separate web server.
  - **Why FrankenPHP over php-fpm:** single process, Octane worker mode without bolting on a front server, HTTP/3 free, `OCTANE_SERVER=frankenphp` already baked into the base image's `ENV`.
- **PHP 8.4** with JIT, property hooks, asymmetric visibility — used in models/DTOs where it pays off.
- **Laravel 12.x** — current LTS-ish line as of 2026.

**Critical env:** `OCTANE_SERVER=frankenphp` (already set in the base image — do NOT redeclare in project `.env`). Tune `OCTANE_WORKERS` to host CPU (`--workers=auto` usually fine).

---

## 4. Data layer

- **Postgres 16** using the `pgvector/pgvector:pg16` image — the extension is pre-installed; only `CREATE EXTENSION vector;` per DB is needed.
  - **Why Postgres + pgvector over a dedicated vector DB (Qdrant, Weaviate, Pinecone):** one engine, one backup strategy, transactional joins between relational rows and embeddings, HNSW is production-ready, no extra service to run.
  - **Why HNSW over IVFFlat:** better recall at comparable speed; no training step on index build.
  - **Why 384-dim:** matches BGE-small output; keeps index memory small (~1.5 KB/row × rowcount).
- **Redis 7-alpine** — single instance per project, backs cache + queue + session + Octane table cache.
  - **Why Redis over DynamoDB/Memcached:** Laravel first-class support across all four roles, and Horizon needs it.

---

## 5. Frontend layer

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

---

## 6. AI layer

| Piece | Pick | Endpoint / ID |
|---|---|---|
| LLM | Claude Sonnet 4.6 | `claude-sonnet-4-6` via `127.0.0.1:4000/anthropic/v1` (or `/openai/v1`) |
| LLM gateway | **[claudeMax-OpenAI-HTTP-Proxy](https://github.com/RandomSynergy17/claudeMax-OpenAI-HTTP-Proxy)** | FastAPI proxy, single shared instance on `:4000`, backed by Claude Code CLI + Max subscription |
| Available models | `claude-opus-4-6`, `claude-sonnet-4-6`, `claude-haiku-4-5` | Also accepts OpenAI aliases (`gpt-4o`, `gpt-4`, `o1`, etc.) that route to Claude tiers |
| Embeddings model | BGE-small-en-v1.5 (BAAI) | 384-dim, 512 ctx, MIT, ~130 MB |
| Embeddings runtime | HuggingFace TEI | Sidecar container on `81xx` (proxy doesn't do embeddings — Claude has no embedding model) |
| Tracing | Langfuse | Wired at Laravel layer via `langfuse-php` (proxy has no native callback) |

**Model ID check:** Claude model strings change. As of 2026-04, `claude-sonnet-4-6` is current. Verify against the latest Anthropic docs (or this assistant's system context) before each new project — don't copy-paste blindly from older projects.

- **Why Claude Max Proxy over direct Anthropic API / LiteLLM:** flat-fee Claude Max subscription (no per-token billing), zero API spend, local (no egress for LLM traffic), drop-in OpenAI *and* Anthropic API compatibility on one port, no external auth to manage — subscription auth handled by the `claude` CLI.
- **Tradeoffs accepted:** ~1–2s subprocess overhead per request (spawns `claude -p`); no per-project virtual keys — all projects share one Max pool; rate-limited by Max subscription caps (429 backpressure with `rate_limit_exceeded`); proxy ignores `temperature` / `top_p` / `max_tokens` (forwarded params not honored by CLI); `n=1` only; no native image/audio/embedding endpoints (stubs return 501).
- **Why BGE-small over nomic-embed-text / OpenAI text-embedding-3-small:** MIT license, 384-dim (smaller index), 130 MB (fits RAM easily), top-of-class on MTEB for its size, no egress cost, self-hosted. (Also: the Claude proxy has no embeddings endpoint — we'd need TEI regardless.)
- **Why TEI (HuggingFace Text Embeddings Inference) over sentence-transformers direct in Python:** HTTP sidecar, batching, hot-reload, identical CPU/GPU runtime so moving to Burj Hikma (future GPU node) is a compose flag not a rewrite.
- **Why Langfuse over Helicone / native Anthropic usage dashboard:** self-hosted, prompt registry, cost breakdown per project/user, retrieval-span tracing for RAG. Since the proxy has no callback hook, traces emit from the Laravel app using `langfuse-php` wrapping each generation.

### Proxy deployment notes

The proxy runs as a **single shared instance on the same host as the app containers** (darktower), started via its own `install.sh` which sets up a systemd user service. It is not part of any project's `compose.yml` — projects only point `ANTHROPIC_BASE_URL` at `127.0.0.1:4000/anthropic/v1`.

Auth modes:
- **No auth (default):** `CLAUDE_PROXY_API_KEY` unset on the proxy, projects leave `ANTHROPIC_API_KEY` empty or set to any placeholder. Fine for a single-tenant home lab.
- **Shared-key auth:** set `CLAUDE_PROXY_API_KEY` on the proxy and the same value as `ANTHROPIC_API_KEY` in every project `.env`. Use when the proxy is exposed beyond localhost.

Concurrency: default `--workers 1 --max-concurrent 10`. For multi-project load, bump to `--workers 4 --max-concurrent 5` (total 20 concurrent) or tune per Max subscription limits.

Health: `curl http://127.0.0.1:4000/health` returns CLI availability + active/max concurrent counts.

---

## 7. Auth, mail, realtime, logging

- **Sanctum** — session cookies for Blade pages, API tokens for headless.
  - **Why Sanctum over Passport:** no OAuth server needed for internal/single-domain apps, handles Blade + API out of the box.
- **Resend** for all outbound mail. API key per project. From-address standard: `noreply-{project}@randomsynergy.xyz`.
  - **Why Resend over SES/Mailgun:** first-party React-email support, simple DX, one consistent provider across projects.
- **Reverb** for WebSockets.
  - **Why Reverb over Pusher/Soketi:** first-party Laravel, no SaaS cost, unique app id/key/secret per project.
- **Monolog** — Laravel's default logger. Use a `stderr` handler so the container emits JSON lines that Docker's json-file driver picks up, which Loki then scrapes from darktower.
  - **Why Monolog over `error_log()`:** structured channels, processors, formatters; Laravel already depends on it (`illuminate/log` wraps it); Loki-friendly JSON output with one handler swap.
  - **Why stderr → Docker → Loki (vs. pushing to Loki directly from PHP):** single log pipeline shared with every other container; no PHP-side retry/buffering logic; works identically in dev (`docker logs`) and prod (Loki queries); survives app crashes.

---

## 8. Laravel packages

**Core runtime**
- `laravel/octane` — worker runtime
- `laravel/sanctum` — auth
- `laravel/reverb` — WebSockets
- `laravel/horizon` — queue dashboard
  - **Why Horizon:** needed once background jobs go past toy scale — retries, failed-job inspection, supervisor process tuning.

**UI**
- `laravel/folio` — file-based Blade page routing (optional, great for content-heavy apps)
- `livewire/livewire` — reactive server components
- `livewire/volt` — single-file Livewire components (colocated markup + logic)
- `blade-ui-kit/blade-icons` — icon components

**AI / data**
- `pgvector/pgvector-php` — vector column + Eloquent cast

**Dev / ops**
- `laravel/boost` — MCP server for Claude Code
- `laravel/pail` — real-time log tail
- `laravel/telescope` (dev only) — request/query debugging

---

## 9. Infrastructure & ops

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

---

## 10. Port allocation

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

---

## 11. Resource baseline (per project)

| Service | Memory | Notes |
|---|---|---|
| App | 1024 MB | Tune `OCTANE_WORKERS` to CPU |
| Postgres | 512 MB | Bump for large vector corpora |
| Redis | 256 MB | Cache + queue |
| TEI | 2048 MB | CPU; ~512 MB on GPU |
| **Total** | **~3.8 GB** | Comfortable on darktower |

---

## 12. Pre-deploy checklist

- [ ] `CREATE EXTENSION vector;` in project DB
- [ ] Generate unique Reverb app id / key / secret
- [ ] Claude Max Proxy reachable on host: `curl http://127.0.0.1:4000/health`
- [ ] If proxy auth enabled: set `ANTHROPIC_API_KEY` in project `.env` to match `CLAUDE_PROXY_API_KEY` on proxy host
- [ ] Set `EMBEDDINGS_URL` to the project's TEI sidecar
- [ ] Pre-pull BGE model into shared `tei-models` volume (first pull takes ~2 min)
- [ ] Confirm port block (index **N**) has no collisions
- [ ] Set Resend API key + `MAIL_FROM_ADDRESS=noreply-{project}@randomsynergy.xyz`
- [ ] Verify `ANTHROPIC_MODEL` string against proxy's supported models (`claude-opus-4-6`, `claude-sonnet-4-6`, `claude-haiku-4-5`)
- [ ] Portainer stack created, env vars set, volumes bind-mounted to `/docker/appdata/{slug}`
- [ ] Langfuse project created; public/secret keys in `.env` (traces emitted from Laravel, not proxy)
- [ ] Resend domain verified for `randomsynergy.xyz`

---

## 13. Concrete examples

### 13.1 `compose.yml` (new project)

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

### 13.2 `.env` template

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
# (and OpenAI-compatible on /openai/v1 if you prefer that SDK)
ANTHROPIC_BASE_URL=http://127.0.0.1:4000/anthropic/v1
ANTHROPIC_API_KEY=                # leave empty if proxy has no CLAUDE_PROXY_API_KEY;
                                  # otherwise set to the proxy's shared key
ANTHROPIC_MODEL=claude-sonnet-4-6 # or claude-opus-4-6 / claude-haiku-4-5

EMBEDDINGS_URL=http://127.0.0.1:8091   # 8090 + N
EMBEDDINGS_DIM=384

# ── Langfuse (tracing, optional but standard) ────────────
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

### 13.3 `scripts/entrypoint.sh`

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

### 13.4 pgvector migration

```php
// database/migrations/2026_01_01_000000_create_documents_table.php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Database\Schema\Blueprint;

return new class extends Migration {
    public function up(): void
    {
        DB::statement('CREATE EXTENSION IF NOT EXISTS vector');

        Schema::create('documents', function (Blueprint $t) {
            $t->id();
            $t->text('content');
            $t->jsonb('metadata')->default('{}');
            $t->timestamps();
        });

        DB::statement('ALTER TABLE documents ADD COLUMN embedding vector(384)');
        DB::statement("
            CREATE INDEX documents_embedding_hnsw
            ON documents USING hnsw (embedding vector_cosine_ops)
            WITH (m = 16, ef_construction = 64)
        ");
    }

    public function down(): void
    {
        Schema::dropIfExists('documents');
    }
};
```

### 13.5 Eloquent model + ANN query

```php
// app/Models/Document.php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Pgvector\Laravel\Vector;
use Pgvector\Laravel\HasNeighbors;

class Document extends Model
{
    use HasNeighbors;

    protected $fillable = ['content', 'metadata', 'embedding'];

    protected $casts = [
        'metadata'  => 'array',
        'embedding' => Vector::class,
    ];
}

// Retrieval
use Pgvector\Laravel\Distance;

$neighbors = Document::query()
    ->nearestNeighbors('embedding', $queryVector, Distance::Cosine)
    ->limit(10)
    ->get();
```

### 13.6 LLM call via Claude Max Proxy

The proxy accepts both Anthropic- and OpenAI-formatted requests. Below uses the Anthropic shape. The `cache_control: ephemeral` block is harmless even though Claude CLI doesn't honor prompt caching through the proxy — Anthropic SDK clients expect the shape.

```php
// app/Services/Llm.php
namespace App\Services;

use Illuminate\Support\Facades\Http;

class Llm
{
    public function chat(string $system, array $messages): string
    {
        // Proxy accepts any bearer when CLAUDE_PROXY_API_KEY is unset;
        // use 'not-needed' as a harmless placeholder.
        $token = config('services.anthropic.key') ?: 'not-needed';

        $res = Http::withToken($token)
            ->acceptJson()
            ->timeout(180)  // ~1–2s CLI spawn overhead + generation time
            ->post(config('services.anthropic.base').'/messages', [
                'model'      => config('services.anthropic.model'),
                'max_tokens' => 4096,
                'system'     => [[
                    'type' => 'text',
                    'text' => $system,
                    'cache_control' => ['type' => 'ephemeral'],
                ]],
                'messages'   => $messages,
            ])->throw()->json();

        return collect($res['content'])->firstWhere('type', 'text')['text'] ?? '';
    }
}

// config/services.php
'anthropic' => [
    'base'  => env('ANTHROPIC_BASE_URL'),   // e.g. http://127.0.0.1:4000/anthropic/v1
    'key'   => env('ANTHROPIC_API_KEY'),    // empty OK when proxy has no CLAUDE_PROXY_API_KEY
    'model' => env('ANTHROPIC_MODEL', 'claude-sonnet-4-6'),
],
```

**Retries on 429:** the proxy returns HTTP 429 (`rate_limit_exceeded`) when all concurrency slots are full. Wrap hot paths with Laravel's retry helper:

```php
$res = retry(3, fn() => Http::withToken($token)
    ->timeout(180)
    ->post(...)
    ->throw(), 500); // 500ms backoff
```

### 13.7 TEI embedding client

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
                'inputs' => array_values($texts),
                'normalize' => true,  // unit vectors → cosine == dot product
            ])
            ->throw()
            ->json();  // -> [[0.01, -0.03, ...], ...]
    }
}
```

### 13.8 Reverb broadcast

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

### 13.9 Horizon config stub

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

### 13.10 Langfuse wiring (Laravel-side)

The Claude Max Proxy has no native Langfuse callback (it's a stateless FastAPI passthrough to `claude -p`), so traces emit from the **Laravel app** using `langfuse-php`. This also lets you capture RAG retrieval spans, user-id tagging, and prompt versions — things a pure LLM-gateway callback couldn't see anyway.

```bash
composer require langfuse/langfuse-php
```

```php
// config/services.php
'langfuse' => [
    'public_key' => env('LANGFUSE_PUBLIC_KEY'),
    'secret_key' => env('LANGFUSE_SECRET_KEY'),
    'host'       => env('LANGFUSE_HOST', 'https://langfuse.darktower.internal'),
],

// app/Services/Llm.php — Llm::chat() with Langfuse wrapping
use Langfuse\Langfuse;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

class Llm
{
    public function chat(string $system, array $messages, ?string $userId = null): string
    {
        $langfuse = new Langfuse(
            config('services.langfuse.public_key'),
            config('services.langfuse.secret_key'),
            config('services.langfuse.host'),
        );

        $trace = $langfuse->trace([
            'name'   => 'chat',
            'userId' => $userId,
            'id'     => (string) Str::uuid(),
        ]);

        $gen = $trace->generation([
            'name'  => 'claude-proxy-call',
            'model' => config('services.anthropic.model'),
            'input' => ['system' => $system, 'messages' => $messages],
        ]);

        try {
            $res = Http::withToken(config('services.anthropic.key') ?: 'not-needed')
                ->acceptJson()
                ->timeout(120)
                ->post(config('services.anthropic.base').'/messages', [
                    'model'      => config('services.anthropic.model'),
                    'max_tokens' => 4096,
                    'system'     => [[
                        'type' => 'text',
                        'text' => $system,
                        'cache_control' => ['type' => 'ephemeral'],
                    ]],
                    'messages'   => $messages,
                ])->throw()->json();

            $text = collect($res['content'])->firstWhere('type', 'text')['text'] ?? '';

            $gen->end([
                'output' => $text,
                'usage'  => $res['usage'] ?? null,
            ]);

            return $text;
        } catch (\Throwable $e) {
            $gen->end(['level' => 'ERROR', 'statusMessage' => $e->getMessage()]);
            throw $e;
        } finally {
            $langfuse->flushAsync();
        }
    }
}
```

For RAG flows, wrap retrieval as a span inside the same trace:

```php
$retrieval = $trace->span(['name' => 'pgvector-ann', 'input' => $queryVector]);
$docs = Document::query()->nearestNeighbors('embedding', $queryVector, Distance::Cosine)->limit(10)->get();
$retrieval->end(['output' => $docs->pluck('id')->all()]);
```

### 13.11 Sanctum SPA auth (Blade)

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

### 13.12 Monolog → stderr → Loki

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

---

## 14. Base image Dockerfile

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

---

## 15. Best used for

Blade-rendered Laravel apps with AI features (RAG, agents, classification, summarization) where the stack should be:
- One Postgres as source of truth (relational + vector)
- Local embeddings (no egress cost, no external dependency)
- Flat-fee LLM access via Claude Max Proxy (no per-token billing, single shared instance)
- Realtime UI without SaaS (Reverb)
- Minimal frontend build chain (no Vite, no npm)

Good fit: OSINT dashboards, internal tools, content platforms, product admin panels, small-team SaaS.

## 16. Ceiling — when to change

- **Heavy SPA interactivity** → swap Blade+Alpine for Inertia+Vue (accept the Vite build step).
- **>10k embeddings/sec sustained** → move TEI to GPU node (Burj Hikma — future dedicated GPU host, not yet live).
- **Multi-region / multi-box HA** → Portainer-on-darktower is single-host; graduate to Kamal (Rails-style deploy) or k8s.
- **Vector corpora >50M rows** → revisit pgvector limits; consider Qdrant as a side store while keeping Postgres as source of truth.
- **Strict SOC2 / compliance boundary on LLM traffic** → Claude Max Proxy sends prompts to Anthropic via the `claude` CLI under your Max subscription; verify that data handling meets the bar per project. If stricter controls are needed, swap the proxy for a direct Anthropic API integration (with DPA) or a self-hosted model.
- **Need per-project cost attribution / budgets** → Max subscription is a flat fee shared across projects. If you need per-project quotas or hard spend caps, swap to LiteLLM + direct Anthropic API keys (gives virtual keys with per-project budgets) or attribute cost at the Langfuse trace level (soft visibility, not enforcement).
- **More than Max subscription can handle (sustained high throughput)** → subprocess spawn + Max rate limits will bottleneck. Move to direct Anthropic API with parallel workers, or host a local model.
