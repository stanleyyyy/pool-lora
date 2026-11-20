#!/usr/bin/env sh
# One-time setup: creates .venv with ESPHome and Device Builder, and secrets.yaml.
# Safe to run again; it only adds what is missing or out of date.
set -e
cd "$(dirname "$0")"

PY=${PYTHON:-python3}
command -v "$PY" >/dev/null 2>&1 || { echo "Python 3.11 or newer is required"; exit 1; }

if [ ! -x .venv/bin/python ]; then
    echo "Creating .venv ..."
    "$PY" -m venv .venv
fi

echo "Installing ESPHome and Device Builder ..."
.venv/bin/python -m pip install --quiet --upgrade pip
.venv/bin/python -m pip install --quiet -r requirements.txt

if [ ! -f secrets.yaml ]; then
    cp secrets.example.yaml secrets.yaml
    echo "Created secrets.yaml - edit it with your Wi-Fi and API values before flashing the receiver."
fi

.venv/bin/esphome version
echo "Setup done. Start the dashboard with:"
echo "  .venv/bin/esphome-device-builder --host 127.0.0.1 --port 6052 ."
