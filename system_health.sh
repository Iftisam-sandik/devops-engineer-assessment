#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
umask 077
trap 'printf "[CRITICAL] health collection failed at line %s\n" "$LINENO" >&2; exit 2' ERR

usage() {
  cat <<'HELP'
Usage: system_health.sh [--json] [--cpu 90] [--mem 85] [--disk 80]
       [--critical 95] [--log /path/health_log.txt]
       [--max-log-bytes 1048576] [--keep 3] [--help]
Linux host metrics from /proc, GNU df and procps ps. All mounted filesystems,
including virtual filesystems, are listed. Zero-size filesystems do not alert.
Thresholds are percentages (0..100); critical must be >= warning thresholds.
Exit: 0 healthy, 1 warning, 2 critical/collection or argument error.
Warnings go to stderr; --json emits one valid JSON object to stdout and the log.
Rotation retains --keep backups. Requires Bash 4+, coreutils, util-linux, procps, awk.
HELP
}
cpu_threshold=90 mem_threshold=85 disk_threshold=80 critical_threshold=95
json=false log_file=health_log.txt max_bytes=1048576 keep=3
die() { printf '[CRITICAL] %s\n' "$*" >&2; exit 2; }
while (($#)); do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --json) json=true; shift ;;
    --cpu|--mem|--disk|--critical|--log|--max-log-bytes|--keep)
      (($# >= 2)) || die "Missing value for $1"
      case "$1" in
        --cpu) cpu_threshold=$2 ;; --mem) mem_threshold=$2 ;;
        --disk) disk_threshold=$2 ;; --critical) critical_threshold=$2 ;;
        --log) log_file=$2 ;; --max-log-bytes) max_bytes=$2 ;; --keep) keep=$2 ;;
      esac
      shift 2 ;;
    *) die "Unknown argument: $1" ;;
  esac
done
for value in "$cpu_threshold" "$mem_threshold" "$disk_threshold" "$critical_threshold"; do
  [[ $value =~ ^(0|[1-9][0-9]?|100)$ ]] || die 'Thresholds must be integers from 0 to 100'
done
((critical_threshold >= cpu_threshold && critical_threshold >= mem_threshold && critical_threshold >= disk_threshold)) || die 'Critical must be >= every warning threshold'
[[ $max_bytes =~ ^[1-9][0-9]*$ && $keep =~ ^[1-9][0-9]*$ ]] || die 'Rotation size and count must be positive integers'
((keep <= 20)) || die 'At most 20 backups are allowed'
[[ -d $(dirname "$log_file") ]] || die 'Log directory does not exist'
for tool in awk df ps date sleep flock wc mv; do command -v "$tool" >/dev/null || die "Required tool missing: $tool"; done

escape_json() {
  local text=$1
  text=${text//\\/\\\\}; text=${text//\"/\\\"}
  text=${text//$'\n'/\\n}; text=${text//$'\r'/\\r}; text=${text//$'\t'/\\t}
  printf '%s' "$text"
}
cpu_sample() { awk '/^cpu / {total=0; for(i=2;i<=9;i++) total+=$i; print total, $5+$6; exit}' /proc/stat; }
read -r total_before idle_before < <(cpu_sample)
sleep 1
read -r total_after idle_after < <(cpu_sample)
cpu=$(awk -v t="$((total_after-total_before))" -v i="$((idle_after-idle_before))" 'BEGIN {printf "%.2f", (t>0 ? 100*(t-i)/t : 0)}')
memory=$(awk '/MemTotal:/ {t=$2} /MemAvailable:/ {a=$2} END {if(t<=0) exit 1; printf "%.2f", 100*(t-a)/t}' /proc/meminfo)
read -r load1 load5 load15 _ < /proc/loadavg
timestamp=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
status=0 warnings=() disks=() processes=()
check_threshold() {
  local name=$1 value=$2 warning=$3
  if awk -v value="$value" -v critical="$critical_threshold" 'BEGIN {exit !(value>=critical)}'; then
    status=2; warnings+=("$name at $value% (critical >= $critical_threshold%)")
  elif awk -v value="$value" -v warning="$warning" 'BEGIN {exit !(value>=warning)}'; then
    ((status >= 1)) || status=1
    warnings+=("$name at $value% (warning >= $warning%)")
  fi
}
check_threshold CPU "$cpu" "$cpu_threshold"
check_threshold Memory "$memory" "$mem_threshold"
disk_output=$(df -P -B1 --all)
while read -r filesystem size used available percent mount; do
  [[ $size =~ ^[0-9]+$ ]] || continue
  percent=${percent%\%}; [[ $percent =~ ^[0-9]+$ ]] || percent=0
  disks+=("{\"filesystem\":\"$(escape_json "$filesystem")\",\"mount\":\"$(escape_json "$mount")\",\"size_bytes\":$size,\"used_bytes\":$used,\"available_bytes\":$available,\"used_percent\":$percent}")
  if ((size > 0)); then check_threshold "Disk $mount" "$percent" "$disk_threshold"; fi
done <<< "$disk_output"
process_output=$(ps -eo pid=,%mem=,comm= --sort=-%mem)
count=0
while read -r pid mem command; do
  ((count < 5)) || break
  processes+=("{\"pid\":$pid,\"memory_percent\":$mem,\"command\":\"$(escape_json "$command")\"}")
  count=$((count+1))
done <<< "$process_output"
warnings_json=()
for warning in "${warnings[@]}"; do
  printf '[WARNING] %s\n' "$warning" >&2
  warnings_json+=("\"$(escape_json "$warning")\"")
done
join_comma() { local IFS=,; printf '%s' "$*"; }
report="{\"timestamp\":\"$timestamp\",\"status\":$status,\"cpu_percent\":$cpu,\"memory_percent\":$memory,\"load_average\":[$load1,$load5,$load15],\"disks\":[$(join_comma "${disks[@]}")],\"top_processes\":[$(join_comma "${processes[@]}")],\"warnings\":[$(join_comma "${warnings_json[@]}")]}"
if ! $json; then
  report="[$timestamp] status=$status CPU=$cpu% Memory=$memory% Load=$load1,$load5,$load15
Disks: $(join_comma "${disks[@]}")
Top 5 processes: $(join_comma "${processes[@]}")
Warnings: $(join_comma "${warnings[@]}")"
fi
exec 9>"${log_file}.lock"
flock -x 9
if [[ -f $log_file ]] && (($(wc -c < "$log_file") + ${#report} + 1 > max_bytes)); then
  for ((i=keep; i>=2; i--)); do
    [[ ! -f ${log_file}.$((i-1)) ]] || mv -f -- "${log_file}.$((i-1))" "${log_file}.$i"
  done
  mv -f -- "$log_file" "${log_file}.1"
fi
printf '%s\n' "$report" >> "$log_file"
flock -u 9
printf '%s\n' "$report"
exit "$status"
