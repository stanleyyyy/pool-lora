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
    KEY=$(.venv/bin/python -c "import base64,os; print(base64.b64encode(os.urandom(32)).decode())")
    cat > secrets.yaml <<EOF
wifi_ssid: "your-ssid"
wifi_password: "your-wifi-password"
fallback_password: "fallback-ap-password"
api_encryption_key: "$KEY"
ota_password: ""
EOF
    echo "Created secrets.yaml with a new API encryption key - put your Wi-Fi details in it before flashing the receiver."
fi

.venv/bin/esphome version
echo "Setup done. Start the dashboard with:"
echo "  .venv/bin/esphome-device-builder --host 127.0.0.1 --port 6052 ."
