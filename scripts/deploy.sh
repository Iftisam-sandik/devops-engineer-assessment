#!/usr/bin/env bash
set -euo pipefail
# SSM invokes this root-owned script; it is also exercised locally with json-file logs.
image=${1:?Usage: deploy.sh registry/repository:tag-or-digest}
[[ $image =~ ^[a-zA-Z0-9][a-zA-Z0-9._:/@-]+$ && $image != -* ]] || { echo 'Invalid image reference' >&2; exit 2; }
app_name=${APP_NAME:-devops-app}
env_file=${APP_ENV_FILE:-/etc/devops-app/app.env}
lock_file=${DEPLOY_LOCK:-/var/lock/devops-app-deploy.lock}
port=${APP_HOST_PORT:-8080}
log_driver=${APP_LOG_DRIVER:-json-file}
health_attempts=${HEALTH_ATTEMPTS:-30}
exec 9>"$lock_file"
flock -n 9 || { echo 'Another deployment is running' >&2; exit 2; }
docker pull "$image"
previous="${app_name}-previous"
had_previous=false
rollback() {
  local code=$?
  trap - ERR
  printf 'Deployment failed; restoring previous container (exit=%s)\n' "$code" >&2
  docker rm -f "$app_name" >/dev/null 2>&1 || true
  if $had_previous; then
    docker rename "$previous" "$app_name"
    docker start "$app_name" >/dev/null
    for ((i=0; i<health_attempts; i++)); do
      if curl -fsS --max-time 2 "http://127.0.0.1:$port/health"; then
        echo 'ROLLBACK_SUCCEEDED'; exit "$code"
      fi
      sleep 2
    done
    echo 'ROLLBACK_HEALTH_FAILED' >&2
  fi
  exit "$code"
}
# Do not touch a working container until the image has been pulled successfully.
docker rm -f "$previous" >/dev/null 2>&1 || true
if docker inspect "$app_name" >/dev/null 2>&1; then
  docker rename "$app_name" "$previous"
  had_previous=true
  trap rollback ERR
  docker stop --time 15 "$previous" >/dev/null
fi
trap rollback ERR
logging=(--log-driver "$log_driver")
if [[ $log_driver == awslogs ]]; then
  : "${AWS_REGION:?AWS_REGION required}" "${APP_LOG_GROUP:?APP_LOG_GROUP required}"
  logging+=(--log-opt "awslogs-region=$AWS_REGION" --log-opt "awslogs-group=$APP_LOG_GROUP" --log-opt "awslogs-stream=$app_name" --log-opt awslogs-create-group=false)
else
  logging+=(--log-opt max-size=10m --log-opt max-file=3)
fi
docker run -d --name "$app_name" --restart unless-stopped --init \
  --env-file "$env_file" --read-only --cap-drop ALL --security-opt no-new-privileges \
  --memory 128m --cpus 0.5 --pids-limit 100 --stop-timeout 15 \
  -p "$port:8080" "${logging[@]}" "$image" >/dev/null
healthy=false
for ((i=0; i<health_attempts; i++)); do
  if curl -fsS --max-time 2 "http://127.0.0.1:$port/health"; then healthy=true; break; fi
  sleep 2
done
if ! $healthy; then false; fi
trap - ERR
echo "DEPLOY_SUCCEEDED image=$image"
# Keep the stopped previous container until the next successful release starts.
