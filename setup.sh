#!/bin/bash
# MediaStack Docker Compose Setup Script
# Initializes project directories and validates configuration

set -e

echo "=========================================="
echo "MediaStack Docker Setup Script"
echo "=========================================="

# Define directories
MEDIASTACK_ROOT="$(pwd)"
DIRS_TO_CREATE=(
    "config/jackett"
    "config"
    "jackett"
    "bazarr/config"
    "sonarr/config"
    "radarr/config"
    "transmission/config"
    "transmission/watch"
    "tvheadend/config"
    "tvheadend/recordings"
    "jellyseerr/config"
    "jellyfin/config"
    "jellyfin/db"
    "syncthing/config"
    "syncthing/data"
    "caddy/config"
    "caddy/data"
    "documents"
    "downloads"
)

echo "✓ Creating directories..."
for dir in "${DIRS_TO_CREATE[@]}"; do
    mkdir -p "$MEDIASTACK_ROOT/$dir"
    echo "  → $dir"
done

echo ""
echo "✓ Directory structure initialized"
echo ""
echo "=========================================="
echo "Validation Checklist"
echo "=========================================="

# Check docker-compose.yml
if [ -f "docker-compose.yml" ]; then
    echo "✓ docker-compose.yml exists"
    docker compose config > /dev/null 2>&1 && echo "✓ docker-compose.yml is valid" || echo "✗ docker-compose.yml has errors"
else
    echo "✗ docker-compose.yml not found"
fi

# Check required external paths (Windows-specific)
echo ""
echo "Checking Windows paths (must exist outside MediaStack/):"
if [ -d "../Videos" ]; then
    echo "✓ ../Videos exists (C:\\Users\\Public\\Videos)"
else
    echo "⚠ ../Videos not found - create C:\\Users\\Public\\Videos or adjust paths"
fi

if [ -d "../Pictures" ]; then
    echo "✓ ../Pictures exists (C:\\Users\\Public\\Pictures)"
else
    echo "⚠ ../Pictures not found - create C:\\Users\\Public\\Pictures or adjust paths"
fi

if [ -d "./music" ]; then
    echo "✓ ./music exists (C:\\Users\\Public\\Music)"
else
    echo "⚠ ./music not found - create C:\\Users\\Public\\Music or symlink it"
fi

echo ""
echo "=========================================="
echo "Next Steps"
echo "=========================================="
echo "1. Verify all directories created successfully"
echo "2. Create external paths if missing:"
echo "   - C:\\Users\\Public\\Videos"
echo "   - C:\\Users\\Public\\Pictures"
echo "   - C:\\Users\\Public\\Music (or symlink)"
echo "3. Enable SMB shares (see SHARES_SETUP.md)"
echo "4. Run: docker compose up -d"
echo "5. Verify all services are healthy: docker ps"
echo ""
echo "Documentation:"
echo "  - SERVICE_SETUP.md : Initial configuration for each service"
echo "  - SHARES_SETUP.md  : Windows SMB shares setup"
echo "  - HEALTH_CHECKS.md : Healthcheck & auto-restart info"
echo ""
