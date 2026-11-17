#!/usr/bin/env bash
set -euo pipefail
terraform_version=1.13.5
tools_dir=${RUNNER_TEMP:-/tmp}/assessment-tools
mkdir -p "$tools_dir"
curl -fsSL "https://releases.hashicorp.com/terraform/$terraform_version/terraform_$terraform_version"'_linux_amd64.zip' -o "$tools_dir/terraform.zip"
curl -fsSL "https://releases.hashicorp.com/terraform/$terraform_version/terraform_$terraform_version"'_SHA256SUMS' -o "$tools_dir/SHA256SUMS"
expected=$(awk '/linux_amd64.zip$/ {print $1}' "$tools_dir/SHA256SUMS")
printf '%s  %s\n' "$expected" "$tools_dir/terraform.zip" | sha256sum --check
unzip -o -q "$tools_dir/terraform.zip" -d "$tools_dir"
"$tools_dir/terraform" fmt -check -recursive terraform
for directory in terraform terraform/bootstrap; do
  "$tools_dir/terraform" -chdir="$directory" init -backend=false -input=false -lockfile=readonly
  "$tools_dir/terraform" -chdir="$directory" validate
done
