#!/usr/bin/env bash
set -euo pipefail
umask 007
source_dir=${1:-${AGENT_LOG_DIR:-/var/log/agent-app}}
archive_dir=${2:-/var/log/monitor/agent-app/archive}
if (( $# > 2 )); then echo 'Usage: archive.sh [log-directory [archive-directory]]' >&2; exit 1; fi
if [[ ! -d "$source_dir" || -L "$source_dir" || ! -w "$source_dir" || ! -r "$source_dir" || ! -x "$source_dir" ]]; then
    echo "[ERROR] Log directory is missing or inaccessible: $source_dir" >&2; exit 1
fi
if [[ -L "$archive_dir" ]] || ! mkdir -p -- "$archive_dir" || [[ ! -w "$archive_dir" || ! -r "$archive_dir" || ! -x "$archive_dir" ]]; then
    echo "[ERROR] Archive directory is inaccessible: $archive_dir" >&2; exit 1
fi
# 같은 입력 디렉토리에서 아카이브가 중복 실행되지 않도록 잠급니다.
exec 9>"$source_dir/.archive.lock"
flock -n 9 || { echo '[WARNING] Another archive process is running' >&2; exit 1; }
# monitor.sh와 같은 잠금을 사용하여 현재 로그의 기록/회전과 겹치지 않습니다.
exec 8>"$source_dir/monitor.lock"
flock 8
compressed=0 deleted=0 failed=0
temporary=''
trap '[[ -z "$temporary" ]] || rm -f -- "$temporary"' EXIT
while IFS= read -r -d '' file; do
    target="$archive_dir/${file##*/}.gz"
    if [[ -e "$target" || -L "$target" || ! -r "$file" ]]; then
        echo "[WARNING] Skip unreadable file or archive collision: $file" >&2
        failed=1; continue
    fi
    temporary=$(mktemp "$archive_dir/.archive-XXXXXX")
    if gzip -c -- "$file" > "$temporary" && touch -r "$file" "$temporary" && mv -- "$temporary" "$target"; then
        temporary=''
        if rm -- "$file"; then
            printf '[ARCHIVED] %s -> %s\n' "$file" "$target"
            compressed=$((compressed+1))
        else failed=1; fi
    else
        echo "[WARNING] Compression failed, source retained: $file" >&2
        rm -f -- "$temporary"; temporary=''; failed=1
    fi
done < <(find "$source_dir" -maxdepth 1 -type f -name '*.log' -mtime +6 -print0)
while IFS= read -r -d '' file; do
    if rm -- "$file"; then printf '[DELETED] %s\n' "$file"; deleted=$((deleted+1)); else failed=1; fi
done < <(find "$archive_dir" -maxdepth 1 -type f -name '*.gz' -mtime +29 -print0)
printf '[INFO] Archived: %d Deleted: %d\n' "$compressed" "$deleted"
exit "$failed"
