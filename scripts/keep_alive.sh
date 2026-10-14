#!/usr/bin/env bash
# Cloud Keep-Alive & 24/7 Position Monitor Ping
# Pings Render backend every 5 minutes to prevent sleep (15m limit) and triggers auto-sell checks.

BACKEND_URL="https://personal-ai-stock-backend.onrender.com"
LOG_FILE="/home/arun/personal-ai-stock/scripts/keep_alive.log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Cloud Keep-Alive Ping Service for $BACKEND_URL" >> "$LOG_FILE"

while true; do
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  
  # 1. Ping Health (Keeps container warm)
  HEALTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 25 "$BACKEND_URL/health" 2>/dev/null || echo "ERR")
  
  # 2. Trigger Auto-Sell Check
  SELL_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 25 -X POST "$BACKEND_URL/api/v1/portfolio/auto-sell-check" 2>/dev/null || echo "ERR")
  
  echo "[$TIMESTAMP] Health Ping: $HEALTH_CODE | Auto-Sell Check: $SELL_CODE" >> "$LOG_FILE"
  
  # Sleep 5 minutes (300 seconds)
  sleep 300
done
