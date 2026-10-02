#!/usr/bin/env bash
set -euo pipefail
bin=${BONUS_BIN:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}
folder=$(mktemp -d)
trap 'rm -rf -- "$folder"' EXIT
expect_status() {
    local want=$1; shift
    set +e
    "$@"
    local actual=$?
    set -e
    echo "expected=$want actual=$actual"
    [[ "$actual" == "$want" ]]
}
cat > "$folder/samples.log" <<'LOG'
[2026-10-02 12:00:00] PID:123 CPU:10% MEM:2% DISK_USED:30%
[2026-10-02 12:01:00] PID:123 CPU:20% MEM:4% DISK_USED:40%
[2026-10-02 12:02:00] PID:123 CPU:30% MEM:6% DISK_USED:50%
malformed
LOG
echo 'Controlled samples: 10/20/30 CPU, 2/4/6 MEM, 30/40/50 DISK'
"$bin/report.sh" "$folder/samples.log" | tee "$folder/report.txt"
grep -q 'Average: 20.00%' "$folder/report.txt"
grep -q 'Data Points: 3 samples' "$folder/report.txt"
"$bin/report.sh" "$folder/samples.log" '2026-10-02 12:01:00' '2026-10-02 12:01:00' | tee "$folder/range.txt"
grep -q 'Data Points: 1 samples' "$folder/range.txt"
expect_status 2 "$bin/report.sh" "$folder/samples.log" '2026-10-03 00:00:00'
expect_status 1 "$bin/report.sh" "$folder/missing.log"
expect_status 1 "$bin/report.sh" "$folder/samples.log" '2026-10-03 00:00:00' '2026-10-02 00:00:00'
mkdir "$folder/logs" "$folder/archive"
printf 'keep old source\n' > "$folder/logs/eight-days.log"
printf 'keep recent source\n' > "$folder/logs/six-days.log"
printf 'keep thirty-day source\n' > "$folder/logs/thirty-days.log"
printf 'retained archive\n' | gzip > "$folder/archive/twenty-nine-days.gz"
printf 'removed archive\n' | gzip > "$folder/archive/thirty-days.gz"
touch -d '8 days ago' "$folder/logs/eight-days.log"
touch -d '6 days ago' "$folder/logs/six-days.log"
touch -d "@$(($(date +%s)-2592060))" "$folder/logs/thirty-days.log" "$folder/archive/thirty-days.gz"
touch -d '29 days ago' "$folder/archive/twenty-nine-days.gz"
ln -s "$folder/logs/six-days.log" "$folder/logs/linked.log"
echo 'Controlled file ages: 6/8/29/30 days; not historical production records'
"$bin/archive.sh" "$folder/logs" "$folder/archive"
[[ ! -e "$folder/logs/eight-days.log" && -f "$folder/logs/six-days.log" && -L "$folder/logs/linked.log" ]]
[[ ! -e "$folder/logs/thirty-days.log" && ! -e "$folder/archive/thirty-days.log.gz" && ! -e "$folder/archive/thirty-days.gz" ]]
[[ -f "$folder/archive/twenty-nine-days.gz" ]]
gzip -cd "$folder/archive/eight-days.log.gz" | tee "$folder/uncompressed.txt"
grep -q 'keep old source' "$folder/uncompressed.txt"
"$bin/archive.sh" "$folder/logs" "$folder/archive"
printf 'collision retained\n' > "$folder/logs/collision.log"
printf 'existing archive\n' | gzip > "$folder/archive/collision.log.gz"
touch -d '8 days ago' "$folder/logs/collision.log"
expect_status 1 "$bin/archive.sh" "$folder/logs" "$folder/archive"
[[ -f "$folder/logs/collision.log" ]]
expect_status 1 "$bin/archive.sh" "$folder/missing" "$folder/archive"
mkdir "$folder/denied"; chmod 000 "$folder/denied"
expect_status 1 "$bin/archive.sh" "$folder/denied" "$folder/archive"
chmod 700 "$folder/denied"
printf '[PASS] statistics, range, age policy, roundtrip, repeat, collision, missing and permission cases\n'
