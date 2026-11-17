#!/usr/bin/env bash
set -euo pipefail
instance=${1:?Usage: ssm-deploy.sh i-instance image region}
image=${2:?Image reference required}
region=${3:-ap-south-1}
[[ $instance =~ ^i-[0-9a-f]+$ ]] || { echo 'Invalid instance ID' >&2; exit 2; }
payload=$(mktemp)
trap 'rm -f "$payload"' EXIT
python3 - "$image" "$payload" <<'PY'
import json, shlex, sys
with open(sys.argv[2], 'w') as handle:
    json.dump({'commands': ['/usr/local/bin/deploy-app ' + shlex.quote(sys.argv[1])], 'executionTimeout': ['600']}, handle)
PY
command_id=$(aws ssm send-command --region "$region" --instance-ids "$instance" \
  --document-name AWS-RunShellScript --parameters "file://$payload" \
  --comment 'Deploy immutable assessment image with health validation and rollback' \
  --query Command.CommandId --output text)
for ((i=0; i<65; i++)); do
  status=$(aws ssm get-command-invocation --region "$region" --command-id "$command_id" --instance-id "$instance" --query Status --output text 2>/dev/null || true)
  case "$status" in
    Success)
      aws ssm get-command-invocation --region "$region" --command-id "$command_id" --instance-id "$instance"
      exit 0 ;;
    Failed|Cancelled|TimedOut|Cancelling)
      aws ssm get-command-invocation --region "$region" --command-id "$command_id" --instance-id "$instance"
      exit 1 ;;
  esac
  sleep 10
done
echo 'SSM command did not complete before the workflow deadline' >&2
exit 1
