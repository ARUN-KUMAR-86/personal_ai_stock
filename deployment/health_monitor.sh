#!/usr/bin/env bash
# Health monitor & auto-recovery script for Personal AI Stock Backend
set -e

PORT="${PORT:-8000}"
HEALTH_URL="http://127.0.0.1:${PORT}/api/v1/health"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$HEALTH_URL" || echo "000")

if [ "$STATUS" -eq 200 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Health check OK (200)"
    exit 0
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Health check FAILED (Status: $STATUS). Attempting restart..."
    if command -v systemctl &>/dev/null && systemctl is-active --quiet stock-intel; then
        systemctl restart stock-intel
    elif docker ps --filter "name=stock_intel_backend" -q | grep -q .; then
        docker restart stock_intel_backend
    fi
    exit 1
fi
