#!/usr/bin/env bash
# Load env if present
[ -f /app/.env ] && source /app/.env || true
echo "Starting supervisord (nginx + Unshackle API)"
# Run GPU checks first (best-effort) then start supervisord as PID 1
/opt/bin/check-gpu.sh || true
exec /usr/bin/supervisord -c /etc/supervisord.conf
