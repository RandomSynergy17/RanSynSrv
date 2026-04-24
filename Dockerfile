# ==============================================================================
# RanSynSrv
# ==============================================================================
# Alpine 3.21 | Nginx | PHP 8.4 | GoAccess Analytics | Claude Code | Dev Tools
# Integrates: stdout-logs, package-install, nvm functionality
# Designed to run behind a reverse proxy (HTTP only)
# ==============================================================================

FROM alpine:3.21

ARG IMAGE_VERSION=1.1.0

LABEL maintainer="Randolph <randolph@randomsynergy.com>"
LABEL org.opencontainers.image.title="RanSynSrv"
LABEL org.opencontainers.image.description="Nginx + PHP 8.4 + GoAccess + Claude Code + optional pgvector AI sidecar"
LABEL org.opencontainers.image.source="https://github.com/RandomSynergy17/RanSynSrv"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.version="${IMAGE_VERSION}"

# ==============================================================================
# BUILD ARGUMENTS
# ==============================================================================
ARG PUID=1000
ARG PGID=1000
ARG TZ=Asia/Dubai
ARG S6_OVERLAY_VERSION=3.2.0.3
ARG GOACCESS_VERSION=1.9.4
ARG NVM_VERSION=0.40.3
ARG CLAUDE_CODE_VERSION=2.1.118

# ==============================================================================
# ENVIRONMENT VARIABLES
# ==============================================================================
ENV TZ=${TZ} \
    PUID=${PUID} \
    PGID=${PGID} \
    # s6-overlay
    S6_CMD_WAIT_FOR_SERVICES_MAXTIME=60000 \
    S6_VERBOSITY=1 \
    # PHP
    PHP_MEMORY_LIMIT=256M \
    PHP_MAX_UPLOAD=50M \
    PHP_MAX_POST=50M \
    PHP_MAX_EXECUTION_TIME=300 \
    # GoAccess
    GOACCESS_ENABLED=true \
    GOACCESS_WS_URL="" \
    # ttyd Web Terminal (TTYD_USERNAME / TTYD_PASSWORD are injected at runtime
    # via compose environment; not declared here to avoid leaking their names
    # into docker image manifests — shell `-n` guards in svc-ttyd/run treat
    # unset and empty-string identically)
    TTYD_ENABLED=false \
    # Shell
    SHELL=/bin/zsh \
    EDITOR=nano \
    VISUAL=nano \
    # Python
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    # Node.js / NVM
    NVM_DIR=/usr/local/share/nvm \
    NPM_CONFIG_PREFIX=/usr/local/share/npm-global \
    # Runtime package install (universal-package-install mod)
    INSTALL_PACKAGES="" \
    INSTALL_PIP_PACKAGES="" \
    # stdout-logs (set to true to redirect logs to Docker)
    DOCKER_LOGS=false \
    # Container identification
    DEVCONTAINER=true

# Path includes NVM and npm global
ENV PATH="/usr/local/share/npm-global/bin:${NVM_DIR}/versions/node/default/bin:${PATH}"

# ==============================================================================
# INSTALL S6-OVERLAY (Process Supervisor) — arch-aware
# ==============================================================================
# The s6-overlay arch-specific tarball must match the image arch. Using `ADD`
# with a hardcoded URL baked x86_64 binaries into arm64 images; we dispatch at
# build time based on uname -m so both linux/amd64 and linux/arm64 work natively.
RUN set -e && \
    ARCH=$(uname -m) && \
    case "$ARCH" in \
        x86_64)  S6_ARCH=x86_64 ;; \
        aarch64) S6_ARCH=aarch64 ;; \
        *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac && \
    cd /tmp && \
    wget -q "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" && \
    wget -q "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz" && \
    wget -q "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz.sha256" && \
    wget -q "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz.sha256" && \
    sha256sum -c s6-overlay-noarch.tar.xz.sha256 && \
    sha256sum -c s6-overlay-${S6_ARCH}.tar.xz.sha256 && \
    tar -C / -Jxpf s6-overlay-noarch.tar.xz && \
    tar -C / -Jxpf s6-overlay-${S6_ARCH}.tar.xz && \
    rm -f s6-overlay-*.tar.xz*

# ==============================================================================
# INSTALL SYSTEM PACKAGES
# ==============================================================================
RUN apk update && apk upgrade && \
    \
    # ========== CORE SYSTEM ==========
    apk add --no-cache \
        shadow \
        tzdata \
        bash \
        bash-completion \
        zsh \
        zsh-vcs \
        coreutils \
        findutils \
        grep \
        sed \
        gawk \
        util-linux \
        zip \
        unzip \
        xz \
        bzip2 \
        gzip \
        tar \
        nano \
        vim \
        procps \
        htop \
        curl \
        wget \
        bind-tools \
        iputils \
        iproute2 \
        iptables \
        ipset \
        ca-certificates \
        openssl \
        jq \
        yq \
        tree \
        file \
        less \
        sudo \
        libcap \
        libcap-utils \
        man-pages \
        mandoc \
    && \
    \
    # ========== NGINX ==========
    apk add --no-cache \
        nginx \
        nginx-mod-http-brotli \
        nginx-mod-http-headers-more \
        nginx-mod-http-fancyindex \
        nginx-mod-http-image-filter \
    && \
    \
    # ========== PHP 8.4 ==========
    apk add --no-cache \
        php84 \
        php84-fpm \
        php84-bcmath \
        php84-bz2 \
        php84-calendar \
        php84-ctype \
        php84-curl \
        php84-dom \
        php84-exif \
        php84-fileinfo \
        php84-ftp \
        php84-gd \
        php84-gettext \
        php84-gmp \
        php84-iconv \
        php84-imap \
        php84-intl \
        php84-ldap \
        php84-mbstring \
        php84-mysqli \
        php84-mysqlnd \
        php84-opcache \
        php84-openssl \
        php84-pcntl \
        php84-pdo \
        php84-pdo_mysql \
        php84-pdo_pgsql \
        php84-pdo_sqlite \
        php84-pgsql \
        php84-phar \
        php84-posix \
        php84-session \
        php84-simplexml \
        php84-soap \
        php84-sockets \
        php84-sodium \
        php84-sqlite3 \
        php84-tokenizer \
        php84-xml \
        php84-xmlreader \
        php84-xmlwriter \
        php84-xsl \
        php84-zip \
        php84-zlib \
        php84-pecl-apcu \
        php84-pecl-igbinary \
        php84-pecl-redis \
    && \
    ln -sf /usr/bin/php84 /usr/bin/php && \
    ln -sf /usr/sbin/php-fpm84 /usr/sbin/php-fpm && \
    \
    # ========== PYTHON 3 ==========
    apk add --no-cache \
        python3 \
        py3-pip \
        py3-setuptools \
        py3-wheel \
        py3-virtualenv \
        py3-cryptography \
        py3-openssl \
        py3-requests \
        py3-yaml \
        py3-jinja2 \
    && \
    \
    # ========== NODE.JS ==========
    apk add --no-cache \
        nodejs \
        npm \
        yarn \
        libgcc \
        libstdc++ \
    && \
    mkdir -p /usr/local/share/npm-global && \
    \
    # ========== DEVELOPMENT TOOLS ==========
    apk add --no-cache \
        git \
        git-lfs \
        git-perl \
        github-cli \
        delta \
        fzf \
        ripgrep \
        rsync \
        rclone \
        openssh-client \
        openssh-keygen \
        sshpass \
        ffmpeg \
        'imagemagick>=7.1.1.13-r0' \
        graphicsmagick \
        sqlite \
        sqlite-libs \
        mariadb-client \
        postgresql-client \
        redis \
        leveldb \
        snappy \
        perl \
        bc \
        ttyd \
    && \
    \
    # ========== BUILD DEPENDENCIES ==========
    apk add --no-cache --virtual .build-deps \
        build-base \
        autoconf \
        automake \
        ncurses-dev \
        libmaxminddb-dev \
        geoip-dev \
        gettext-dev \
        openssl-dev \
        leveldb-dev \
        snappy-dev \
        libffi-dev \
        python3-dev \
    && \
    \
    # ========== GOACCESS RUNTIME DEPS ==========
    apk add --no-cache \
        ncurses \
        libmaxminddb \
        gettext \
    && \
    \
    # ========== BUILD GOACCESS ==========
    cd /tmp && \
    set -e && \
    wget -q "https://tar.goaccess.io/goaccess-${GOACCESS_VERSION}.tar.gz" && \
    tar -xzf "goaccess-${GOACCESS_VERSION}.tar.gz" && \
    cd "goaccess-${GOACCESS_VERSION}" && \
    ./configure --enable-utf8 --enable-geoip=mmdb --with-openssl && \
    make && make install && \
    cd / && rm -rf /tmp/goaccess* && \
    \
    # ========== PYTHON PACKAGES ==========
    pip3 install --no-cache-dir \
        plyvel==1.5.1 \
        python-snappy==0.7.3 \
        httpie==3.2.4 \
        glances==4.2.0 \
    && \
    \
    # ========== CLEANUP BUILD DEPS ==========
    apk del .build-deps && \
    \
    # ========== SET TIMEZONE ==========
    ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && \
    echo "${TZ}" > /etc/timezone && \
    \
    # ========== FINAL CLEANUP ==========
    rm -rf /var/cache/apk/* /tmp/* /root/.cache

# ==============================================================================
# INSTALL NVM (Node Version Manager)
# ==============================================================================
RUN mkdir -p ${NVM_DIR} && \
    wget -O /tmp/nvm-install.sh "https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh" && \
    # sha256 is specific to NVM_VERSION=0.40.3 — update this line when bumping
    # NVM_VERSION or the build will correctly fail with a checksum mismatch.
    echo "2d8359a64a3cb07c02389ad88ceecd43f2fa469c06104f92f98df5b6f315275f  /tmp/nvm-install.sh" | sha256sum -c - && \
    bash /tmp/nvm-install.sh && \
    rm -f /tmp/nvm-install.sh

# ==============================================================================
# CREATE USER AND DIRECTORIES
# ==============================================================================
RUN addgroup -g ${PGID} abc && \
    adduser -D -u ${PUID} -G abc -s /bin/zsh abc && \
    addgroup abc wheel && \
    \
    mkdir -p \
        /data/nginx \
        /data/webroot/public_html \
        /data/webroot/goaccess \
        /data/databases \
        /data/log/nginx \
        /data/log/php \
        /data/ssh \
        /data/scripts \
        /data/crontabs \
        /data/claude/.claude \
        /data/commandhistory \
        /defaults \
        /run/nginx \
        /run/php \
        /workspace \
    && \
    chown -R abc:abc /data /defaults /run/nginx /run/php \
        /workspace ${NVM_DIR} /usr/local/share/npm-global && \
    chmod 700 /data/ssh && \
    ln -sf /data/claude/.claude /home/abc/.claude && \
    \
    # Narrow to only the two subcommands the zshrc aliases use — stops an
    # abc-running process from doing `sudo nginx -c attacker.conf` and loading
    # an arbitrary config as root. (Under compose's no-new-privileges this is
    # already blocked, but belt-and-braces for `docker run` invocations.)
    printf '%s\n%s\n' \
        "abc ALL=(root) NOPASSWD: /usr/sbin/nginx -t" \
        "abc ALL=(root) NOPASSWD: /usr/sbin/nginx -s reload" \
        >> /etc/sudoers.d/abc && \
    chmod 0440 /etc/sudoers.d/abc && \
    \
    setcap cap_net_raw+p /bin/ping 2>/dev/null || true

# ==============================================================================
# INSTALL CLAUDE CODE CLI
# ==============================================================================
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} && \
    chown -R abc:abc /usr/local/share/npm-global

# ==============================================================================
# SETUP ZSH FOR ABC USER
# ==============================================================================
USER abc
WORKDIR /home/abc
RUN sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended && \
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.oh-my-zsh/custom/themes/powerlevel10k && \
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions && \
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting && \
    git clone --depth=1 https://github.com/zsh-users/zsh-completions ~/.oh-my-zsh/custom/plugins/zsh-completions && \
    printf '%s\n' \
        '# RanSynSrv - Environment for login shells (runs AFTER /etc/profile)' \
        'export PATH="/usr/local/share/npm-global/bin:${PATH}"' \
        'export NVM_DIR="/usr/local/share/nvm"' \
        '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' \
        > ~/.zprofile && \
    cat > ~/.zshrc << 'EOF'
# RanSynSrv - Zsh Configuration
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
plugins=(git docker docker-compose node npm fzf rsync sudo zsh-autosuggestions zsh-syntax-highlighting zsh-completions)
source $ZSH/oh-my-zsh.sh

# Environment
export LANG=en_US.UTF-8
export EDITOR='nano'
export VISUAL='nano'
export PATH="${PATH}:/usr/local/share/npm-global/bin"
export GIT_PAGER='delta'

# NVM
export NVM_DIR="/usr/local/share/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias nginx-test='sudo nginx -t'
alias nginx-reload='sudo nginx -s reload'
alias logs='tail -f /data/log/nginx/access.log'
alias errors='tail -f /data/log/nginx/error.log'
alias phplogs='tail -f /data/log/php/error.log'
alias cc='claude'

# History
HISTFILE=/data/commandhistory/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt appendhistory sharehistory hist_ignore_dups hist_ignore_space

# FZF
[ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh
[ -f /usr/share/fzf/completion.zsh ] && source /usr/share/fzf/completion.zsh

# Start in /data directory
cd /data 2>/dev/null || true
EOF
USER root

# ==============================================================================
# COPY CONFIGURATION FILES
# ==============================================================================
# Files land root-owned. The `abc` runtime user must NOT be able to overwrite
# supervisor scripts under /etc/s6-overlay/s6-rc.d/*/run — those run as root on
# every boot, so writable-by-abc would be a privilege-escalation path from any
# PHP RCE. We selectively re-chown only the trees that legitimately need to be
# abc-owned (defaults/ is read by init's cp; /etc/nginx/ the init symlinks).
COPY root/ /
RUN chown -R abc:abc /defaults && \
    rm -f /etc/nginx/http.d/default.conf

# ==============================================================================
# PHP CONFIGURATION
# ==============================================================================
# Ensure the conf.d directory exists; svc-php-fpm/run regenerates
# /etc/php84/conf.d/99-ransynsrv.ini at each boot from current env vars so
# PHP_MEMORY_LIMIT, PHP_MAX_UPLOAD, etc. are actually runtime-configurable.
RUN mkdir -p /etc/php84/conf.d

# ==============================================================================
# FINALIZE
# ==============================================================================
VOLUME /data
# Only the HTTP port is exposed. GoAccess WebSocket (7890) and ttyd (7681) are
# internal and only reachable via the nginx proxy at /goaccess/ws and /ttyd/.
# Declaring them here made `docker run -P` publish them directly, bypassing the
# nginx-level auth and access controls.
EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD wget -qO- http://127.0.0.1/health || exit 1

ENTRYPOINT ["/init"]
