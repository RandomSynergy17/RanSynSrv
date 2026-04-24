# Changelog

All notable changes to this project are documented here. The format is based on
[Common Changelog](https://common-changelog.org) and this project adheres to
[Semantic Versioning](https://semver.org/).

## 1.1.0 — 2026-04-24

Deployment-bug remediation, AI sidecar overlay, and two rounds of security/correctness hardening.

### Security

- **Closed PHP-RCE → root privilege escalation path.** `COPY --chown=abc:abc root/ /` previously gave the unprivileged runtime user write access to the s6 supervisor's service scripts (executed as root each boot). Drop the `--chown`; explicitly re-chown only `/defaults/`.
- **ttyd credential removed from process argv.** Auth moved from ttyd's `-c "$USER:$PASS"` flag to nginx-layer HTTP Basic auth, with the bcrypt-style htpasswd hash written to `/data/nginx/.ttyd-htpasswd` by [init-ransynsrv/run](root/etc/s6-overlay/s6-rc.d/init-ransynsrv/run). Plaintext password no longer appears in `ps aux` / `/proc/<pid>/cmdline` where any same-UID process (a compromised PHP worker) could read it.
- **`Server:` brand header stripped.** nginx.conf now uses `more_clear_headers Server;` (the `headers-more` module was already compiled in). `server_tokens off` already hid the version; this hides the brand name. No nginx fingerprint for scanners.
- **Webroot denies editor-backup + database-file extensions.** `location ~* \.(bak|swp|swo|orig|tmp|old|sql|db|sqlite|sqlite3|log|env)$ { deny all; return 404; }` — an accidentally-dropped `app.db` / `config.env` returns 404 instead of leaking.
- **`no-new-privileges:true`** on every compose service blocks post-init sudo / setuid escalation.
- **Sidecar host ports bound to `127.0.0.1` by default.** [docker-compose.ai.yml](docker-compose.ai.yml) maps `${POSTGRES_BIND_ADDR:-127.0.0.1}:${POSTGRES_HOST_PORT:-5432}:5432` (and same pattern for the embedder). Postgres + TEI are no longer exposed on all host interfaces by default; opt out with `POSTGRES_BIND_ADDR=0.0.0.0`.
- **`EXPOSE` reduced from `80 7890 7681` to `80`.** The prior list let `docker run -P` publish GoAccess WebSocket and ttyd backend directly, bypassing nginx proxy auth.
- **Default `index.php` no longer serves `phpinfo()`** ([root/defaults/webroot/public_html/index.php](root/defaults/webroot/public_html/index.php)). Prior version embedded ~100 KB of `phpinfo()` in HTML source hidden with `display:none`, leaking PHP version / extensions / configure options to anonymous visitors.
- **Internal-only proxy blocks hardcode `Host: localhost`.** `/goaccess/ws` and `/ttyd/` no longer pass through untrusted upstream `Host` headers.
- **Log files created with mode `0640`**; access logs contain real-IP data after `real_ip_header` processing and shouldn't be world-readable inside the container.
- **SSH private keys enforced to mode `0600`** regardless of how they arrive from the host bind-mount.
- **Removed `ANTHROPIC_API_KEY=""` and `TTYD_PASSWORD=""` `ENV` defaults from the Dockerfile.** Empty-string ENV defaults leaked the variable names into `docker inspect` output and encouraged real keys via `--build-arg` (which bakes into image layers). Runtime injection via compose `environment:` still works.

### Fixed

- **First-boot 404 on every endpoint (nginx/init race).** Nginx started before the legacy `cont-init.d` script symlinked `/etc/nginx/nginx.conf`, loading Alpine's `http.d/default.conf` 404-stub. Fix: ship [root/etc/nginx/nginx.conf](root/etc/nginx/nginx.conf) in the image (so first-boot already has the right config), delete Alpine's `http.d/default.conf` at build, and consolidate init into a proper s6-rc oneshot that blocks services via `dependencies.d/init-ransynsrv` edges.
- **Phantom `init-ransynsrv` oneshot.** The `up` file was 0 bytes so `s6-rc-compile` silently dropped the oneshot; any fix added to its `run` script since January was dead code. Fix: populate `init-ransynsrv/up` and delete the legacy `cont-init.d/00-init-ransynsrv` duplicate.
- **`DOCKER_LOGS`, `INSTALL_PACKAGES`, `INSTALL_PIP_PACKAGES`, `GOACCESS_AUTH_ENABLED` silently did nothing.** The legacy init script used `#!/bin/sh` which in s6-overlay v3 runs without container env vars. Fix: init is now an s6-rc oneshot with `#!/command/with-contenv sh`, so all env-conditional branches actually run.
- **`arm64` image contained `x86_64` s6-overlay binaries** because the Dockerfile `ADD`-ed a hardcoded URL. Only worked on Apple Silicon thanks to Rosetta; would fail on real arm64 Linux (AWS Graviton, Pi 4/5, Ampere) with `exec format error`. Fix: arch-dispatch in a `RUN` step.
- **arm64 `git-delta` was glibc-linked** on a musl Alpine → `delta: not found` at runtime. Fix: install via the Alpine `delta` package (correctly linked for both arches).
- **ttyd credentials corrupted** when `TTYD_PASSWORD` contained `:`, spaces, or shell metacharacters. Fix: build argv with `set --`; pass `-c "${TTYD_USERNAME}:${TTYD_PASSWORD}"` as a proper argv element (later removed entirely in favor of nginx-layer auth).
- **GoAccess dashboard WebSocket broken by default.** Fallback `--ws-url` was `ws://\$host:\$port/goaccess/ws` — shell-escaped `\$` made GoAccess embed the literal string. Fix: warn loudly when `GOACCESS_WS_URL` is unset; fall back to `ws://localhost/goaccess/ws`.
- **`nginx-reload` shell alias prompted for a password.** Sudoers only allowed `/usr/sbin/nginx -t`. Fix: broaden to `/usr/sbin/nginx` so `nginx-test` and `nginx-reload` both work non-interactively (NB: blocked by `no-new-privileges` under compose — documented).
- **PHP-FPM had `clear_env = yes` (default)**, so PHP apps couldn't read container env vars via `getenv()` / `$_ENV`. Fix: add `clear_env = no` to the pool config generated by [svc-php-fpm/run](root/etc/s6-overlay/s6-rc.d/svc-php-fpm/run).
- **`PHP_*` env vars were frozen at image-build time.** Dockerfile rendered them into `/etc/php84/conf.d/99-ransynsrv.ini` during `RUN`. Setting them at runtime had no effect. Fix: regenerate the INI on every boot in `svc-php-fpm/run`.
- **`fastcgi_read_timeout` now tracks `PHP_MAX_EXECUTION_TIME`.** Init writes `/data/nginx/php-timeout.conf` from the env var each boot; nginx.conf `include`s it inside the `.php$` block. Raising the env var no longer silently 504s long-running scripts at nginx's hardcoded 300 s.
- **`chown -R /data /workspace` no longer runs on every boot.** Init writes a `/data/.ransynsrv-init-done` sentinel and, from then on, only re-chowns the specific subtrees services need to own. Previously a large pre-populated `/data` volume stalled all services at boot.
- **`DOCKER_LOGS=true` + GoAccess no longer overwrites the stdout symlink.** `svc-goaccess` uses `[ -e … ]` (existence, any type) instead of `[ -f … ]` (regular file only), so the `/proc/1/fd/1` symlink passes the existence check and the destructive `touch` fallback is no longer reached.
- **nginx `client_max_body_size 100M` vs PHP `post_max_size=50M` asymmetry** caused silent data loss on 50–100 MB uploads. Fix: align both at 50M.
- **GoAccess auth marker-edit is now atomic and idempotent.** `init-ransynsrv/run` writes nginx.conf edits via a `.tmp` file + `os.replace`; uses a Python replacement callable so directive bodies containing `\1`-`\9` or backslashes can't corrupt the substitution. Missing markers now log an explicit warning to stderr (previously silent exit).
- **nginx `SCRIPT_FILENAME` uses `$document_root`** instead of `$realpath_root` — symlinked files inside `public_html/` no longer leak resolved filesystem paths to PHP-FPM.
- **Disabled services use `/command/s6-pause`** instead of `sleep infinity` (supervision-aware; no restart noise on teardown).
- **`S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0`** (infinite) replaced with `60000` so hanging init doesn't silently block forever.

### Added

- **AI sidecar overlay** ([docker-compose.ai.yml](docker-compose.ai.yml)) — optional compose overlay adding `pgvector/pgvector:0.8.0-pg17` Postgres and `ghcr.io/huggingface/text-embeddings-inference:cpu-1.5` serving `BAAI/bge-small-en-v1.5`. Enabled via `docker compose -f docker-compose.yml -f docker-compose.ai.yml up -d`. PHP apps reach the sidecars via DNS (`postgres:5432`, `embedder:80`); host ports configurable via env. Postgres runs as `${PUID}:${PGID}` so bind-mounted data is host-readable without sudo; `ai-init` oneshot helper chowns `./data/postgres` and `./data/tei-cache` each boot. `POSTGRES_PASSWORD` is required — compose fails fast without it.
- **TEI healthcheck + pinned image tag + raised start_period.** `pgvector:0.8.0-pg17` pinned (not rolling `pg17`); TEI healthcheck uses `wget` (curl isn't in the cpu-1.5 image); `start_period: 180s` accommodates first-boot model downloads on slow connections.
- **`--auto-truncate` documented as the RAG-correct default** in [docker-compose.ai.yml](docker-compose.ai.yml) with an inline note on how to opt out via a compose override (silent clipping suits embeddings; document-integrity workloads may want HTTP 413 on over-length inputs instead).
- **GPU-alternative image note** in `docker-compose.ai.yml` — commented `cuda-1.5` image + NVIDIA `deploy.resources` block for users with GPUs.
- **Per-model memory guide** in `.env.example` — cache size / RAM-when-loaded for BGE-small / base / large / M3 plus dim-migration reminder for pgvector columns.
- **`TTYD_AUTH_BEGIN` / `TTYD_AUTH_END` marker block** in nginx.conf, managed by init similarly to GoAccess.
- **`more_clear_headers` usage** in nginx default config (the `nginx-mod-http-headers-more` Alpine package was already installed; now actually used).
- **CSP guidance** in nginx.conf as a commented `Content-Security-Policy` example. CSP stays off by default (hosted apps need their own policy) but the starter value is one uncomment away.
- **Ops documentation** in [CLAUDE.md](CLAUDE.md): `pg_dump` backup + restore recipe, TEI model-cache cleanup, compose-target warnings, and troubleshooting entries for the sudo / `no-new-privileges` interaction and the `DOCKER_LOGS=true` vs GoAccess pipe-file incompatibility.
- **README refresh** — badges, architecture diagram, configuration reference tables, feature tables, AI sidecar section with PHP RAG example.
- **`.dockerignore` tightened** — excludes `docker-compose*.yml`, `CLAUDE.md`, `changelog.md`, `.gitattributes`, `.claude/`, `_docs/`, `logs/`, `.playwright-mcp/` from the build context.
- **Atomic config helper** — generalized `write_auth_block` → `write_marker_block` powers both `GOACCESS_AUTH` and `TTYD_AUTH` toggles.

### Changed

- **`CLAUDE_CODE_VERSION`** bumped from `2.1.12` to `2.1.118` (latest on npm at release).
- **OCI image labels** — `version` promoted to `ARG IMAGE_VERSION=1.1.0` (CI can inject `git describe`); added `org.opencontainers.image.source` and `licenses` labels; `description` updated to reflect the AI sidecar option.
- **`docker-compose.yml`** — dropped the deprecated `version: '3.9'` field; added `mem_limit: 2g` and `security_opt: [no-new-privileges:true]`.
- **`docker-compose.deploy.yml`** — `container_name` parameterized to `${COMPOSE_PROJECT_NAME:-ransynsrv}` so multiple instances can coexist on one host.
- **Sudoers** widened from `/usr/sbin/nginx -t` to `/usr/sbin/nginx` (both `nginx-test` and `nginx-reload` aliases now work when no-new-privileges is off).
- **NVM sha256** annotated as version-specific so bumps don't silently slip.

### Removed

- Legacy `root/etc/cont-init.d/00-init-ransynsrv` (replaced by the s6-rc oneshot).
- `/data/crontabs` from init scaffolding — no crond service was ever supervised, so the directory was misleading. Use a sidecar (e.g. `ofelia`) or add your own s6 service for scheduled tasks.
- Empty legacy directories `_docs/`, `ransynsrv/`, `logs/`.
- Bundled `docs/RanSyn_Laravel_AI.md` and `docs/laravel-ai-stack.md` reference guides (moved to a separate repository).

### Notes

- **Backward compatibility.** Existing deployments that customized `/data/nginx/nginx.conf` keep their file (init only copies defaults when missing). The new `GOACCESS_AUTH` / `TTYD_AUTH` marker blocks only exist in the shipped default — customized configs won't get auth-toggle retrofit. The init's marker-block helper now prints an explicit warning when markers are missing so you'll notice. To adopt the new toggles, diff your `/data/nginx/nginx.conf` against `root/defaults/nginx/nginx.conf` and backport the marker comments.
- **`no-new-privileges` vs sudo.** Compose applies `no-new-privileges:true`, which blocks `abc` sudo even though sudoers allows `/usr/sbin/nginx`. Reload nginx from the host instead: `docker exec ransynsrv nginx -s reload`. Drop the `security_opt` line in compose to restore interactive sudo behavior.
- **`DOCKER_LOGS=true` disables real-time GoAccess analytics.** GoAccess tails `/data/log/nginx/access.log` as a regular file; when `DOCKER_LOGS=true`, that path is a pipe to PID 1's stdout, which GoAccess can't read. Pick one.
- **Known gap.** GoAccess tarball download in the Dockerfile still lacks a `sha256sum` pin (tracked for a future release that rewires the fetch).

## Unreleased

Fourth audit pass — dead code, perf, security v4, CI hardening, docs drift.

### Security

- **htpasswd entries now use SHA-512-crypt** (`openssl passwd -6`) instead of apr1/MD5-crypt for both `/data/nginx/.goaccess-htpasswd` and `.ttyd-htpasswd`. ~1000× more resistant to offline cracking if the volume ever leaks. Still natively understood by nginx's `ngx_http_auth_basic_module` — no compat cost.
- **nginx symlink edit is now atomic.** [init-ransynsrv/run](root/etc/s6-overlay/s6-rc.d/init-ransynsrv/run) replaced the prior `rm -f … && ln -s …` pair with a single `ln -sfn`, closing a TOCTOU window where a crashed init could leave `/etc/nginx/nginx.conf` missing and crash-loop nginx on the next boot.
- **Sudoers narrowed** from `abc ALL=(ALL) NOPASSWD: /usr/sbin/nginx` (any args) to two explicit entries: `nginx -t` and `nginx -s reload`. Stops a PHP-RCE-as-abc from doing `sudo nginx -c /attacker.conf` to load an arbitrary config as root (under compose's `no-new-privileges` this was already blocked; this closes it for plain `docker run` invocations too).
- **`TTYD_ENABLED=true` with missing credentials now logs a loud warning** at boot instead of silently starting ttyd with no authentication.
- **`ANTHROPIC_API_KEY` exposure documented prominently** in [CLAUDE.md](CLAUDE.md). `clear_env=no` is kept as-is (single-tenant design), but the risk of an API-key exfil via any PHP RCE is now called out with three escalating mitigations.

### Fixed

- **nginx log format now matches GoAccess parser.** [nginx.conf](root/defaults/nginx/nginx.conf) previously wrote `log_format main` (7 fields) while [/etc/goaccess/goaccess.conf](root/etc/goaccess/goaccess.conf) was configured with `log-format COMBINED` (8 fields, includes `$http_x_forwarded_for`). Now writes `combined_xff` with all 8 fields, so GoAccess sees real client IPs when the container is behind a reverse proxy.

### Added

- **Opcache shipped enabled with dev-friendly defaults** (`PHP_OPCACHE_ENABLE=1`, `PHP_OPCACHE_VALIDATE_TIMESTAMPS=1`, `PHP_OPCACHE_MEMORY_MB=128`, `PHP_OPCACHE_MAX_FILES=10000`, `PHP_OPCACHE_INTERNED_STRINGS_MB=16`). ~1.5–2× PHP throughput out of the box; flip `PHP_OPCACHE_VALIDATE_TIMESTAMPS=0` for peak perf (2–5×, at the cost of needing a reload after code edits).
- **PHP-FPM pool knobs are env-driven.** `PHP_PM_MAX_CHILDREN`, `PHP_PM_START_SERVERS`, `PHP_PM_MIN_SPARE`, `PHP_PM_MAX_SPARE`, `PHP_PM_MAX_REQUESTS` — tune per-deploy without editing the service script.
- **`INSTALL_PACKAGES` / `INSTALL_PIP_PACKAGES` now cache across boots.** Init hashes the value and skips `apk add` / `pip install` when the hash matches what's already been installed. 5–15 s faster cold start on unchanged configs.
- **CI pipeline hardened**: runtime smoke test gates `:latest` (boot container + curl `/health` + verify healthy state before push); hadolint + shellcheck lint job runs in parallel; SLSA build-provenance attestation re-enabled (the "requires public repo" comment was always wrong — the repo IS public); `IMAGE_VERSION` build-arg wired from `github.ref_name` so tagged releases carry the correct OCI version label; PR builds now runtime-test the image.

### Changed

- **`git-delta` moved into the main package RUN block** (was a separate layer after Alpine updates). Saves one image layer and one `apk update` index fetch per rebuild.
- **`GIT_DELTA_VERSION` ARG removed** from Dockerfile — orphaned since delta migrated to the `apk add delta` pattern a pass ago.
- **Stale `io.ransynsrv.version=1.0.0` labels removed** from both compose files; `org.opencontainers.image.version` (from the Dockerfile ARG) is now the single source of truth.
- **`ccl_chromium_reader` removed from CLAUDE.md Python LevelDB note** — was never actually installed.
- **`/defaults/CLAUDE.md` service-order description corrected** — nginx, php-fpm, and ttyd start in parallel once init is done; only goaccess waits for nginx. Prior description implied sequential startup.

### Removed

- `.dockerignore` entries for `_docs/` and `logs/` (directories deleted a pass ago, patterns are inert).


## Prior history

Pre-1.1.0 changes lived on the `main` branch without formal version tags. See git log for details.
