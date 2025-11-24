# docker-unshackle
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

FROM python:slim-trixie

# declare ARG variables after FROM
ARG UNSHACKLE_BRANCH=main
ARG UNSHACKLE_SOURCE=https://github.com/unshackle-dl/unshackle
ARG UI_BRANCH=main
# unshackle UI is currently broken
#ARG UI_SOURCE=https://github.com/unshackle-dl/unshackle-ui
# Use a modified UI source that more or less works with the current unshackle backend
ARG UI_SOURCE=https://github.com/Kryxan/unshackle-ui

# Set environment variables to reduce image size
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_CACHE_DIR=/tmp/uv-cache

# Add container metadata
LABEL org.opencontainers.image.description="Docker image for Unshackle CLI and Web UI with all required dependencies"
LABEL org.opencontainers.image.source="${UNSHACKLE_SOURCE}"
LABEL unshackle.branch="${UNSHACKLE_BRANCH}"

# Install base dependencies (Debian packages) including Node.js
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        nano \
        iputils-ping \
        wget \
        gnupg \
        git \
        curl \
        build-essential \
        cmake \
        pkg-config \
        bash \
        nginx \
        supervisor \
        grc \
        nodejs \
        npm \
        openssl \
    && rm -rf /var/lib/apt/lists/*

# Install media processing dependencies (Debian packages)
# Ensure existing apt source lines include contrib/non-free components
# (avoid adding duplicate 'deb' entries which trigger warnings).
# Enable non-free repos for drivers that live in non-free (intel-media drivers etc.)
#RUN echo "deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware" > /etc/apt/sources.list.d/nonfree.list \
# && echo "deb http://deb.debian.org/debian-security trixie-security main contrib non-free non-free-firmware" >> /etc/apt/sources.list.d/nonfree.list \
# && echo "deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware" >> /etc/apt/sources.list.d/nonfree.list
RUN set -eux; \
    for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.{list,sources}; do \
        [ -f "$f" ] || continue; \
        case "$f" in \
            *.sources) \
                # For .sources files, append components on the 'Components:' line if missing
                if ! grep -qEi '^Components:.*\bcontrib\b' "$f"; then \
                    sed -ri 's/^(Components:[[:space:]]*)(.*main.*)$/\1\2 contrib non-free non-free-firmware/' "$f" || true; \
                fi; \
                ;; \
            *) \
                # For legacy .list files, append components to 'deb' lines when missing
                awk '/^deb/ && /debian/ && $0 !~ /contrib/ {print $0 " contrib non-free non-free-firmware"; next} {print}' "$f" > "$f.tmp" && mv "$f.tmp" "$f" || true; \
                ;; \
        esac; \
    done




    
# NOTE: The following VA-API / userspace driver packages are targeted for
# Intel integrated GPUs to improve ffmpeg hardware acceleration. If you need
# NVIDIA or AMD GPU support, uncomment/add the appropriate packages below
# instead (NVIDIA typically requires the proprietary driver + nvidia-container-toolkit,
# AMD may need mesa packages or ROCm components):
# # NVIDIA (example placeholder):
# # && apt-get install -y --no-install-recommends nvidia-driver nvidia-container-toolkit \
# # AMD (example placeholder):
# # && apt-get install -y --no-install-recommends mesa-vulkan-drivers rocminfo \
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ffmpeg \
        aria2 \
        mediainfo \
        mkvtoolnix \
        # VA-API / userspace driver libs and tools (Intel integrated GPU)
        libva2 \
        libva-drm2 \
        libva-x11-2 \
        libdrm2 \
        vainfo \
        intel-media-va-driver-non-free \
        i965-va-driver-shaders \
        mesa-va-drivers \
    && rm -rf /var/lib/apt/lists/*

# Install shaka packager
RUN wget https://github.com/shaka-project/shaka-packager/releases/download/v2.6.1/packager-linux-x64 \
    && chmod +x packager-linux-x64 \
    && mv packager-linux-x64 /usr/local/bin/packager

# Install N_m3u8DL-RE
RUN wget https://github.com/nilaoda/N_m3u8DL-RE/releases/download/v0.3.0-beta/N_m3u8DL-RE_v0.3.0-beta_linux-x64_20241203.tar.gz \
    && tar -xzf N_m3u8DL-RE_v0.3.0-beta_linux-x64_20241203.tar.gz \
    && mv N_m3u8DL-RE /usr/local/bin/ \
    && chmod +x /usr/local/bin/N_m3u8DL-RE \
    && rm N_m3u8DL-RE_v0.3.0-beta_linux-x64_20241203.tar.gz

# Create binaries directory and add symlinks
RUN mkdir -p /app/binaries && \
    ln -sf /usr/bin/ffprobe /app/binaries/ffprobe && \
    ln -sf /usr/bin/ffmpeg /app/binaries/ffmpeg && \
    ln -sf /usr/bin/mkvmerge /app/binaries/mkvmerge && \
    ln -sf /usr/local/bin/N_m3u8DL-RE /app/binaries/N_m3u8DL-RE && \
    ln -sf /usr/local/bin/packager /app/binaries/packager && \
    ln -sf /usr/local/bin/packager /usr/local/bin/shaka-packager && \
    ln -sf /usr/local/bin/packager /usr/local/bin/packager-linux-x64

# nginx and supervisor were already installed above with base dependencies

# Install uv for Python package management
RUN pip install --no-cache-dir uv

# Set working directory
WORKDIR /app

# Clone the official unshackle repository
RUN git clone --branch ${UNSHACKLE_BRANCH} ${UNSHACKLE_SOURCE} /app/unshackle-source

# Copy the official source files
RUN cp -r /app/unshackle-source/* /app/ && rm -rf /app/unshackle-source


# Install dependencies with uv
RUN uv sync --frozen

# Add a few runtime subtitle helpers that may not be present in the
# upstream project's locked deps on some environments (subby + webvtt)
RUN uv add isodate subby webvtt-py

# Build the UI directly in this stage
WORKDIR /tmp
# Copy our fixed UI source instead of cloning
RUN git clone --branch ${UI_BRANCH} ${UI_SOURCE} /tmp/unshackle-ui
WORKDIR /tmp/unshackle-ui

# Install UI dependencies
RUN npm ci

# Create production environment file with generated API key (Vite uses VITE_ prefix)
RUN UNSHACKLE_API_KEY=$(openssl rand -hex 32) && \
    echo "VITE_UNSHACKLE_API_URL=" > .env.production && \
    echo "VITE_UNSHACKLE_API_KEY=$UNSHACKLE_API_KEY" >> .env.production && \
    echo "VITE_TMDB_API_KEY=" >> .env.production && \
    echo "VITE_TMDB_BASE_URL=https://api.themoviedb.org/3" >> .env.production && \
    echo "VITE_TMDB_IMAGE_BASE=https://image.tmdb.org/t/p/w500" >> .env.production && \
    echo "VITE_APP_ENV=production" >> .env.production && \
    echo "VITE_LOG_LEVEL=error" >> .env.production && \
    echo "VITE_DEBUG_API=false" >> .env.production && \
    echo "TMDB_API_KEY=" >> .env.production && \
    echo "UNSHACKLE_API_KEY=$UNSHACKLE_API_KEY" > /app/.env


# Build the UI application (skip type checking due to upstream TypeScript issues)
RUN npm run build --skip-type-check || npx vite build

# Copy the built UI to nginx web root
RUN mkdir -p /var/www/html && cp -r /tmp/unshackle-ui/dist/* /var/www/html/

# Return to app directory
WORKDIR /app

# Create nginx configuration
COPY <<EOF /etc/nginx/sites-available/default
server {
    listen 80;
    server_name localhost;
    root /var/www/html;
    index index.html;

    # Enable gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/json application/xml+rss application/atom+xml image/svg+xml;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # API proxy - proxy /api/* requests to unshackle serve
    location /api/ {
        proxy_pass http://127.0.0.1:8888;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
    }

    # Static files with long-term caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        try_files \$uri =404;
    }

    # SPA fallback - serve index.html for all other routes
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Error pages
    error_page 404 /index.html;
}

# Transparent proxy server for API calls (listens on 8889, proxies to real API on 8888)
server {
    listen 8889;
    server_name localhost;

    # Proxy all requests to the real unshackle API
    location / {
        proxy_pass http://127.0.0.1:8888;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;

        # WebSocket support
        proxy_set_header Connection "upgrade";
    }
}
EOF

# Create supervisor configuration
COPY <<EOF /etc/supervisor/conf.d/unshackle.conf
[supervisord]
nodaemon=true
user=root
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid

[program:nginx]
command=nginx -g "daemon off;"
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:unshackle-api]
command=bash -c "source /app/.env && uv run unshackle serve --host 0.0.0.0 --port 8888 --no-key"
directory=/app
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
user=root
environment=HOME="/root",PATH="/app/.venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
EOF

# Create directories for downloads and config
RUN mkdir -p /app/downloads /app/config /var/log/supervisor

# Create startup script
COPY <<EOF /app/start.sh
#!/bin/bash

echo "=== Unshackle Docker Container Starting ==="
echo "Unshackle Branch: ${UNSHACKLE_BRANCH}"
echo "Container Built: $(date)"

# Load the generated API key
source /app/.env


# Display environment info
echo ""
echo "=== Environment Information ==="
echo "TMDB API Key: \$([ -n "\$TMDB_API_KEY" ] && echo "Set (\${TMDB_API_KEY:0:8}...)" || echo "Not set")"
echo "Unshackle API Key: \$([ -n "\$UNSHACKLE_API_KEY" ] && echo "Set (\${UNSHACKLE_API_KEY:0:8}...)" || echo "Not set")"

# Update the built UI with runtime environment variables if TMDB key is provided
if [ -n "\$TMDB_API_KEY" ]; then
    echo "Updating UI configuration with TMDB API key..."
    # Replace the literal "$TMDB_API_KEY" placeholder in built JS files with the runtime key
    find /var/www/html -name "*.js" -type f -exec sed -i "s/\\$TMDB_API_KEY/${TMDB_API_KEY}/g" {} \;
    echo "TMDB API key injected into UI build files"
fi

echo "=== Starting Services ==="
echo "Web UI: http://localhost (or your container's exposed port)"
echo "API: http://localhost:8888"
echo ""

# Start supervisor which will manage nginx and unshackle
exec supervisord -c /etc/supervisor/conf.d/unshackle.conf
EOF

# Convert line endings and make executable
RUN sed -i 's/\r$//' /app/start.sh && chmod +x /app/start.sh

# Configure grc and create wrapper scripts for interactive and non-interactive use
RUN set -eux; \
    if [ -f /etc/default/grc ]; then \
        sed -ri 's/^GRC_ALIASES=.*/GRC_ALIASES=true/' /etc/default/grc || echo 'GRC_ALIASES=true' >> /etc/default/grc; \
    fi; \
    if [ -f /etc/profile.d/grc.sh ]; then ln -sf /etc/profile.d/grc.sh /etc/grc.sh || true; fi; \
    # Create system-wide wrapper scripts so commands work in scripts and services
    cat > /usr/local/bin/unshackle <<'SH' && chmod +x /usr/local/bin/unshackle; \
#!/bin/sh
exec uv run unshackle "$@"
SH
    cat > /usr/local/bin/dl <<'SH' && chmod +x /usr/local/bin/dl; \
#!/bin/sh
exec uv run unshackle dl "$@"
SH
    # Ensure docker exec interactive shells load grc by default for root
    if [ -f /etc/profile.d/grc.sh ]; then \
        grep -qxF '[[ -s "/etc/profile.d/grc.sh" ]] && source /etc/profile.d/grc.sh' /root/.bashrc || echo '[[ -s "/etc/profile.d/grc.sh" ]] && source /etc/profile.d/grc.sh' >> /root/.bashrc; \
    fi || true

# Expose ports
EXPOSE 80 8888

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost/ && curl -f http://localhost:8888/ || exit 1

# Set the startup command
CMD ["bash", "/app/start.sh"]
