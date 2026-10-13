#!/usr/bin/env bash
# ==============================================================================
# One-Click Automatic Cloud Deployment Script for Personal AI Stock Intelligence
# ==============================================================================
# Pushes the latest codebase to GitHub (origin main), triggering Render's
# automated zero-configuration cloud build and deployment.
# ==============================================================================

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "========================================================"
echo "🚀 AUTO-DEPLOYING PERSONAL AI STOCK TO THE CLOUD"
echo "========================================================"

# 1. Check for uncommitted changes
if [[ -n $(git status --porcelain) ]]; then
  echo "📦 Staging and committing all updates..."
  git add .
  COMMIT_MSG="feat: auto-sync live trading controls and Option B hybrid guard $(date +'%Y-%m-%d %H:%M:%S')"
  git commit -m "$COMMIT_MSG"
  echo "✅ Committed: $COMMIT_MSG"
else
  echo "ℹ️ Working tree clean. Pushing latest commit..."
fi

# 2. Push to GitHub
echo "📡 Pushing to GitHub (origin main)..."
git push origin main
echo "✅ Pushed to https://github.com/ARUN-KUMAR-86/personal_ai_stock.git"

echo ""
echo "========================================================"
echo "☁️ Render Cloud Service is now building automatically!"
echo "Target Endpoint: https://personal-ai-stock-backend.onrender.com"
echo "========================================================"
echo "Your Android phone app will automatically load this endpoint"
echo "without requiring any copy-pasting of URLs or IP addresses."
echo "========================================================"
