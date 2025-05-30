#!/bin/bash
set -e

# locate project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/bin/server_status_venv"
REQUIREMENTS="$SCRIPT_DIR/bin/requirements.txt"

# bootstrap venv if missing
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip
    pip install -r "$REQUIREMENTS"
else
    source "$VENV_DIR/bin/activate"
fi

# enter bin/ so server_status.py is in cwd
cd "$SCRIPT_DIR/bin"

# start the server
gunicorn -w 12 -k aiohttp.GunicornWebWorker -b 0.0.0.0:8081 server_status:app
