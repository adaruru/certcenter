#!/bin/sh
# Save at /etc/cert-sync.sh
# Cron (entrypoint): 0 3 * * * root /bin/bash /etc/cert-sync.sh

set -e

DOMAIN="*.itsower.com.tw"
API="http://192.168.100.63:9250/health?domain=$DOMAIN"
CERT_API="http://192.168.100.63:9250/cert?domain=$DOMAIN"
TARGET_DIR="/etc/carcare-cert/live"
LOG_FILE="/var/log/cert-sync.log"

# Mirror stdout+stderr to both log file and container stdout without bash-only syntax
_log_pipe="$(mktemp)"
rm -f "$_log_pipe"
mkfifo "$_log_pipe"
tee -a "$LOG_FILE" <"$_log_pipe" &
_tee_pid=$!
exec >"$_log_pipe" 2>&1
trap 'rm -f "$_log_pipe"; kill "$_tee_pid" >/dev/null 2>&1 || true' EXIT INT TERM

echo "[INFO] Checking cert status for domain=$DOMAIN"

resp="$(curl -s "$API" || true)"
status="$(echo "$resp" | jq -r '.status // "UNKNOWN"')"

if [ "$status" = "OK" ] || [ "$status" = "WARN" ]; then
    echo "[INFO] Cert status=$status, downloading..."
    rm -f live.zip
    mkdir -p "$TARGET_DIR"
    curl -OJ "$CERT_API"
    unzip -o live.zip -d "$TARGET_DIR"

    if pgrep -x "nginx" >/dev/null 2>&1; then
        echo "[INFO] Reloading nginx to apply new certificate..."
        /usr/sbin/nginx -s reload || echo "[WARN] nginx reload failed, please check"
    else
        echo "[INFO] nginx is not running yet (first boot), skip reload"
    fi
elif [ "$status" = "ERROR" ]; then
    echo "[ERROR] Certificate expired, manual intervention required!"
else
    echo "[ERROR] Unknown status: $status"
fi