#!/usr/bin/env bash
# Ping Render backend to keep container awake 24/7
curl -s -m 25 "https://personal-ai-stock-backend.onrender.com/health" > /dev/null 2>&1
curl -s -m 25 "https://personal-ai-stock-backend.onrender.com/api/v1/health" > /dev/null 2>&1
curl -s -m 25 -X POST "https://personal-ai-stock-backend.onrender.com/api/v1/portfolio/auto-sell-check" > /dev/null 2>&1
