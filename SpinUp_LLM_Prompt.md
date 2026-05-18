# SpinUp_LLM_Prompt.md — RanSynSrv New Project Bootstrap

> **Instructions for the LLM reading this file:**
> You are about to bootstrap a new web app project on the **RanSynSrv** stack.
> Work through the four phases below in order. Ask each phase's questions as a single
> conversational message, wait for the user's answers, then move to the next phase.
> Do **not** generate any code or config until all four phases are complete.

---

## Stack at a Glance

**Repo:** https://github.com/RandomSynergy17/RanSynSrv  
**Image:** `ghcr.io/randomsynergy17/ransynsrv:latest`

| Component | Detail |
|-----------|--------|
| OS | Alpine Linux |
| Web server | Nginx (port 80 internal) |
| Backend | PHP 8.4-FPM (45+ extensions) |
| Analytics | GoAccess real-time dashboard at `/goaccess` |
| Terminal | ttyd web terminal at `/ttyd` (opt-in) |
| Dev tool | Claude Code CLI (needs `ANTHROPIC_API_KEY`) |
| Supervision | s6-overlay — services auto-restart |
| Persistence | Single `/data` volume — all configs, web files, logs |
| Deployment | Docker Compose / Portainer |

---

## Phase 1 — App Identity

Ask the user these questions together in one message:

1. **App name / slug** — used as the Portainer stack name and `COMPOSE_PROJECT_NAME`
   (e.g. `nsplaylistmaker`, lowercase, no spaces)
2. **What does the app do?** — one or two sentences describing its purpose and main workflow
3. **Public URL** — the external URL users will reach it at
   (e.g. `https://myapp.randomsynergy.xyz`) — needed for GoAccess WebSocket config.
   *Note: this URL is proxied manually via NPM (Nginx Proxy Manager) — you do not need to configure SSL inside the container.*

---

## Phase 2 — Deployment

Ask the user these questions together in one message:

1. **Portainer host** — which Portainer environment to deploy to (e.g. `DarkTower`)
2. **Exposed HTTP port** — the host port that maps to the container's port 80
   (e.g. `22186`) — must be unique across all running stacks on that host
3. **Docker volume host path** — the absolute host-side path that maps to `/data` inside the container
   (e.g. `/docker/app/nspm`) — this is where all web files, logs, and configs live
4. **Host user mapping** — run `id $USER` on the Portainer host and provide the `uid` and `gid`
   (e.g. `uid=1000 gid=1000`). Used as `PUID`/`PGID` so files in the volume are owned by your host user.
5. **SSH server alias** — the ssh-manager MCP alias for this host (e.g. `darktower`).
   Used to write app files directly into the volume after the container starts.
   If the alias isn't set up yet, ask the user what host/IP and username to use.
6. **Upload / source folder** — is there a dedicated folder on the host for user-uploaded or input files?
   - If yes: what is the host path? (e.g. `/docker/app/nspm/uploads`)
   - What type of files will be stored there? (e.g. playlist files, images, CSVs)
   - This folder can be mapped as a sub-path under the data volume or as a separate additional mount

---

## Phase 3 — AI & Feature Flags

Ask the user these questions together in one message:

1. **Anthropic API key** — enables the Claude Code CLI *inside* the container for AI-assisted
   in-container development; also enables the app itself to call the Anthropic API if needed.
   Paste the key or type `skip` to leave it empty.
   > Which model does the app use if calling the API directly? (e.g. `claude-haiku-4-5-20251001`)

2. **GoAccess analytics** — enabled by default. Should it be password-protected?
   - If yes: provide a username and password for Basic Auth at `/goaccess`

3. **ttyd web terminal** — disabled by default (security risk). Enable it?
   - If yes: provide a username and password

4. **PHP settings** — any changes from defaults?
   - Memory limit (default `256M`)
   - Max upload size (default `50M`)
   - Max execution time (default `300s`)

5. **Extra runtime packages** — installed at container startup, hash-cached so they survive restarts:
   - **Alpine packages** (`INSTALL_PACKAGES`) — e.g. `ffmpeg imagemagick mc`
   - **Python/pip packages** (`INSTALL_PIP_PACKAGES`) — e.g. `openpyxl pillow pandas`

   > These are **two separate variables**. Never mix them — Alpine package names in
   > `INSTALL_PIP_PACKAGES` (or vice versa) are silently ignored by the wrong installer.

6. **AI sidecar overlay** — do you need a local vector database or text-embedding service?
   The optional `docker-compose.ai.yml` overlay adds:
   - **pgvector-enabled Postgres 17** (for vector similarity search / RAG)
   - **HuggingFace TEI** serving BGE-small-en-v1.5 (384-dim embeddings, CPU-only, ~500 MB)

   PHP apps inside the container reach them via `postgres:5432` and `http://embedder/embed`.

   If yes:
   - Provide a strong `POSTGRES_PASSWORD`
   - Any preference for embedding model? (default: `BAAI/bge-small-en-v1.5`; alternatives: `BAAI/bge-base-en-v1.5` 768-dim, `BAAI/bge-m3` 1024-dim — larger = slower, more memory)
   - Host ports to expose Postgres and the embedder on? (defaults: `5432` and `7997`)

---

## Phase 4 — App Requirements

Ask the user these questions together in one message:

1. **User workflow** — walk through the app step by step from the user's perspective.
   What do they do first, second, third? What does success look like?
2. **Input** — what does the user provide? (file upload, a form, a URL, a paste?)
3. **Output** — what does the user receive or see as a result?
4. **UI style** — any preferences?
   - Color scheme / theme (dark/light/custom)
   - CSS framework: Tailwind CDN (default), Bootstrap, or plain CSS
   - Single-page app or multi-page?
5. **Anything else** — any integrations, third-party APIs, database requirements,
   or must-have features not covered above?

---

## Generate: Artifacts to Produce

Once all four phases are answered, generate the following in order:

### 1. `stack.env` for Portainer

Generate a clean `KEY=VALUE` file with **no comments and no blank lines** — this is what Portainer
reads as the stack environment. Fill every `[placeholder]` from the user's answers.

```dotenv
COMPOSE_PROJECT_NAME=[stack-slug]
TZ=Asia/Dubai
PUID=[host-uid]
PGID=[host-gid]
HTTP_PORT=[exposed-port]
DATA_PATH=[host-data-path]
PHP_MEMORY_LIMIT=256M
PHP_MAX_UPLOAD=50M
PHP_MAX_POST=50M
PHP_MAX_EXECUTION_TIME=300
GOACCESS_ENABLED=true
GOACCESS_WS_URL=wss://[public-domain]:443/goaccess/ws
GOACCESS_AUTH_ENABLED=false
GOACCESS_USERNAME=admin
GOACCESS_PASSWORD=
TTYD_ENABLED=false
TTYD_USERNAME=admin
TTYD_PASSWORD=
ANTHROPIC_API_KEY=[api-key-or-leave-blank]
INSTALL_PACKAGES=
INSTALL_PIP_PACKAGES=
DOCKER_LOGS=false
```

If the AI sidecar was requested, append these lines too (use the ports the user provided in
Phase 3 — **do not default to 5432/7997 if other stacks on this host may already use them**):

```dotenv
POSTGRES_PASSWORD=[strong-random-password]
POSTGRES_USER=ransynsrv
POSTGRES_DB=ransynsrv
POSTGRES_HOST_PORT=[user-specified-postgres-port]
EMBEDDER_MODEL=BAAI/bge-small-en-v1.5
EMBEDDER_HOST_PORT=[user-specified-embedder-port]
```

> **Port collision warning:** `POSTGRES_HOST_PORT` and `EMBEDDER_HOST_PORT` are host-side ports.
> Every stack on the same Portainer host that enables the AI sidecar needs **different** values here.
> If the user did not specify ports, ask them to confirm before using any default — or call
> `portainer__list_containers(endpoint_id=...)` and scan the `Ports` field to find free ports.

### 2. Portainer Stack YAML

Generate a complete compose file the user can paste directly into Portainer's
stack editor. Base it on this template and fill in values from Phase 2:

```yaml
services:
  [stack-slug]:
    image: ghcr.io/randomsynergy17/ransynsrv:latest
    container_name: [stack-slug]
    hostname: ransynsrv
    security_opt:
      - no-new-privileges:true
    mem_limit: 2g
    environment:
      - PUID=[host-uid]
      - PGID=[host-gid]
      - TZ=Asia/Dubai
      - PHP_MEMORY_LIMIT=${PHP_MEMORY_LIMIT:-256M}
      - PHP_MAX_UPLOAD=${PHP_MAX_UPLOAD:-50M}
      - PHP_MAX_POST=${PHP_MAX_POST:-50M}
      - PHP_MAX_EXECUTION_TIME=${PHP_MAX_EXECUTION_TIME:-300}
      - GOACCESS_ENABLED=${GOACCESS_ENABLED:-true}
      - GOACCESS_WS_URL=${GOACCESS_WS_URL:-}
      - GOACCESS_AUTH_ENABLED=${GOACCESS_AUTH_ENABLED:-false}
      - GOACCESS_USERNAME=${GOACCESS_USERNAME:-admin}
      - GOACCESS_PASSWORD=${GOACCESS_PASSWORD:-}
      - TTYD_ENABLED=${TTYD_ENABLED:-false}
      - TTYD_USERNAME=${TTYD_USERNAME:-admin}
      - TTYD_PASSWORD=${TTYD_PASSWORD:-}
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}
      - USE_BUILTIN_RIPGREP=0
      - INSTALL_PACKAGES=${INSTALL_PACKAGES:-}
      - INSTALL_PIP_PACKAGES=${INSTALL_PIP_PACKAGES:-}
      - DOCKER_LOGS=${DOCKER_LOGS:-false}
    volumes:
      - [host-data-path]:/data
      # Uncomment if there is a dedicated upload/source folder:
      # - [host-upload-path]:/data/webroot/public_html/uploads
    ports:
      - "[exposed-port]:80"
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://127.0.0.1/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 30s
```

> In Portainer, set the stack name to `[stack-slug]` and enter env vars via the
> "Environment variables" editor — do not hardcode secrets in the YAML.
>
> **If the user wants the AI sidecar overlay:** append the contents of
> [`docker-compose.ai.yml`](https://raw.githubusercontent.com/RandomSynergy17/RanSynSrv/main/docker-compose.ai.yml)
> as additional services in the same stack YAML, and include the `POSTGRES_*` and `EMBEDDER_*`
> env vars in the Portainer environment editor.

### 3. `DEPLOY.md` — Project Deployment Reference

Generate this file with **all placeholders replaced by real values** from the user's answers.
Write it to `[host-data-path]/DEPLOY.md` (volume root, not web-accessible) during Step 2 of the
deployment procedure below.

This file stays with the project so any LLM or developer can deploy or update it without
referring back to this SpinUp guide.

````markdown
# DEPLOY.md — [App Name]

## Stack Details

| Key | Value |
|-----|-------|
| Stack name | [stack-slug] |
| Portainer host | [portainer-host] |
| SSH alias | [ssh-alias] |
| HTTP port | [exposed-port] |
| Data volume | [host-data-path] → /data |
| Upload folder | [host-upload-path] → /data/webroot/public_html/uploads (if applicable) |
| Public URL | [public-url] |
| Image | ghcr.io/randomsynergy17/ransynsrv:latest |
| Postgres host port | [postgres-host-port] *(AI sidecar only — omit if not used)* |
| Embedder host port | [embedder-host-port] *(AI sidecar only — omit if not used)* |

## Portainer IDs *(auto-populated after initial deploy)*

| Key | Value |
|-----|-------|
| Endpoint ID | `[portainer-endpoint-id]` |
| Stack ID | `[portainer-stack-id]` |
| Container ID | `[container-id]` |
| Container name | `[stack-slug]` |
| Deployed at | `[deployed-at]` |
| Image digest | `[image-digest]` |

> These IDs are used by Portainer-MCP calls for updates, redeployment, and log access.
> If a future session needs them, read this file first rather than doing a Portainer lookup.

---

## Initial Deployment

**1. Create the volume directory tree** (ssh-manager → `[ssh-alias]`):
```bash
mkdir -p [host-data-path]/webroot/public_html \
         [host-data-path]/webroot/src \
         [host-data-path]/databases \
         [host-data-path]/nginx \
         [host-data-path]/log/nginx \
         [host-data-path]/log/php
```

**2. Write app files and this DEPLOY.md** — use `ssh_execute` heredocs or `ssh_upload` to write
each file under `[host-data-path]/webroot/public_html/` and `[host-data-path]/webroot/src/`.
Write this file to `[host-data-path]/DEPLOY.md` with `[auto-populated]` placeholders first;
they will be patched in step 4.

**3. Create the Portainer stack** (portainer-mcp → `[portainer-host]`):
- Stack name: `[stack-slug]`
- Compose YAML + `stack.env` key-value pairs
- Wait ~30 s for s6-overlay init to complete

**4. Patch this file with the returned IDs** (see "Auto-update DEPLOY.md" below).

**5. Verify**:
```bash
docker exec [stack-slug] wget -qO- http://127.0.0.1/health
# → 200 OK
portainer__container_logs(container_id=[container-id], endpoint_id=[portainer-endpoint-id])
# → no ERROR lines in last 20 lines
```

**6. NPM proxy** (manual — Nginx Proxy Manager on `[portainer-host]`):
- Proxy host: `[public-domain]` → `[host-ip]:[exposed-port]`
- Enable SSL (Let's Encrypt)

---

## Auto-update DEPLOY.md after deploy

After `portainer__create_stack` returns, run `portainer__inspect_stack` and
`portainer__list_containers` to collect all IDs, then overwrite the "Portainer IDs" table
in this file via `ssh_execute`:

```bash
# Example sed patch (fill in real values before running)
sed -i \
  -e 's|\[portainer-endpoint-id\]|ENDPOINT_ID_HERE|g' \
  -e 's|\[portainer-stack-id\]|STACK_ID_HERE|g' \
  -e 's|\[container-id\]|CONTAINER_ID_HERE|g' \
  -e 's|\[deployed-at\]|DATETIME_HERE|g' \
  -e 's|\[image-digest\]|DIGEST_HERE|g' \
  [host-data-path]/DEPLOY.md
```

---

## Updating App Files

Push changed PHP/asset files without redeploying the container:

```bash
# Write changed file (ssh-manager → [ssh-alias])
cat > [host-data-path]/webroot/public_html/[changed-file] <<'EOF'
[file content]
EOF

# Reload Nginx only when nginx.conf / *.conf files change
docker exec [stack-slug] nginx -t && docker exec [stack-slug] nginx -s reload
```

PHP files take effect immediately — no reload needed for `.php` changes.

---

## Updating Stack Config (env vars / image version)

Call `portainer__update_stack` with the updated env block and the same compose YAML:

```
portainer__update_stack(
  id=[portainer-stack-id],
  endpointId=[portainer-endpoint-id],
  stackFileContent=<compose YAML>,
  env=[updated key-value pairs from stack.env]
)
```

Portainer will pull the latest image and restart the container automatically.
Update `[image-digest]` in this file after a successful redeploy.

---

## Container Access & Debugging

```bash
# Shell into the container
docker exec -it [stack-slug] zsh

# Tail all logs
portainer__container_logs(container_id=[container-id], endpoint_id=[portainer-endpoint-id])
# or via SSH:
docker logs -f [stack-slug]

# PHP errors
docker exec [stack-slug] tail -f /data/log/php/error.log

# Nginx errors
docker exec [stack-slug] tail -f /data/log/nginx/error.log

# Reload Nginx after config edit
docker exec [stack-slug] nginx -t && docker exec [stack-slug] nginx -s reload

# Check s6 service states
docker exec [stack-slug] s6-rc -a list

# Container stats
portainer__container_stats(container_id=[container-id], endpoint_id=[portainer-endpoint-id])
```

---

## Troubleshooting

### "Unable to authenticate WebSocket" on the GoAccess dashboard

Two causes — work through them in order:

**1. WebSocket Support not enabled in NPM.**
Edit the proxy host in Nginx Proxy Manager and toggle **"WebSocket Support"** on.
This must be on for GoAccess live updates (and ttyd) to work through the NPM reverse proxy.

**2. GoAccess started before NPM/SSL was live.**
GoAccess bakes `GOACCESS_WS_URL` into the dashboard HTML at startup. If the domain wasn't
reachable yet, the HTML might have been generated with a bad fallback URL.
Restart GoAccess to regenerate:
```bash
docker exec [stack-slug] s6-rc -d change svc-goaccess \
  && docker exec [stack-slug] s6-rc -u change svc-goaccess
```
If the URL itself is wrong, update `GOACCESS_WS_URL` in the Portainer stack env and redeploy first.

---

### Python/pip packages not installing (`INSTALL_PIP_PACKAGES`)

The variable name is **`INSTALL_PIP_PACKAGES`** — not `PYTHON_PACKAGES`, `PIP_PACKAGES`, or any
other alias. If the wrong name is used the container starts silently without installing anything.

```dotenv
INSTALL_PACKAGES=ffmpeg imagemagick     # Alpine (apk) packages
INSTALL_PIP_PACKAGES=openpyxl pillow    # Python (pip3) packages — separate variable
```

After correcting the variable name, redeploy the stack (or restart the container) to trigger the
init script. The init script hash-caches installed packages, so if you've already started the
container with a blank `INSTALL_PIP_PACKAGES`, you may need to delete the cache file first:
```bash
docker exec [stack-slug] rm -f /data/.ransynsrv-install-cache/pip.hash
docker compose restart   # or redeploy via Portainer
```

---

## Key Paths

| Host path | Container path | Purpose |
|-----------|----------------|---------|
| `[host-data-path]/DEPLOY.md` | *(volume root)* | This file |
| `[host-data-path]/webroot/public_html/` | `/data/webroot/public_html/` | Web root |
| `[host-data-path]/webroot/src/` | `/data/webroot/src/` | PHP backend classes |
| `[host-data-path]/databases/` | `/data/databases/` | SQLite files |
| `[host-data-path]/nginx/nginx.conf` | `/etc/nginx/nginx.conf` | Nginx config (live symlink) |
| `[host-data-path]/log/nginx/` | `/data/log/nginx/` | Access + error logs |
| `[host-data-path]/log/php/` | `/data/log/php/` | PHP-FPM errors |
| `[host-upload-path]/` | `/data/webroot/public_html/uploads/` | User uploads |
````

---

### 4. App Scaffold

Based on Phase 4 answers, generate the initial application files.

**Placement conventions:**

| File | Container path |
|------|----------------|
| Entry point | `/data/webroot/public_html/index.php` |
| Additional pages/views | `/data/webroot/public_html/*.php` |
| Static assets | `/data/webroot/public_html/assets/` |
| API endpoints | `/data/webroot/public_html/api/*.php` |
| PHP backend classes | `/data/webroot/src/` (not web-accessible) |
| SQLite databases | `/data/databases/*.db` |
| Uploaded files | `/data/webroot/public_html/uploads/` (or the separate mount) |

**Default scaffold rules:**
- Use Tailwind CSS via CDN unless the user specified otherwise
- Clean, dark-friendly UI with clear step-by-step layout matching the workflow from Phase 4
- PHP reads `ANTHROPIC_API_KEY` via `getenv('ANTHROPIC_API_KEY')` if the app calls the API
- SQLite via PDO at `/data/databases/[slug].db` for any persistence
- All paths must use the `/data/...` container paths above — never relative paths

### 4. Deploy via Portainer-MCP + SSH-manager

Execute these steps in order using your MCP tools.

**Step 1 — Create the volume directory structure on the host**

Use `ssh_execute` (server = `[ssh-alias]`) to create the expected folder tree before the
container starts, so s6-overlay's init doesn't fight with Docker's auto-created root-owned dirs:

```bash
mkdir -p [host-data-path]/webroot/public_html \
         [host-data-path]/webroot/src \
         [host-data-path]/databases \
         [host-data-path]/nginx \
         [host-data-path]/log/nginx \
         [host-data-path]/log/php
```

If there is a separate upload/source folder, create it too:
```bash
mkdir -p [host-upload-path]
```

**Step 2 — Write app files and `DEPLOY.md` to the volume**

Use `ssh_execute` with a heredoc (or `ssh_upload` if uploading generated local files) to write
each file into the volume. Write `DEPLOY.md` first so it's always present even if later steps
fail. Target paths on the host map directly to container paths:

| Host path | Container path |
|-----------|----------------|
| `[host-data-path]/DEPLOY.md` | *(volume root — not served by Nginx)* |
| `[host-data-path]/webroot/public_html/index.php` | `/data/webroot/public_html/index.php` |
| `[host-data-path]/webroot/public_html/api/*.php` | `/data/webroot/public_html/api/*.php` |
| `[host-data-path]/webroot/src/*.php` | `/data/webroot/src/*.php` |

Example heredoc write via ssh_execute:
```bash
cat > [host-data-path]/webroot/public_html/index.php <<'PHPEOF'
<?php
// generated scaffold content here
PHPEOF
```

**Step 3 — Create the Portainer stack**

Call `portainer__create_stack` with:
- **name**: `[stack-slug]`
- **stackFileContent**: the compose YAML from artifact 2 above
- **env**: the `stack.env` key-value pairs from artifact 1 above
- **endpointId**: the ID of the `[portainer-host]` environment (get it from `portainer__list_environments` if unknown)

Wait ~30 seconds for s6-overlay init to complete.

**Step 4 — Patch `DEPLOY.md` with the real Portainer IDs**

After `portainer__create_stack` returns, collect the following IDs:

| ID | How to get it |
|----|---------------|
| `portainer-endpoint-id` | Returned by `portainer__list_environments` or from the create response |
| `portainer-stack-id` | Returned directly by `portainer__create_stack` |
| `container-id` | Call `portainer__list_containers(endpoint_id=...)`, find the container named `[stack-slug]` |
| `image-digest` | From `portainer__inspect_container` → `Image` field |
| `deployed-at` | Current UTC timestamp |

Then use `ssh_execute` (server = `[ssh-alias]`) to patch `DEPLOY.md`:

```bash
sed -i \
  -e 's|\[portainer-endpoint-id\]|ACTUAL_ENDPOINT_ID|g' \
  -e 's|\[portainer-stack-id\]|ACTUAL_STACK_ID|g' \
  -e 's|\[container-id\]|ACTUAL_CONTAINER_ID|g' \
  -e 's|\[deployed-at\]|ACTUAL_DATETIME|g' \
  -e 's|\[image-digest\]|ACTUAL_DIGEST|g' \
  [host-data-path]/DEPLOY.md
```

**Step 5 — Verify the container is healthy**

```bash
portainer__container_logs(container_id=ACTUAL_CONTAINER_ID, endpoint_id=ACTUAL_ENDPOINT_ID)
```
Confirm no `ERROR` lines in the last 20 lines. Then:
```bash
portainer__inspect_container(container_id=ACTUAL_CONTAINER_ID, endpoint_id=ACTUAL_ENDPOINT_ID)
```
Confirm `Status: running` and healthcheck state is `healthy`.

**Step 6 — Reload Nginx to pick up the scaffold files**

Use `ssh_execute` (server = `[ssh-alias]`):
```bash
docker exec [stack-slug] nginx -t && docker exec [stack-slug] nginx -s reload
```

**Step 7 — NPM proxy (manual)**

In Nginx Proxy Manager on `[portainer-host]`:
1. Add proxy host: domain `[public-domain]` → forward to `[host-ip]:[exposed-port]`
2. **Enable "WebSocket Support"** on the proxy host (toggle in the NPM proxy host editor)
   — this is required for GoAccess live updates and ttyd; without it the browser gets
   "Unable to authenticate WebSocket" even though the URL and credentials are correct
3. Enable SSL via Let's Encrypt

Then restart GoAccess so it regenerates the dashboard HTML with the now-live `wss://` URL:
```bash
# ssh-manager → [ssh-alias]
docker exec [stack-slug] s6-rc -d change svc-goaccess \
  && docker exec [stack-slug] s6-rc -u change svc-goaccess
```
Wait ~5 s, then verify `[public-url]/goaccess` loads and the real-time indicator is green.

**Step 8 — Verify**

- `[public-url]` → app loads
- `[public-url]/goaccess` → analytics dashboard loads
- `[public-url]/health` → returns `200 OK`

**Step 9 — Present the deployment summary to the user**

Output the following table block as your final message, filled with all real values.
Mask secrets to the last 4 characters (e.g. `sk-ant-…xxxx`). Omit AI sidecar rows if not used.

---

### ✅ [App Name] — Deployed

**Access**

| | |
|---|---|
| App URL | [public-url] |
| Analytics | [public-url]/goaccess |
| Web terminal | [public-url]/ttyd *(if enabled)* |
| Health check | [public-url]/health |

**Stack**

| | |
|---|---|
| Stack name | `[stack-slug]` |
| Container name | `[stack-slug]` |
| Portainer host | `[portainer-host]` |
| HTTP port | `[exposed-port]` |
| Image | `ghcr.io/randomsynergy17/ransynsrv:latest` |
| Deployed at | `[deployed-at]` |

**Portainer IDs** *(for future MCP calls)*

| | |
|---|---|
| Endpoint ID | `[portainer-endpoint-id]` |
| Stack ID | `[portainer-stack-id]` |
| Container ID | `[container-id]` |
| Image digest | `[image-digest]` |

**Storage**

| | |
|---|---|
| Data volume | `[host-data-path]` → `/data` |
| Upload folder | `[host-upload-path]` → `/data/webroot/public_html/uploads` *(if applicable)* |
| SSH alias | `[ssh-alias]` |

**Environment**

| Variable | Value |
|---|---|
| `PUID` / `PGID` | `[host-uid]` / `[host-gid]` |
| `TZ` | `[tz]` |
| `PHP_MEMORY_LIMIT` | `[value]` |
| `PHP_MAX_UPLOAD` | `[value]` |
| `PHP_MAX_EXECUTION_TIME` | `[value]s` |
| `ANTHROPIC_API_KEY` | `[masked — last 4 chars]` |
| `GOACCESS_ENABLED` | `[value]` |
| `GOACCESS_AUTH_ENABLED` | `[value]` |
| `TTYD_ENABLED` | `[value]` |
| `INSTALL_PACKAGES` | `[value or —]` |
| `DOCKER_LOGS` | `[value]` |

**AI Sidecar** *(omit section if not deployed)*

| | |
|---|---|
| Postgres host port | `[postgres-host-port]` |
| Embedder host port | `[embedder-host-port]` |
| Embedder model | `[embedder-model]` |

**Next steps**
- To update a file: `ssh_execute` → write to `[host-data-path]/webroot/public_html/` → reload nginx if needed
- To update env vars / image: `portainer__update_stack(id=[portainer-stack-id], endpointId=[portainer-endpoint-id], ...)`
- Full deployment reference: `[host-data-path]/DEPLOY.md`

---

## Key Paths Reference

| Path inside container | Purpose |
|-----------------------|---------|
| `/data/webroot/public_html/` | Nginx web root — all HTTP-accessible files |
| `/data/webroot/src/` | PHP backend classes (not web-accessible) |
| `/data/databases/` | SQLite `.db` files |
| `/data/nginx/nginx.conf` | Live Nginx config (symlinked to `/etc/nginx/nginx.conf`) |
| `/data/nginx/*.conf` | Extra Nginx configs auto-included on reload |
| `/data/nginx/nginx-upload.conf` | Auto-generated by init from `PHP_MAX_UPLOAD` — sets `client_max_body_size` |
| `/data/nginx/php-timeout.conf` | Auto-generated by init from `PHP_MAX_EXECUTION_TIME` — sets FastCGI timeouts |
| `/data/log/nginx/access.log` | Web access log (fed to GoAccess) |
| `/data/log/nginx/error.log` | Nginx error log |
| `/data/log/php/error.log` | PHP-FPM error log |
| `/data/webroot/goaccess/index.html` | Auto-generated analytics dashboard |
| `/run/php/php-fpm.sock` | PHP-FPM Unix socket (used internally by Nginx) |
| `/data/claude/.claude/` | Claude Code config (persists across restarts) |

**Reload Nginx** (from host, not inside container):
```bash
docker exec [container-name] nginx -t && docker exec [container-name] nginx -s reload
```

**View PHP errors:**
```bash
docker exec [container-name] tail -f /data/log/php/error.log
```

---

## ⚠️ Known Gotchas

These are real issues that have bitten deployments. Check them before debugging anything else.

### 1. nginx.conf must be named exactly `nginx.conf`

RanSynSrv's init symlinks `/data/nginx/nginx.conf` → `/etc/nginx/nginx.conf`. If you name your
config `myapp.conf`, `playday.conf`, etc., the default config runs silently — your routes and PHP
config are ignored.

### 2. nginx.conf must be a complete config, not just a `server {}` block

The file must include the full nginx config hierarchy:

```nginx
worker_processes auto;
pid /run/nginx/nginx.pid;
error_log /data/log/nginx/error.log warn;
include /etc/nginx/modules/*.conf;

events { worker_connections 2048; }

http {
    include /data/nginx/nginx-upload.conf;  # ← required — sets client_max_body_size
    ...
    server {
        ...
        location ~ \.php$ {
            include /data/nginx/php-timeout.conf;  # ← required — sets FastCGI timeouts
            ...
        }
    }
}
```

A bare `server { }` block at line 1 causes nginx to crash-loop with:
`"server" directive is not allowed here in /etc/nginx/nginx.conf:1`

Use the default config from `root/defaults/nginx/nginx.conf` as your base.

### 3. Custom nginx.conf must include the two auto-generated fragments

| Include | Where | What it does |
|---------|-------|--------------|
| `include /data/nginx/nginx-upload.conf;` | inside `http {}` | Sets `client_max_body_size` from `PHP_MAX_UPLOAD` |
| `include /data/nginx/php-timeout.conf;` | inside `location ~ \.php$ {}` | Sets FastCGI read/send timeouts from `PHP_MAX_EXECUTION_TIME` |

Omitting either causes a silent mismatch: PHP allows the upload/execution but nginx blocks it first.

### 4. GoAccess WS URL — no explicit port required for standard HTTPS

`wss://` without a port number is fine for standard HTTPS (defaults to port 443 per RFC 6455,
identical to how `https://` works). GoAccess 1.9.x embeds the URL verbatim and the browser connects correctly.

```dotenv
# ✅ Both of these work
GOACCESS_WS_URL=wss://yourdomain.com/goaccess/ws
GOACCESS_WS_URL=wss://yourdomain.com:443/goaccess/ws

# For local dev — match HTTP_PORT
GOACCESS_WS_URL=ws://localhost:8080/goaccess/ws
```

### 5. Python packages: use `INSTALL_PIP_PACKAGES`, not `PYTHON_PACKAGES`

```dotenv
INSTALL_PACKAGES=ffmpeg imagemagick     # Alpine (apk)
INSTALL_PIP_PACKAGES=openpyxl pillow    # Python (pip3) — this exact name
```

`PYTHON_PACKAGES` is silently ignored — the container starts successfully but the packages are never installed. Caught at runtime when scripts throw `ModuleNotFoundError`.

### 6. `php` resolves to PHP 8.4; Composer is at `/usr/bin/composer.phar`

Inside the container, `php` → PHP 8.4 (Dockerfile symlink). Laravel artisan and Composer work as expected:

```bash
php artisan migrate
php /usr/bin/composer.phar install
```

### 7. Nginx reload from inside the container is blocked under compose

`sudo nginx -s reload` fails when `no-new-privileges:true` is set in compose (the default).
Reload from the **host** instead:

```bash
docker exec ransynsrv nginx -t && docker exec ransynsrv nginx -s reload
```

### 8. Multiple instances on the same host

Set `COMPOSE_PROJECT_NAME=myapp_name` in `.env` to prevent container and network name conflicts.
Each instance also needs a unique `HTTP_PORT`.

### 9. GoAccess analytics persist across restarts

Since v1.4.0, GoAccess stores historical analytics in `/data/goaccess-db/` (TokyoCabinet).
First boot may scaffold this directory automatically — no manual action needed.

### 10. Do not mix Alpine and pip packages in the same variable

Wrong installer silently ignores unknown package names:

```dotenv
INSTALL_PACKAGES=ffmpeg imagemagick mc         # ✅ Alpine packages here
INSTALL_PIP_PACKAGES=pandas numpy requests     # ✅ pip packages here — separate variable
```
