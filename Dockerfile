# syntax=docker/dockerfile:1.4
# Unshackle-Docker
# https://github.com/Kryxan/Unshackle-docker
#
# This repository contains a standalone copy of the `Dockerfile` used to
# build an Unshackle image with the Unshackle UI. The Unshackle UI is
# currently in development and does not work in it's current state. I
# have created a modified version and this Dockerfile references that
# sorta works, but required some modifications to the backend Unshackle.
# Due to unforseen consequences of those changes, I am not including my
# changes to the Unshackle source. 
#
#Notes & usage:
#- The Dockerfile uses build ARGs to reference the Unshackle sources:
#  - `UNSHACKLE_BRANCH` (default: `main`)
#  - `UNSHACKLE_SOURCE` (default: `https://github.com/unshackle-dl/unshackle`)
#  - `UI_BRANCH` / `UI_SOURCE` for the web UI
#
#- The Dockerfile depends on Debian `slim-trixie` packages and some
# `non-free` driver components. I'm running this on a system with a
# single integrated intel gpu. Edit the dockerfile or ommit the the
# drivers if you do not need/want them.

# Single-stage Dockerfile integrating official unshackle CLI and UI using Debian slim-trixie
# Configuration variables
# Build the main unshackle CLI application using Debian slim-trixie

# syntax for BuildKit features (cache mounts)
# requires Docker BuildKit; e.g. `DOCKER_BUILDKIT=1 docker build .`
FROM python:slim-trixie

# declare ARG variables after FROM
ARG UNSHACKLE_BRANCH=main
ARG UNSHACKLE_SOURCE=https://github.com/unshackle-dl/unshackle

ARG UI_BRANCH=main
# unshackle UI is currently broken
# ARG UI_SOURCE=https://github.com/unshackle-dl/unshackle-ui
# Use a modified UI source that more or less works with the current unshackle backend
ARG UI_SOURCE=https://github.com/Kryxan/unshackle-ui

# GPU driver repositories (multi-GPU + WSL2 aware)
# "intel nvidia amd" or "intel nvidia" or "intel" or "" (none)
# Default "intel" is safe for all systems (harmless if no Intel GPU present)
ARG GPUSUPPORT="intel"

# Add container metadata
LABEL org.opencontainers.image.description="Docker image for Unshackle CLI and Web UI with all required dependencies"
LABEL org.opencontainers.image.source="${UNSHACKLE_SOURCE}"
LABEL unshackle.branch="${UNSHACKLE_BRANCH}"

WORKDIR /tmp

# Environment variables
ENV UV_CACHE_DIR=/app/cache/uv \
    NODE_ENV=production

# Ensure /opt/bin is on PATH so installed tools are found by scripts
ENV PATH=/opt/bin:$PATH

# FFmpeg hardware acceleration defaults
# VAAPI: Intel/AMD GPU acceleration (safe fallback, auto-detects if unavailable)
ENV LIBVA_DRIVER_NAME=iHD \
    LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri

# Create directories just to be sure they exist
RUN mkdir -p /app/binaries /opt/bin || true;

# Install minimal tools required to add external apt repositories (curl/gpg)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl gnupg dirmngr ca-certificates \
    && rm -rf /var/lib/apt/lists/*


# Ensure existing debian.sources components lines include contrib/non-free components
RUN set -eux; \
    # Ensure apt list files include contrib/non-free components where appropriate
    for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.{list,sources}; do \
        [ -f "$f" ] || continue; \
        case "$f" in \
            *.sources) \
                if ! grep -qEi '^Components:.*\\bcontrib\\b' "$f"; then \
                    sed -ri 's/^(Components:[[:space:]]*)(.*main.*)$/\1\2 contrib non-free non-free-firmware/' "$f" || true; \
                fi; \
                ;; \
            *) \
                awk '/^deb/ && /debian/ && $0 !~ /contrib/ {print $0 " contrib non-free non-free-firmware"; next} {print}' "$f" > "$f.tmp" && mv "$f.tmp" "$f" || true; \
                ;; \
        esac; \
    done
# Add GPU driver repositories based on selected GPUSUPPORT build ARG
RUN set -eux; \
    if grep -qi microsoft /proc/version; then \
        echo "WSL2 detected: skipping kernel driver repos, only user-space libs will be installed later"; \
    else \
        for gpu in $GPUSUPPORT; do \
            case "$gpu" in \
                nvidia) echo "Adding NVIDIA CUDA repository..."; \
                    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/3bf863cc.pub \
                        | gpg --dearmor -o /usr/share/keyrings/nvidia.gpg; \
                    printf "Types: deb\nURIs: https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/\nSuites: /\nComponents: \nArchitectures: amd64\nSigned-By: /usr/share/keyrings/nvidia.gpg\n" \
                        > /etc/apt/sources.list.d/nvidia-cuda.sources ;; \
                amd) echo "Adding AMD ROCm repository..."; \
                    curl -fsSL https://repo.radeon.com/rocm/rocm.gpg.key \
                        | gpg --dearmor -o /usr/share/keyrings/rocm.gpg; \
                    printf "Types: deb\nURIs: https://repo.radeon.com/rocm/apt/debian/\nSuites: jammy\nComponents: main\nArchitectures: amd64\nSigned-By: /usr/share/keyrings/rocm.gpg\n" \
                        > /etc/apt/sources.list.d/rocm.sources ;; \
                *) echo "Unknown GPU type: $gpu" ;; \
            esac; \
        done; \
    fi


# Add Jellyfin repository for jellyfin-ffmpeg7 package
RUN curl -fsSL https://repo.jellyfin.org/debian/jellyfin_team.gpg.key \
        | gpg --dearmor -o /usr/share/keyrings/jellyfin.gpg; \
    printf "Types: deb\nURIs: https://repo.jellyfin.org/debian\nSuites: trixie\nComponents: main\nArchitectures: amd64\nSigned-By: /usr/share/keyrings/jellyfin.gpg\n" \
        > /etc/apt/sources.list.d/jellyfin.sources

# Add Caddy repository (needed before apt install) and other third-party keys
RUN set -eux; \
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg || true; \
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' > /etc/apt/sources.list.d/caddy-stable.list || true

# Consolidated apt install with BuildKit cache mounts for faster iterative builds
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    set -eux; \
    apt-get update && apt-get upgrade -y; \
    apt-get install -y --no-install-recommends \
        nano iputils-ping wget git build-essential cmake pkg-config \
        bash supervisor grc nodejs npm unzip fastfetch jq \
        jellyfin-ffmpeg7 aria2 mediainfo mkvtoolnix mpv nginx openssl caddy

# Bento4 (mp4decrypt) - download official zip, map bin/ to /opt/bin/, keep rest under /opt/bento4/
RUN set -eux; \
    MP4_URL="https://www.bok.net/Bento4/binaries/Bento4-SDK-1-6-0-641.x86_64-unknown-linux.zip"; \
    echo "Downloading Bento4 from $MP4_URL"; \
    wget -qO /tmp/bento4.zip "$MP4_URL" || true; \
    mkdir -p /tmp/bento4 && unzip -q /tmp/bento4.zip -d /tmp/bento4 || true; \
    BENTO_DIR=/tmp/bento4/Bento4-SDK-1-6-0-641.x86_64-unknown-linux; \
    if [ -d "$BENTO_DIR" ]; then \
        mkdir -p /opt/bento4; \
        mv "$BENTO_DIR/bin"/* /opt/bin/ 2>/dev/null || true; \
        mv "$BENTO_DIR/utils"/* /opt/bin/ 2>/dev/null || true; \
        mv "$BENTO_DIR"/* /opt/bento4/ 2>/dev/null || true; \
    fi; \
    rm -rf /tmp/bento4 /tmp/bento4.zip || true;

# dovi_tool
RUN set -eux; \
    DOVI_URL=$(curl -s https://api.github.com/repos/quietvoid/dovi_tool/releases/latest \
        | jq -r '.assets[] | select(.browser_download_url | test("x86_64-unknown-linux")) | .browser_download_url' \
        | head -n1); \
    echo "DOVI URL: $DOVI_URL"; \
    if [ -n "$DOVI_URL" ]; then \
        wget -qO /tmp/dovi.tgz "$DOVI_URL" && \
        mkdir -p /tmp/dovi && \
        tar -xzf /tmp/dovi.tgz -C /tmp/dovi; \
        find /tmp/dovi -type f -perm /111 -exec cp -v {} /opt/bin/ \;; \
        rm -f /tmp/dovi.tgz; \
    fi;

# hdr10plus_tool
RUN set -eux; \
    HDR10P_URL=$(curl -s https://api.github.com/repos/quietvoid/hdr10plus_tool/releases/latest \
        | jq -r '.assets[] | select(.browser_download_url | test("x86_64-unknown-linux")) | .browser_download_url' \
        | head -n1); \
    echo "HDR10P URL: $HDR10P_URL"; \
    if [ -n "$HDR10P_URL" ]; then \
        wget -qO /tmp/hdr10p.tgz "$HDR10P_URL" && \
        mkdir -p /tmp/hdr10p && \
        tar -xzf /tmp/hdr10p.tgz -C /tmp/hdr10p; \
        find /tmp/hdr10p -type f -perm /111 -exec cp -v {} /opt/bin/ \;; \
        rm -f /tmp/hdr10p.tgz; \
    fi;

# N_m3u8DL-RE
RUN set -eux; \
    N3_URL=$(curl -s https://api.github.com/repos/nilaoda/N_m3u8DL-RE/releases/latest \
        | jq -r '.assets[] | select(.browser_download_url | test("linux-musl-x64")) | .browser_download_url' \
        | head -n1); \
    echo "N3 URL: $N3_URL"; \
    if [ -n "$N3_URL" ]; then \
        wget -qO /tmp/n3.tgz "$N3_URL" && \
        mkdir -p /tmp/n3 && \
        tar -xzf /tmp/n3.tgz -C /tmp/n3; \
        find /tmp/n3 -type f -perm /111 -exec cp -v {} /opt/bin/ \;; \
        rm -f /tmp/n3.tgz; \
    fi;

# shaka-packager (single binary asset)
RUN set -eux; \
    SH_URL=$(curl -s https://api.github.com/repos/shaka-project/shaka-packager/releases/latest \
        | jq -r '.assets[] | select(.browser_download_url | test("packager-linux-x64")) | .browser_download_url' \
        | head -n1); \
    echo "SHAKA URL: $SH_URL"; \
    if [ -n "$SH_URL" ]; then \
        wget -qO /opt/bin/packager "$SH_URL" && chmod +x /opt/bin/packager; \
    fi

# hola-proxy (single binary asset)
RUN set -eux; \
    HOLA_URL=$(curl -s https://api.github.com/repos/Snawoot/hola-proxy/releases/latest \
        | jq -r '.assets[] | select(.browser_download_url | test("linux-amd64")) | .browser_download_url' \
        | head -n1); \
    echo "HOLA URL: $HOLA_URL"; \
    if [ -n "$HOLA_URL" ]; then \
        wget -qO /opt/bin/hola-proxy "$HOLA_URL" && chmod +x /opt/bin/hola-proxy; \
    fi

# CCExtractor: ffmpeg wrapper for extracting CEA-608 closed captions
COPY docker-files/ccextractor-wrapper.py /opt/bin/ccextractor-wrapper.py
COPY docker-files/ccextractor /opt/bin/ccextractor
RUN chmod +x /opt/bin/ccextractor

#
# GPU driver dependencies (if selected)
#
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    set -eux; \
    if grep -qi microsoft /proc/version; then \
        echo "WSL2 detected: installing only user-space libraries"; \
        apt-get update; \
        for gpu in $GPUSUPPORT; do \
            case "$gpu" in \
                intel) apt-get install -y --no-install-recommends \
                    libva2 libva-drm2 libva-x11-2 libdrm2 vainfo ;; \
                nvidia) echo "WSL2: NVIDIA drivers managed by host, skipping toolkit install" ;; \
                amd) apt-get install -y --no-install-recommends \
                    mesa-vulkan-drivers ;; \
            esac; \
        done; \
    else \
        apt-get update; \
        for gpu in $GPUSUPPORT; do \
            case "$gpu" in \
                intel) apt-get install -y --no-install-recommends \
                    libva2 libva-drm2 libva-x11-2 libdrm2 vainfo \
                    intel-media-va-driver-non-free i965-va-driver-shaders mesa-va-drivers \
                    firmware-intel-graphics ;; \
                nvidia) apt-get install -y --no-install-recommends \
                    nvidia-driver nvidia-driver-libs nvidia-container-toolkit ;; \
                amd) apt-get install -y --no-install-recommends \
                    mesa-vulkan-drivers rocminfo firmware-amd-graphics ;; \
            esac; \
        done; \
    fi


# Configure grc and create wrapper scripts for interactive and non-interactive use
RUN set -eux; \
    if [ -f /etc/default/grc ]; then \
        grep -q '^GRC_ALIASES=true' /etc/default/grc || \
        sed -ri 's/^GRC_ALIASES=.*/GRC_ALIASES=true/' /etc/default/grc || \
        echo 'GRC_ALIASES=true' >> /etc/default/grc; \
    fi
# Set the startup command and default interactive shell preferences
# Use a single-quoted heredoc so nothing is expanded during build
RUN set -eux; \
    mkdir -p /root; \
    cat > /root/.bashrc <<'BASHRC'
# Extract project name and version from pyproject.toml for prompt
if [ -f /app/pyproject.toml ]; then
    PROJECT_NAME=$(grep '^name = ' /app/pyproject.toml | sed 's/name = "\(.*\)"/\1/' 2>/dev/null || echo "unshackle")
    PROJECT_VERSION=$(grep '^version = ' /app/pyproject.toml | sed 's/version = "\(.*\)"/\1/' 2>/dev/null || echo "unknown")
    PS1='\n${debian_chroot:+($debian_chroot)}\[\033[01;32m\]'"$PROJECT_NAME"' (\[\033[01;33m\]'"$PROJECT_VERSION"'\[\033[01;32m\])\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='\n${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
fi

export LS_OPTIONS='--color=auto'
eval "$(dircolors)"
alias ls='ls $LS_OPTIONS'
alias ll='ls $LS_OPTIONS -l'
alias l='ls $LS_OPTIONS -lA'

# Load grc if available
[[ -s "/etc/profile.d/grc.sh" ]] && source /etc/profile.d/grc.sh

# Show a fastfetch summary only for interactive shells and when fastfetch exists
if [ -t 1 ] && command -v fastfetch >/dev/null 2>&1; then
    fastfetch --logo /opt/logo.txt || true
fi
BASHRC
RUN set -eux; sed -i 's/\r$//' /root/.bashrc; cp /root/.bashrc /etc/skel/.bashrc || true


COPY docker-files/subtitleedit-wrapper.py /opt/bin/subtitleedit-wrapper.py
COPY docker-files/subtitleedit /opt/bin/subtitleedit
COPY docker-files/unshackle /opt/bin/unshackle
COPY docker-files/dl /opt/bin/dl
COPY docker-files/start.sh /usr/local/bin/start.sh
COPY docker-files/nginx-default.conf /etc/nginx/sites-available/default
COPY docker-files/supervisor-unshackle.conf /etc/supervisor/conf.d/unshackle.conf
COPY docker-files/supervisord.conf /etc/supervisord.conf
COPY docker-files/healthcheck.sh /etc/healthcheck.sh
COPY docker-files/logo.txt /opt/logo.txt
COPY docker-files/check-gpu.sh /opt/bin/check-gpu.sh
COPY docker-files/unshackle-update.sh /opt/bin/unshackle-update.sh


RUN set -eux; \
    # normalize line endings for text files only (scripts), ensure executables are runnable, create symlinks
    for f in /opt/bin/*; do \
        [ -f "$f" ] || continue; \
        chmod +x "$f" 2>/dev/null || true; \
        # Only normalize line endings for text files (check for shebang or .py/.sh extension)
        if head -n1 "$f" 2>/dev/null | grep -q '^#!'; then \
            sed -i 's/\r$//' "$f" 2>/dev/null || true; \
        elif echo "$f" | grep -qE '\.(py|sh|bash)$'; then \
            sed -i 's/\r$//' "$f" 2>/dev/null || true; \
        fi; \
        ln -sf "$f" /usr/local/bin/$(basename "$f") || true; \
        ln -sf "$f" /app/binaries/$(basename "$f") || true; \
    done; \
    # Symlink jellyfin-ffmpeg binaries to standard locations
    ln -sf /usr/lib/jellyfin-ffmpeg/ffmpeg /usr/local/bin/ffmpeg; \
    ln -sf /usr/lib/jellyfin-ffmpeg/ffprobe /usr/local/bin/ffprobe; \
    ln -sf /usr/lib/jellyfin-ffmpeg/ffplay /usr/local/bin/ffplay; \
    # Create capitalized SubtitleEdit symlink for Unshackle compatibility
    ln -sf /opt/bin/subtitleedit /opt/bin/SubtitleEdit; \
    ln -sf /opt/bin/SubtitleEdit /usr/local/bin/SubtitleEdit; \
    ln -sf /opt/bin/SubtitleEdit /app/binaries/SubtitleEdit

# All tools in /opt/bin (including Bento4) are already symlinked by the previous RUN command

#
# Unshackle CLI configuration
#


# Set working directory
WORKDIR /app

# Install uv and subtitle-related Python packages (use BuildKit pip cache)
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir uv pysubs2 pycaption ffsubsync || true

# Download Unshackle using update script (skip UI build for now)
RUN SKIP_UI_BUILD=true /opt/bin/unshackle-update.sh

# Install dependencies with uv
RUN uv sync --frozen
RUN uv add isodate subby webvtt-py

# Verify unshackle installation
RUN uv run unshackle env check || true

#
# Unshackle UI Build and Integration
#
# Set up environment variables for UI (before running update script)
RUN set -eux; \
    UNSHACKLE_API_KEY=$(openssl rand -hex 32) && \
    mkdir -p /app/unshackle-ui && \
    echo "# Unshackle API Configuration" > /app/unshackle-ui/.env.production && \
    echo "# Generated during Docker build" >> /app/unshackle-ui/.env.production && \
    echo "VITE_UNSHACKLE_API_URL==http://localhost:8888" >> /app/unshackle-ui/.env.production && \
    echo "VITE_UNSHACKLE_API_KEY=$UNSHACKLE_API_KEY" >> /app/unshackle-ui/.env.production && \
    echo "UNSHACKLE_API_KEY=$UNSHACKLE_API_KEY" > /app/.env && \
    echo "# TMDB API Configuration" >> /app/.env && \
    echo "TMDB_API_KEY=" >> /app/.env && \
    echo "VITE_TMDB_API_KEY=" >> /app/unshackle-ui/.env.production && \
    echo "VITE_TMDB_BASE_URL=https://api.themoviedb.org/3" >> /app/unshackle-ui/.env.production && \
    echo "VITE_TMDB_IMAGE_BASE=https://image.tmdb.org/t/p/w500" >> /app/unshackle-ui/.env.production && \
    echo "# Application Configuration" >> /app/unshackle-ui/.env.production && \
    echo "VITE_APP_NAME=Unshackle UI" >> /app/unshackle-ui/.env.production && \
    echo "VITE_APP_ENV=production" >> /app/unshackle-ui/.env.production && \
    echo "# Development Configuration (optional)" >> /app/unshackle-ui/.env.production && \
    echo "VITE_DEBUG=false" >> /app/unshackle-ui/.env.production && \
    echo "VITE_LOG_LEVEL=error" >> /app/unshackle-ui/.env.production && \
    echo "VITE_DEBUG_API=false" >> /app/unshackle-ui/.env.production

# Run update script to download UI and build it
RUN --mount=type=cache,target=/root/.npm,sharing=locked \
    /opt/bin/unshackle-update.sh



# Expose ports for Unshackle UI (80) and API (8888)
EXPOSE 80 8888

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s CMD /etc/healthcheck.sh


CMD ["bash", "/usr/local/bin/start.sh"]
