#!/usr/bin/env bash
set -euo pipefail
# Prevent credentials being exposed by shell tracing.
set +x

profile="${1:?Usage: bash scripts/test-api.sh AWS_PROFILE}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
tf_dir="$script_dir/../infra/environments/dev"

for command in aws terraform curl node; do
  command -v "$command" >/dev/null || {
    echo "Missing command: $command" >&2
    exit 1
  }
done

body_file="$(mktemp)"
cleanup() {
  rm -f -- "$body_file"
  unset credentials access_key secret_key session_token
}
trap cleanup EXIT

credentials="$(aws configure export-credentials \
  --profile "$profile" --format process)"

read_credential() {
  printf '%s' "$credentials" |
    node -e '
      let input = "";
      process.stdin.on("data", chunk => input += chunk);
      process.stdin.on("end", () => {
        const value = JSON.parse(input)[process.argv[1]];
        if (typeof value !== "string" || !value ||
            /[^\x20-\x7e]|["\\]/.test(value)) {
          process.exit(1);
        }
        process.stdout.write(value);
      });
    ' "$1"
}

access_key="$(read_credential AccessKeyId)"
secret_key="$(read_credential SecretAccessKey)"
session_token="$(read_credential SessionToken)"
unset credentials

for output in health_url database_health_url; do
  url="$(terraform "-chdir=$tf_dir" output -raw "$output")"
  url="${url//$'\r'/}"

  if [[ "$url" =~ ^https://[a-z0-9]+\.execute-api\.([a-z0-9-]+)\.amazonaws\.com/health(/db)?$ ]]; then
    region="${BASH_REMATCH[1]}"
  else
    echo "Unexpected API endpoint: $url" >&2
    exit 1
  fi

  echo "Testing $url"

  # Bash printf sends plain text without a BOM.
  # Credentials go through stdin, not curl arguments.
  http_status="$(
    printf '%s\n' \
      "aws-sigv4 = \"aws:amz:${region}:execute-api\"" \
      "user = \"${access_key}:${secret_key}\"" \
      "header = \"x-amz-security-token: ${session_token}\"" |
      curl --disable --config - --silent --show-error \
        --connect-timeout 10 --max-time 30 \
        --output "$body_file" \
        --write-out '%{http_code}' \
        --url "$url"
  )"

  if [[ "$http_status" != "200" ]]; then
    echo "FAIL HTTP $http_status: check IAM permissions and application logs." >&2
    exit 1
  fi

  node -e '
    const fs = require("node:fs");
    const result = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    if (result.status !== "ok" ||
        (process.argv[2] === "database_health_url" &&
         result.database !== "ok")) {
      console.error("Unexpected health response");
      process.exit(1);
    }
  ' "$body_file" "$output"

  printf 'PASS HTTP 200: '
  cat "$body_file"
  printf '\n'
done

echo "Both API health checks passed."