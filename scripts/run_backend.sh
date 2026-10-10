#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR/backend"

if [ ! -d "venv" ]; then
    echo "Creating Python virtual environment in backend/venv..."
    python3 -m venv venv
    ./venv/bin/pip install --upgrade pip
    ./venv/bin/pip install -r requirements.txt
fi

PORT="${1:-${PORT:-8000}}"
HOST="${2:-${HOST:-0.0.0.0}}"

# Check if port is already in use
if command -v ss >/dev/null 2>&1; then
    PID_USING_PORT=$(ss -tulpn "sport = :$PORT" 2>/dev/null | grep -o 'pid=[0-9]*' | cut -d= -f2 | head -n1 || true)
    if [ -n "$PID_USING_PORT" ]; then
        echo "[WARNING] Port $PORT is already in use by process PID: $PID_USING_PORT"
        echo "You can stop it with: kill -9 $PID_USING_PORT"
        echo "Or run on a different port: ./scripts/run_backend.sh 8080"
        exit 1
    fi
fi

echo "Starting Personal AI Stock Intelligence Backend on $HOST:$PORT..."
./venv/bin/uvicorn app.main:app --host "$HOST" --port "$PORT" --reload
