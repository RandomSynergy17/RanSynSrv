# Changelog

All notable changes to this project are documented here. The format is based on
[Common Changelog](https://common-changelog.org) and this project adheres to
[Semantic Versioning](https://semver.org/).

## Unreleased

### Security

- **Removed `ANTHROPIC_API_KEY=""` `ENV` default from [Dockerfile](Dockerfile)**. Leaving it as an `ENV` leaked the variable name into `docker inspect` output and encouraged contributors to pass real keys via `--build-arg` (which bakes into image layers). Runtime injection via compose `environment:` still works unchanged.
- **Bound sidecar host ports to `127.0.0.1` by default**: [docker-compose.ai.yml](docker-compose.ai.yml) now maps `${POSTGRES_BIND_ADDR:-127.0.0.1}:${POSTGRES_HOST_PORT:-5432}:5432` and same pattern for the embedder. Postgres + TEI are no longer exposed on all host interfaces by default. Set `POSTGRES_BIND_ADDR=0.0.0.0` / `EMBEDDER_BIND_ADDR=0.0.0.0` to opt out.

### Fixed

- **GoAccess auth marker-edit is now atomic**: [init-ransynsrv/run](root/etc/s6-overlay/s6-rc.d/init-ransynsrv/run) writes the modified nginx.conf to a `.tmp` file and `os.replace`s it into place, so a crashed/interrupted init can't leave nginx with a syntactically invalid config between the `GOACCESS_AUTH_BEGIN` / `GOACCESS_AUTH_END` markers.
- **Python regex replacement hardened**: the auth-block writer uses a replacement callable rather than a string template, so directive bodies containing regex-special chars (`\1`-`\9`, backslashes) can't corrupt the substitution.
- **nginx `SCRIPT_FILENAME` uses `$document_root`** instead of `$realpath_root` ([root/defaults/nginx/nginx.conf](root/defaults/nginx/nginx.conf), [root/etc/nginx/nginx.conf](root/etc/nginx/nginx.conf)): symlinked files under `public_html/` no longer leak their resolved filesystem paths to PHP-FPM.
- **Disabled services use `s6-pause` instead of `sleep infinity`**: [svc-goaccess/run](root/etc/s6-overlay/s6-rc.d/svc-goaccess/run) and [svc-ttyd/run](root/etc/s6-overlay/s6-rc.d/svc-ttyd/run) now `exec /command/s6-pause` when their env var is off, which cooperates with s6 supervision signals and doesn't generate restart-noise on container teardown.
- **TEI healthcheck switched to `wget`** ([docker-compose.ai.yml](docker-compose.ai.yml)): the `text-embeddings-inference:cpu-1.5` base image doesn't reliably include `curl`; `wget` is more likely to be present. `start_period` raised to `180s` so slow first-boot model downloads don't flap the health state.
- **Pinned `pgvector` to a versioned tag** (`pgvector/pgvector:0.8.0-pg17`) in [docker-compose.ai.yml](docker-compose.ai.yml). The rolling `pg17` tag auto-advances across minor extension releases and could surprise existing vector columns on compose-level pulls.

### Added

- **CSP guidance** added to [nginx.conf](root/defaults/nginx/nginx.conf) as a commented `Content-Security-Policy` example. CSP stays off by default (hosted apps need their own policy) but the starter value is now one uncomment away.
- **Ops documentation** in [CLAUDE.md](CLAUDE.md) AI Sidecar Overlay section: `pg_dump` backup + restore recipe, TEI model-cache cleanup procedure for model swaps, and a warning against `docker compose up -d postgres --no-deps` (which would bypass the `ai-init` permission barrier).
- **`.dockerignore` tightened**: excludes `docker-compose*.yml`, `CLAUDE.md`, `changelog.md`, `.gitattributes`, `.claude/`, `_docs/`, `logs/`, `.playwright-mcp/` from the build context (reduces context-transfer latency; none of these land in the image anyway via `COPY root/ /`).
- **NVM sha256 comment**: [Dockerfile](Dockerfile) now annotates the NVM installer sha256 as version-specific so bumps don't silently look transparent.

### Added

- **AI sidecar overlay** ([docker-compose.ai.yml](docker-compose.ai.yml)): optional compose overlay adding `pgvector/pgvector:pg17` Postgres and `ghcr.io/huggingface/text-embeddings-inference:cpu-1.5` serving `BAAI/bge-small-en-v1.5`. Enabled via `docker compose -f docker-compose.yml -f docker-compose.ai.yml up -d`. PHP apps inside ransynsrv reach the sidecars by DNS (`postgres:5432`, `embedder:80`); host ports are configurable via `POSTGRES_HOST_PORT` / `EMBEDDER_HOST_PORT` env vars. Both services include `no-new-privileges`, memory limits, and healthchecks. Postgres runs as `${PUID}:${PGID}` so bind-mounted files are host-readable without `sudo`; an `ai-init` oneshot helper chowns `./data/postgres` and `./data/tei-cache` on every boot. See the AI Sidecar Overlay section in [CLAUDE.md](CLAUDE.md) for first-time setup, the PHP usage pattern, and model-swap instructions. New env vars documented in [.env.example](.env.example): `POSTGRES_USER`, `POSTGRES_PASSWORD` (required), `POSTGRES_DB`, `POSTGRES_HOST_PORT`, `POSTGRES_INITDB_ARGS`, `POSTGRES_MEM_LIMIT`, `EMBEDDER_MODEL`, `EMBEDDER_HOST_PORT`, `EMBEDDER_MEM_LIMIT`.

### Security

- **Container privilege escalation**: `abc` runtime user could overwrite service scripts under `/etc/s6-overlay/s6-rc.d/*/run` (executed as root at boot), giving a PHP-RCE-to-root path. Root cause: `COPY --chown=abc:abc root/ /` chowned everything. Fix: drop the `--chown`; re-chown only `/defaults/` explicitly. Closes the escalation path.
- **`no-new-privileges:true`** added to both [docker-compose.yml](docker-compose.yml) and [docker-compose.deploy.yml](docker-compose.deploy.yml).
- **`EXPOSE` reduced to `80`** in [Dockerfile](Dockerfile). The prior `EXPOSE 80 7890 7681` made `docker run -P` publish the internal GoAccess WebSocket and ttyd backend directly, bypassing nginx proxy auth.
- **Default `index.php` no longer serves `phpinfo()`** ([root/defaults/webroot/public_html/index.php](root/defaults/webroot/public_html/index.php)). Previous version embedded 100 KB of `phpinfo()` in the HTML source (hidden with `display:none`), leaking PHP version / extensions / configure options to anonymous visitors.
- **Internal-only proxy blocks hardcode `Host: localhost`** ([root/defaults/nginx/nginx.conf](root/defaults/nginx/nginx.conf)) on `/goaccess/ws` and `/ttyd/` to prevent passthrough of untrusted upstream `Host` headers when running behind a reverse proxy.

### Fixed

- **First-boot 404 on every endpoint** (nginx/init race): nginx started before the legacy `cont-init.d` script symlinked `/etc/nginx/nginx.conf`, so it loaded Alpine's `http.d/default.conf` "everything returns 404" stub. Fix: ship [root/etc/nginx/nginx.conf](root/etc/nginx/nginx.conf) in the image (first-boot already has the right config), delete `/etc/nginx/http.d/default.conf` at image build, and consolidate init into a proper s6-rc oneshot that blocks nginx via the existing `dependencies.d/init-ransynsrv` edges.
- **Phantom `init-ransynsrv` oneshot**: the `up` file was 0 bytes so `s6-rc-compile` silently dropped the oneshot; any fix added to its `run` script since January (CLAUDE.md default copy, `.cache` chown) was dead code. Fix: populate [root/etc/s6-overlay/s6-rc.d/init-ransynsrv/up](root/etc/s6-overlay/s6-rc.d/init-ransynsrv/up) with the path to `run`, delete the legacy `root/etc/cont-init.d/00-init-ransynsrv` duplicate.
- **`DOCKER_LOGS=true`, `INSTALL_PACKAGES`, `INSTALL_PIP_PACKAGES`, `GOACCESS_AUTH_ENABLED` silently did nothing**: the legacy init script used `#!/bin/sh` which in s6-overlay v3 runs without container env vars. Fix: init is now an s6-rc oneshot with `#!/command/with-contenv sh`, so all env-conditional branches work. Proven live: `mc` installs, logs become stdout symlinks, GoAccess auth applies.
- **`arm64` image contained `x86_64` s6-overlay binaries** because the Dockerfile `ADD`-ed a hardcoded URL. Only worked on Apple Silicon thanks to Rosetta; would fail on any real arm64 Linux host (AWS Graviton, Pi 4/5, Ampere) with `exec format error`. Fix: arch-dispatch in a `RUN` step that picks the matching tarball based on `uname -m`.
- **`arm64` `git-delta` binary was built for glibc** but Alpine uses musl → `delta: not found` at runtime. Fix: change the `aarch64` case from `aarch64-unknown-linux-gnu` to `aarch64-unknown-linux-musl`.
- **ttyd credentials corrupted** when `TTYD_PASSWORD` contained `:`, spaces, or shell metacharacters. The `$AUTH_ARG` variable was interpolated unquoted. Fix: pass `-c "${TTYD_USERNAME}:${TTYD_PASSWORD}"` as a proper argv element via `set --`.
- **GoAccess dashboard WebSocket broken by default**: the fallback `--ws-url` was `ws://\$host:\$port/goaccess/ws` — the shell-escaped `\$` made GoAccess embed the literal string into the rendered HTML. Fix: if `GOACCESS_WS_URL` is unset, print a loud warning and fall back to `ws://localhost/goaccess/ws`. Production deploys should set this explicitly (already documented in `.env.example`).
- **`nginx-reload` shell alias prompted for a password**: sudoers only allowed `/usr/sbin/nginx -t`, not `-s reload`. Fix: broaden the sudoers rule to `/usr/sbin/nginx` (any subcommand). The zshrc aliases (`nginx-test`, `nginx-reload`) now both work non-interactively.
- **PHP-FPM workers had `clear_env = yes` (default)**, so PHP apps couldn't read container env vars via `getenv()`/`$_ENV`. Fix: add `clear_env = no` to the pool config generated by [svc-php-fpm/run](root/etc/s6-overlay/s6-rc.d/svc-php-fpm/run).
- **`PHP_MEMORY_LIMIT`, `PHP_MAX_UPLOAD`, `PHP_MAX_POST`, `PHP_MAX_EXECUTION_TIME` were frozen at image build time** (Dockerfile rendered them into the INI file at `RUN` time). Setting them in `.env`/compose at runtime had no effect. Fix: regenerate `/etc/php84/conf.d/99-ransynsrv.ini` from env on each boot in [svc-php-fpm/run](root/etc/s6-overlay/s6-rc.d/svc-php-fpm/run).
- **nginx `client_max_body_size 100M` vs PHP `post_max_size=50M` asymmetry** caused silent data loss on 50-100 MB uploads. Fix: set nginx `client_max_body_size 50M` to match.
- **CLAUDE.md inaccuracy**: claimed nginx workers run as `abc`; they actually run as `nginx` (Alpine default). Doc updated.
- **`S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0`** (infinite wait) replaced with `60000` so hanging init doesn't silently block forever.
- **`GoAccess` auth toggle is now idempotent**: init writes the auth directives between `# GOACCESS_AUTH_BEGIN` / `# GOACCESS_AUTH_END` markers in the default [nginx.conf](root/defaults/nginx/nginx.conf) so enable/disable is symmetric regardless of surrounding indentation.

### Changed

- **`CLAUDE_CODE_VERSION` bumped** `2.1.12` → `2.1.118` in [Dockerfile](Dockerfile) (latest on npm as of April 2026).
- **`docker-compose.yml`**: dropped the deprecated `version: '3.9'` field; added `mem_limit: 2g`.
- **`docker-compose.deploy.yml`**: `container_name` parameterized to `${COMPOSE_PROJECT_NAME:-ransynsrv}` so multiple instances can coexist on one host.

### Removed

- Retired the bundled `docs/RanSyn_Laravel_AI.md` and `docs/laravel-ai-stack.md` reference guides (prior commit).
- Deleted legacy `root/etc/cont-init.d/00-init-ransynsrv` (replaced by the s6-rc oneshot).
- Deleted empty legacy directories `_docs/`, `ransynsrv/`, `logs/`.

### Notes

- **Backward compatibility**: existing deployments that previously customized `/data/nginx/nginx.conf` will keep their file (init only copies defaults when missing). The new `# GOACCESS_AUTH_BEGIN` / `# GOACCESS_AUTH_END` markers only exist in the shipped default; customized user configs won't get the marker-based auth toggle retrofit, so the sed is silently skipped rather than risking malformed edits. If you want the new toggle, diff your `/data/nginx/nginx.conf` against `root/defaults/nginx/nginx.conf` and backport the markers manually.
- **Known gap**: GoAccess tarball download in the Dockerfile still lacks a `sha256sum` pin (tracked separately from this change set).
