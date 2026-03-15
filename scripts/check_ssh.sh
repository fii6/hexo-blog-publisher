#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$SKILL_DIR/.env"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a
  source "$ENV_FILE"
  set +a
fi

REPO_SSH_URL="${REPO_SSH_URL:-}"
if [[ -z "$REPO_SSH_URL" ]]; then
  echo "SSH_CONFIG_MISSING|REPO_SSH_URL is empty in $ENV_FILE"
  exit 2
fi

extract_endpoint() {
  local url="$1"

  if [[ "$url" =~ ^ssh://([^/]+)/ ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  fi

  if [[ "$url" =~ ^([^@[:space:]]+@[^:[:space:]]+):.+$ ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  fi

  return 1
}

if ! endpoint="$(extract_endpoint "$REPO_SSH_URL")"; then
  echo "SSH_CONFIG_INVALID|cannot_parse_endpoint|$REPO_SSH_URL"
  exit 3
fi

set +e
ssh_output="$(ssh -T -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new "$endpoint" 2>&1)"
ssh_code=$?
set -e

if [[ $ssh_code -eq 0 ]] || grep -Eiq 'successfully authenticated|welcome to gitlab|shell access is disabled|logged in as|hi .*!' <<<"$ssh_output"; then
  echo "SSH_OK|$endpoint"
  exit 0
fi

first_line="$(printf '%s\n' "$ssh_output" | head -n 1)"
echo "SSH_FAIL|$endpoint|$first_line"
exit 1
