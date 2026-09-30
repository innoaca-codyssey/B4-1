#!/usr/bin/env bash
set -euo pipefail

app=${AGENT_APP:-${AGENT_HOME:?AGENT_HOME is required}/agent-app-linux-arm64}
log_dir=${AGENT_LOG_DIR:-/var/log/agent-app}
port=${AGENT_PORT:-15034}
log="$log_dir/monitor.log"

pid=$(pgrep -n -f "^${app}$") || {
    echo "[ERROR] Process is not running: $app"
    exit 1
}
if ! ss -H -ltn "sport = :$port" | grep -q LISTEN; then
    echo "[ERROR] Port $port is not listening"
    exit 1
fi
echo "[OK] PID:$pid PORT:$port"

if ! firewall=$(sudo -n /usr/sbin/ufw status 2>/dev/null) || ! grep -q '^Status: active' <<< "$firewall"; then
    echo '[WARNING] Firewall is inactive or its status is unavailable'
fi

cpu_ticks() {
    local stat
    local -a fields
    stat=$(cat "/proc/$pid/stat") || return 1
    read -ra fields <<< "${stat##*) }"
    echo "$((${fields[11]} + ${fields[12]})) ${fields[19]}"
}
read -r first born < <(cpu_ticks)
read -r before _ < /proc/uptime
sleep 1
if ! read -r last still_born < <(cpu_ticks) || [[ "$born" != "$still_born" ]]; then
    echo '[ERROR] Process exited during sampling'
    exit 1
fi
read -r after _ < /proc/uptime
hz=$(getconf CLK_TCK)
cpu=$(awk -v a="$first" -v b="$last" -v h="$hz" -v t1="$before" -v t2="$after" 'BEGIN {printf "%.1f", 100*(b-a)/h/(t2-t1)}')
rss=$(awk '/^VmRSS:/ {print $2}' "/proc/$pid/status")
total=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
mem=$(awk -v r="$rss" -v t="$total" 'BEGIN {printf "%.1f", 100*r/t}')
disk=$(df -P / | awk 'NR==2 {gsub(/%/, "", $5); print $5}')
echo "CPU:$cpu% MEM:$mem% RSS:${rss}KiB DISK_USED:$disk%"
for pair in "CPU $cpu 20" "MEM $mem 10" "DISK_USED $disk 80"; do
    read -r label value limit <<< "$pair"
    if awk -v v="$value" -v l="$limit" 'BEGIN {exit !(v>l)}'; then
        echo "[WARNING] $label threshold exceeded ($value% > $limit%)"
    fi
done

line="[$(date '+%Y-%m-%d %H:%M:%S')] PID:$pid CPU:$cpu% MEM:$mem% DISK_USED:$disk%"
exec 9>"$log_dir/monitor.lock"
flock 9
size=0
[[ ! -f "$log" ]] || size=$(stat -c %s "$log")
if (( size + ${#line} + 1 > 10000000 )); then
    rm -f "$log.9"
    for ((i=8; i>=1; i--)); do
        [[ ! -f "$log.$i" ]] || mv "$log.$i" "$log.$((i+1))"
    done
    [[ ! -f "$log" ]] || mv "$log" "$log.1"
fi
printf '%s\n' "$line" >> "$log"
echo "[INFO] Log appended: $log"
