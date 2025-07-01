#!/bin/bash
set -e

CURRENT_STEP=1
declare -a steps=(
  "Updating & Upgrading System..."
  "Installing Dependencies..."
  "Setting up Certbot..."
  "Cloning Webhook Listener..."
  "Launching webhook in tmux session..."
  "Downloading Gophish..."
  "Extracting & Configuring Gophish..."
  "Launching Gophish in tmux session..."
  "Fetching IP & credentials..."
)
TOTAL_STEPS=${#steps[@]}

run_step() {
  local message="$1"
  shift
  local log_file="/tmp/step_error.log"
  printf "➤ [Step %d/%d] %-40s " "$CURRENT_STEP" "$TOTAL_STEPS" "$message"
  CURRENT_STEP=$((CURRENT_STEP+1))
  ("$@" > /dev/null 2> "$log_file") &
  local pid=$!
  wait $pid
  local status=$?
  if [ "$status" -eq 0 ]; then
    printf "[OK]\n"
  else
    printf "[FAIL]\n"
    echo "        ↳ Reason: $(head -n 1 "$log_file")"
    exit 1
  fi
}

echo "────────────────────────────────────────────"

run_step "${steps[0]}" sudo bash -c 'apt update -y && apt upgrade -y'
run_step "${steps[1]}" sudo apt install -y unzip net-tools docker.io golang-go python3 python3-venv libaugeas0 wget git tmux curl
run_step "${steps[2]}" bash -c '
  python3 -m venv /opt/certbot/ && \
  /opt/certbot/bin/pip install --upgrade pip && \
  /opt/certbot/bin/pip install certbot && \
  ln -sf /opt/certbot/bin/certbot /usr/bin/certbot
'

# Step 4: Clone webhook
printf "➤ [Step %d/%d] %-40s " "$CURRENT_STEP" "$TOTAL_STEPS" "${steps[3]}"
cd /opt/
if [ ! -d "/opt/webhook" ]; then
  git clone https://github.com/gophish/webhook.git > /dev/null 2>&1
  echo "[OK]"
else
  echo "[SKIP]"
fi
CURRENT_STEP=$((CURRENT_STEP+1))

# Step 5: Launch webhook
printf "➤ [Step %d/%d] %-40s " "$CURRENT_STEP" "$TOTAL_STEPS" "${steps[4]}"
tmux has-session -t webhook 2>/dev/null && tmux kill-session -t webhook
tmux new-session -d -s webhook 'cd /opt/webhook && go run main.go --port="9999" --server=0.0.0.0 --path="/webhook"' > /dev/null 2>&1
echo "[OK]"
CURRENT_STEP=$((CURRENT_STEP+1))

run_step "${steps[5]}" wget -q https://github.com/gophish/gophish/releases/download/v0.12.1/gophish-v0.12.1-linux-64bit.zip

run_step "${steps[6]}" bash -c '
  mkdir -p /opt/gophish && \
  unzip -o /opt/gophish-v0.12.1-linux-64bit.zip -d /opt/gophish > /dev/null && \
  chmod +x /opt/gophish/gophish && \
  cat <<EOF > /opt/gophish/config.json
{
  "admin_server": {
    "listen_url": "0.0.0.0:3333",
    "use_tls": true,
    "cert_path": "gophish_admin.crt",
    "key_path": "gophish_admin.key",
    "trusted_origins": []
  },
  "phish_server": {
    "listen_url": "0.0.0.0:443",
    "use_tls": true,
    "cert_path": "example.crt",
    "key_path": "example.key"
  },
  "db_name": "sqlite3",
  "db_path": "gophish.db",
  "migrations_prefix": "db/db_",
  "contact_address": "",
  "logging": {
    "filename": "",
    "level": ""
  }
}
EOF
'

# Step 8: Launch Gophish
printf "➤ [Step %d/%d] %-40s " "$CURRENT_STEP" "$TOTAL_STEPS" "${steps[7]}"
cd /opt/gophish
tmux has-session -t gophish 2>/dev/null && tmux kill-session -t gophish
tmux new-session -d -s gophish './gophish &> gophish.log'
echo "[OK]"
CURRENT_STEP=$((CURRENT_STEP+1))

# Step 9: Get IP and default password
printf "➤ [Step %d/%d] %-40s " "$CURRENT_STEP" "$TOTAL_STEPS" "${steps[8]}"
sleep 5
IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip)
DEFAULT_PASS=$(grep -oP 'password \K[0-9a-f]+' /opt/gophish/gophish.log | tail -n1)
[ -z "$DEFAULT_PASS" ] && DEFAULT_PASS="(not found - check gophish.log)"
echo "[OK]"

# Summary
echo ""
echo "────────────────────────────────────────────"
echo "               SETUP COMPLETE"
echo "────────────────────────────────────────────"
printf "➤ %-30s : https://%s:3333\n" "Gophish Admin Panel" "$IP"
printf "   %-30s : %s\n" "Username" "admin"
printf "   %-30s : %s\n" "Password" "$DEFAULT_PASS"
echo ""
printf "➤ %-30s : https://%s (port 443)\n" "Phishing Server" "$IP"
printf "➤ %-30s : http://%s:9999/webhook\n" "Webhook Listener" "$IP"
echo "────────────────────────────────────────────"
