#!/bin/bash
rm -rf /opt/gophish /opt/webhook
clear
set -euo pipefail

CURRENT_STEP=1
declare -a steps=(
  "Updating..."
  "Installing Dependencies..."
  "Cloning Webhook Listener..."
  "Launching webhook in tmux session..."
  "Downloading Gophish..."
  "Extracting & Configuring Gophish..."
  "Launching Gophish in tmux session..."
  "Fetching IP & credentials..."
)
TOTAL_STEPS=${#steps[@]}

# Spinner baru (jelas)
SPINNER_CHARS=('●○○○○' '○●○○○' '○○●○○' '○○○●○' '○○○○●' '○○○●○' '○○●○○' '○●○○○')

# Warna
GREEN=$'\e[0;32m'
BOLD_GREEN=$'\e[1;32m'
RED=$'\e[0;31m'
YELLOW=$'\e[0;33m'
RESET=$'\e[0m'

MSG_WIDTH=45

print_header() {
  echo ""
  echo "${BOLD_GREEN}${BOLD_GREEN}✨ PHISKIT ${RESET}"
  echo ""
  echo "${YELLOW}➤ Automated Gophish + Webhook Installer with tmux session handling${RESET}"
  echo ""
}

# print header
print_header

# Pilihan versi Gophish
echo "────────────────────────────────────────────"
echo " Pilih versi Gophish yang ingin diinstall:"
echo " 1) v0.12.1"
echo " 2) v0.11.0"
echo " 3) v0.10.1"
echo "────────────────────────────────────────────"
read -rp "Masukkan pilihan [1-3]: " choice

case $choice in
  1)
    GOPHISH_VERSION="v0.12.1"
    GOPHISH_URL="https://github.com/gophish/gophish/releases/download/v0.12.1/gophish-v0.12.1-linux-64bit.zip"
    GOPHISH_FILE="gophish-v0.12.1-linux-64bit.zip"
    ;;
  2)
    GOPHISH_VERSION="v0.11.0"
    GOPHISH_URL="https://github.com/gophish/gophish/releases/download/v0.11.0/gophish-v0.11.0-linux-64bit.zip"
    GOPHISH_FILE="gophish-v0.11.0-linux-64bit.zip"
    ;;
  3)
    GOPHISH_VERSION="v0.10.1"
    GOPHISH_URL="https://github.com/gophish/gophish/releases/download/v0.10.1/gophish-v0.10.1-linux-64bit.zip"
    GOPHISH_FILE="gophish-v0.10.1-linux-64bit.zip"
    ;;
  *)
    echo "Pilihan tidak valid."
    exit 1
    ;;
esac

# Lokasi penyimpanan
GOPHISH_PATH="/opt/gophish"
GOPHISH_ZIP="/opt/$GOPHISH_FILE"

run_step() {
  local message="$1"
  shift
  local log_file="/tmp/step_error.log"
  : > "$log_file"

  ("$@" > /dev/null 2> "$log_file") &
  local pid=$!

  local spinner_i=0
  local status=0

  while kill -0 "$pid" 2>/dev/null; do
    spinner_i=$(( (spinner_i + 1) % ${#SPINNER_CHARS[@]} ))
    spinner_display="${BOLD_GREEN}${SPINNER_CHARS[$spinner_i]}${RESET}"
    printf "\r\033[K➤ [Step %d/%d] %-*s %b" \
      "$CURRENT_STEP" "$TOTAL_STEPS" "$MSG_WIDTH" "$message" "$spinner_display"
    sleep 0.12
  done

  wait "$pid" || status=$?

  if [ "$status" -eq 0 ]; then
    printf "\r\033[K➤ [Step %d/%d] %-*s %b\n" \
      "$CURRENT_STEP" "$TOTAL_STEPS" "$MSG_WIDTH" "$message" "${GREEN}[OK]${RESET}"
  else
    local reason
    reason="$(head -n 1 "$log_file" || echo "(no stderr captured)")"
    printf "\r\033[K➤ [Step %d/%d] %-*s %b\n" \
      "$CURRENT_STEP" "$TOTAL_STEPS" "$MSG_WIDTH" "$message" "${RED}[FAIL]${RESET}"
    echo "        ↳ Reason: ${reason}"
    echo "        ↳ Full log: ${log_file}"
    exit 1
  fi

  CURRENT_STEP=$((CURRENT_STEP + 1))
}

echo "────────────────────────────────────────────"

# Step 1
run_step "${steps[0]}" sudo bash -c 'apt update -y'

# Step 2
run_step "${steps[1]}" sudo apt install -y unzip wget git golang-go tmux curl python3 python3-venv

# Step 3: Clone webhook (tampilkan SKIP berwarna kuning jika sudah ada)
if [ ! -d "/opt/webhook" ]; then
  run_step "${steps[2]}" bash -c "cd /opt && git clone https://github.com/gophish/webhook.git"
else
  printf "➤ [Step %d/%d] %-*s ${YELLOW}[SKIP]${RESET}\n" "$CURRENT_STEP" "$TOTAL_STEPS" "$MSG_WIDTH" "${steps[2]}"
  CURRENT_STEP=$((CURRENT_STEP+1))
fi

# Step 4: Launch webhook
run_step "${steps[3]}" bash -c 'tmux has-session -t webhook 2>/dev/null && tmux kill-session -t webhook; tmux new-session -d -s webhook "cd /opt/webhook && go run main.go --port=\"9999\" --server=0.0.0.0 --path=\"/webhook\"" > /dev/null 2>&1'

# Step 5: Download Gophish sesuai pilihan
run_step "${steps[4]}" wget -q "$GOPHISH_URL" -O "$GOPHISH_ZIP"

# Step 6: Extract & configure gophish
run_step "${steps[5]}" bash -c "mkdir -p $GOPHISH_PATH && unzip -o $GOPHISH_ZIP -d $GOPHISH_PATH > /dev/null && chmod +x $GOPHISH_PATH/gophish && cat > $GOPHISH_PATH/config.json <<EOF
{
  \"admin_server\": {
    \"listen_url\": \"0.0.0.0:3333\",
    \"use_tls\": true,
    \"cert_path\": \"gophish_admin.crt\",
    \"key_path\": \"gophish_admin.key\",
    \"trusted_origins\": []
  },
  \"phish_server\": {
    \"listen_url\": \"0.0.0.0:443\",
    \"use_tls\": true,
    \"cert_path\": \"example.crt\",
    \"key_path\": \"example.key\"
  },
  \"db_name\": \"sqlite3\",
  \"db_path\": \"gophish.db\",
  \"migrations_prefix\": \"db/db_\",
  \"contact_address\": \"\",
  \"logging\": {
    \"filename\": \"\",
    \"level\": \"\"
  }
}
EOF"

# Step 7: Launch Gophish
run_step "${steps[6]}" bash -c 'cd /opt/gophish; tmux has-session -t gophish 2>/dev/null && tmux kill-session -t gophish; tmux new-session -d -s gophish "./gophish &> gophish.log"'

# Step 8: Get IP and default password
run_step "${steps[7]}" bash -c '
  sleep 2
  IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || echo "(ip-detect-failed)")
  DEFAULT_PASS=$(grep -oP "password \K[0-9a-f]+" /opt/gophish/gophish.log 2>/dev/null | tail -n1)
  [ -z "$DEFAULT_PASS" ] && DEFAULT_PASS="(not found - check /opt/gophish/gophish.log)"
  echo "IP=${IP}" > /tmp/gophish_summary
  echo "PASS=${DEFAULT_PASS}" >> /tmp/gophish_summary
'
# Final summary (baca dari /tmp/gophish_summary)
sleep 2
IP="$(awk -F= '/^IP=/{print $2}' /tmp/gophish_summary 2>/dev/null || echo '(ip-not-detected)')"
DEFAULT_PASS="$(awk -F= '/^PASS=/{print $2}' /tmp/gophish_summary 2>/dev/null || echo '(no-pass)')"

# Jika pengguna pilih v0.10.1, gunakan password default gophish
if [ "${GOPHISH_VERSION}" = "v0.10.1" ]; then
  DEFAULT_PASS="gophish"
fi

# Summary
echo ""
echo "${BOLD_GREEN}────────────────────────────────────────────${RESET}"
echo "${BOLD_GREEN}               SETUP COMPLETE${RESET}"
echo "${BOLD_GREEN}────────────────────────────────────────────${RESET}"
printf "➤ ${YELLOW}%-30s${RESET} : ${GREEN}https://%s:3333${RESET}\n" "Gophish Admin Panel" "$IP"
printf "  ${YELLOW}%-30s${RESET} : ${GREEN}%s${RESET}\n" "Username" "admin"
printf "  ${YELLOW}%-30s${RESET} : ${GREEN}%s${RESET}\n" "Password" "$DEFAULT_PASS"
echo ""
printf "➤ ${YELLOW}%-30s${RESET} : ${GREEN}https://%s (port 443)${RESET}\n" "Phishing Server" "$IP"
printf "➤ ${YELLOW}%-30s${RESET} : ${GREEN}http://%s:9999/webhook${RESET}\n" "Webhook Listener" "$IP"
echo "${BOLD_GREEN}────────────────────────────────────────────${RESET}"
echo ""
printf "${YELLOW}Success!${RESET}\n"
echo ""