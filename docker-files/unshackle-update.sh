#!/bin/bash
# Unshackle Update Script
# Downloads latest versions of Unshackle and Unshackle UI, then copies API files

set -e

UNSHACKLE_BRANCH="${UNSHACKLE_BRANCH:-main}"
UNSHACKLE_SOURCE="${UNSHACKLE_SOURCE:-https://github.com/unshackle-dl/unshackle}"
UI_BRANCH="${UI_BRANCH:-main}"
UI_SOURCE="${UI_SOURCE:-https://github.com/Kryxan/unshackle-ui}"

WORK_DIR="/tmp/unshackle-updates"
APP_DIR="/app"

echo "========================================="
echo "Unshackle Update Script"
echo "========================================="

# Create temporary working directory
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Function to get current version
get_current_version() {
    if [ -f "$APP_DIR/pyproject.toml" ]; then
        grep '^version = ' "$APP_DIR/pyproject.toml" | sed 's/version = "\(.*\)"/\1/' || echo "unknown"
    else
        echo "unknown"
    fi
}

# Function to get remote version
get_remote_version() {
    local repo=$1
    local branch=$2
    git ls-remote --tags "$repo" | grep -v '{}' | tail -n1 | sed 's/.*\/v\?\(.*\)/\1/' || echo "unknown"
}

CURRENT_VERSION=$(get_current_version)
echo "Current Unshackle version: $CURRENT_VERSION"

# Download Unshackle
echo ""
echo "Downloading Unshackle from $UNSHACKLE_SOURCE (branch: $UNSHACKLE_BRANCH)..."
if [ -d "$WORK_DIR/unshackle-source" ]; then
    rm -rf "$WORK_DIR/unshackle-source"
fi

git clone --depth 1 --branch "$UNSHACKLE_BRANCH" "$UNSHACKLE_SOURCE" "$WORK_DIR/unshackle-source" || {
    echo "ERROR: Failed to clone Unshackle repository"
    exit 1
}

NEW_VERSION=$(grep '^version = ' "$WORK_DIR/unshackle-source/pyproject.toml" | sed 's/version = "\(.*\)"/\1/' || echo "unknown")
echo "Remote Unshackle version: $NEW_VERSION"

# Download Unshackle UI
echo ""
echo "Downloading Unshackle UI from $UI_SOURCE (branch: $UI_BRANCH)..."
if [ -d "$WORK_DIR/unshackle-ui" ]; then
    rm -rf "$WORK_DIR/unshackle-ui"
fi

git clone --depth 1 --branch "$UI_BRANCH" "$UI_SOURCE" "$WORK_DIR/unshackle-ui" || {
    echo "ERROR: Failed to clone Unshackle UI repository"
    exit 1
}

# Copy Unshackle files to /app
echo ""
echo "Updating Unshackle files..."
if [ "$CURRENT_VERSION" != "$NEW_VERSION" ] || [ "$1" == "--force" ]; then
    echo "Copying Unshackle source files..."
    cp -r "$WORK_DIR/unshackle-source"/* "$APP_DIR/"
    echo "Unshackle updated: $CURRENT_VERSION -> $NEW_VERSION"
else
    echo "Unshackle already at latest version ($CURRENT_VERSION)"
fi

# Copy API files from UI to Unshackle
echo ""
echo "Updating API files from UI repository..."
if [ -d "$WORK_DIR/unshackle-ui/api" ]; then
    if [ -d "$APP_DIR/unshackle/core/api" ]; then
        echo "Backing up current API files..."
        cp -r "$APP_DIR/unshackle/core/api" "$APP_DIR/unshackle/core/api.backup.$(date +%Y%m%d_%H%M%S)" || true
    fi
    
    echo "Copying updated API files..."
    mkdir -p "$APP_DIR/unshackle/core/api"
    cp -r "$WORK_DIR/unshackle-ui/api"/* "$APP_DIR/unshackle/core/api/"
    echo "API files updated from UI repository"
else
    echo "WARNING: No api directory found in UI repository"
fi

# Update UI repository and build
echo ""
echo "Updating UI repository..."
if [ -d "$APP_DIR/unshackle-ui" ]; then
    rm -rf "$APP_DIR/unshackle-ui"
fi
cp -r "$WORK_DIR/unshackle-ui" "$APP_DIR/unshackle-ui"
echo "UI repository updated"

# Build UI if not skipped
if [ "$SKIP_UI_BUILD" != "true" ]; then
    echo ""
    echo "Building UI..."
    cd "$APP_DIR/unshackle-ui"
    
    # Install dependencies
    npm ci --include=dev --legacy-peer-deps || npm install --legacy-peer-deps || {
        echo "WARNING: npm install failed, attempting to continue..."
    }
    
    # Build UI
    npm run build || {
        echo "WARNING: UI build failed, continuing without UI"
        mkdir -p dist
    }
    
    # Deploy to web server
    echo "Deploying UI to /var/www/html..."
    mkdir -p /var/www/html /var/log/supervisor
    if [ -d dist ] && [ "$(ls -A dist 2>/dev/null)" ]; then
        cp -r dist/* /var/www/html/
        echo "UI deployed successfully"
    else
        echo '<h1>Unshackle UI build failed</h1><p>API available on port 8888</p>' > /var/www/html/index.html
        echo "WARNING: UI build produced no output, placeholder page created"
    fi
    
    cd "$APP_DIR"
else
    echo "Skipping UI build (SKIP_UI_BUILD=true)"
fi

# Clean up
echo ""
echo "Cleaning up temporary files..."
rm -rf "$WORK_DIR"

echo ""
echo "========================================="
echo "Update complete!"
echo "========================================="
echo "Unshackle version: $NEW_VERSION"
echo ""
echo "Next steps:"
echo "  1. Review changes in $APP_DIR"
echo "  2. Run 'uv sync' to update dependencies if needed"
echo "  3. Restart services with 'supervisorctl restart all'"
echo "========================================="
