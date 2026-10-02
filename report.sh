#!/usr/bin/env bash
set -euo pipefail
log=${1:-${AGENT_LOG_DIR:-/var/log/agent-app}/monitor.log}
from=${2:-}
to=${3:-}
if (( $# > 3 )); then echo 'Usage: report.sh [log [from [to]]]' >&2; exit 1; fi
if [[ ! -f "$log" || ! -r "$log" ]]; then echo "[ERROR] Log is missing or unreadable: $log" >&2; exit 1; fi
for stamp in "$from" "$to"; do
    [[ -z "$stamp" ]] && continue
    if [[ ! "$stamp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}$ ]] || ! date -d "$stamp" >/dev/null 2>&1; then
        echo '[ERROR] Time must be YYYY-MM-DD HH:MM:SS' >&2; exit 1
    fi
done
if [[ -n "$from" && -n "$to" && "$from" > "$to" ]]; then echo '[ERROR] Start time is after end time' >&2; exit 1; fi
LC_ALL=C awk -v from="$from" -v to="$to" '
{
    stamp = substr($0, 2, 19)
    valid = NF == 6 && $1 ~ /^\[[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ && $2 ~ /^[0-9][0-9]:[0-9][0-9]:[0-9][0-9]\]$/ && $3 ~ /^PID:[0-9]+$/
    for (i=1; i<=3; i++) {
        split($(i+3), part, ":")
        label = i==1 ? "CPU" : i==2 ? "MEM" : "DISK_USED"
        if (part[1] != label || part[2] !~ /^[0-9]+(\.[0-9]+)?%$/) valid=0
        sub(/%$/, "", part[2]); value[i]=part[2]+0
    }
    if (!valid) {bad++; next}
    if ((from!="" && stamp<from) || (to!="" && stamp>to)) next
    n++
    for (i=1; i<=3; i++) {
        sum[i]+=value[i]
        if (n==1 || value[i]<lo[i]) {lo[i]=value[i]; lot[i]=stamp}
        if (n==1 || value[i]>hi[i]) {hi[i]=value[i]; hit[i]=stamp}
    }
}
END {
    if (bad) printf "[WARNING] Malformed lines skipped: %d\n", bad > "/dev/stderr"
    if (!n) {print "[INFO] No samples in the requested range"; exit 2}
    print "====== STATISTICS REPORT ======"
    for (i=1; i<=3; i++) {
        printf "[%s]\nAverage: %.2f%%\nMaximum: %.2f%% at %s\nMinimum: %.2f%% at %s\n", i==1 ? "CPU" : i==2 ? "MEM" : "DISK", sum[i]/n, hi[i], hit[i], lo[i], lot[i]
    }
    printf "[Samples]\nData Points: %d samples\n", n
}' "$log"
