#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$SKILL_DIR/.env"

expand_path() {
  local p="$1"
  if [[ "$p" == "~" ]]; then
    printf '%s' "$HOME"
  elif [[ "$p" == ~/* ]]; then
    printf '%s/%s' "$HOME" "${p#~/}"
  else
    printf '%s' "$p"
  fi
}

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a
  source "$ENV_FILE"
  set +a
fi

BLOG_REPO_PATH="$(expand_path "${BLOG_REPO_PATH:-$HOME/project/blog}")"
PREVIEW_HOST="${PREVIEW_HOST:-localhost}"
PREVIEW_PORT="${PREVIEW_PORT:-4000}"
PREVIEW_LOG_DIR="$(expand_path "${PREVIEW_LOG_DIR:-$HOME/tmp}")"
LOG_FILE="$PREVIEW_LOG_DIR/hexo-preview-${PREVIEW_PORT}.log"
PID_FILE="$PREVIEW_LOG_DIR/hexo-preview-${PREVIEW_PORT}.pid"

BIND_HOST="$PREVIEW_HOST"
CHECK_HOST="$PREVIEW_HOST"
if [[ "$BIND_HOST" == "localhost" ]]; then
  BIND_HOST="127.0.0.1"
  CHECK_HOST="127.0.0.1"
elif [[ "$BIND_HOST" == "0.0.0.0" ]]; then
  CHECK_HOST="127.0.0.1"
fi

if [[ ! -d "$BLOG_REPO_PATH" ]]; then
  echo "REPO_NOT_FOUND|$BLOG_REPO_PATH"
  exit 2
fi

if ! git -C "$BLOG_REPO_PATH" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "NOT_A_GIT_REPO|$BLOG_REPO_PATH"
  exit 3
fi

mkdir -p "$PREVIEW_LOG_DIR"
: > "$LOG_FILE"

port_is_free() {
  python - "$BIND_HOST" "$PREVIEW_PORT" <<'PY'
import socket, sys
host = sys.argv[1]
port = int(sys.argv[2])
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
try:
    s.bind((host, port))
except OSError:
    sys.exit(1)
else:
    sys.exit(0)
finally:
    s.close()
PY
}

port_accepting() {
  python - "$CHECK_HOST" "$PREVIEW_PORT" <<'PY'
import socket, sys
host = sys.argv[1]
port = int(sys.argv[2])
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(1)
try:
    ok = s.connect_ex((host, port)) == 0
except OSError:
    ok = False
finally:
    s.close()
sys.exit(0 if ok else 1)
PY
}

kill_pid_if_running() {
  local pid="$1"
  [[ -z "$pid" ]] && return 0
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    sleep 1
  fi
  if kill -0 "$pid" 2>/dev/null; then
    kill -9 "$pid" 2>/dev/null || true
    sleep 1
  fi
}

clear_preview_port() {
  if port_is_free; then
    return 0
  fi

  if [[ -f "$PID_FILE" ]]; then
    kill_pid_if_running "$(cat "$PID_FILE" 2>/dev/null || true)"
    rm -f "$PID_FILE"
  fi

  pkill -f "openclaw-hexo-preview-$PREVIEW_PORT" 2>/dev/null || true
  pkill -f "hexo s --ip $PREVIEW_HOST --port $PREVIEW_PORT" 2>/dev/null || true
  pkill -f "hexo server --ip $PREVIEW_HOST --port $PREVIEW_PORT" 2>/dev/null || true
  sleep 1

  if ! port_is_free; then
    echo "PORT_STILL_BUSY|$PREVIEW_PORT"
    exit 4
  fi
}

clear_preview_port

if ! (
  cd "$BLOG_REPO_PATH"
  hexo clean >>"$LOG_FILE" 2>&1
  hexo g >>"$LOG_FILE" 2>&1
); then
  echo "BUILD_FAIL|$LOG_FILE"
  exit 5
fi

(
  cd "$BLOG_REPO_PATH"
  nohup bash -lc "exec -a openclaw-hexo-preview-$PREVIEW_PORT hexo s --ip $PREVIEW_HOST --port $PREVIEW_PORT" >>"$LOG_FILE" 2>&1 &
  echo $! >"$PID_FILE"
)

preview_pid="$(cat "$PID_FILE")"

for _ in $(seq 1 15); do
  if port_accepting && kill -0 "$preview_pid" 2>/dev/null; then
    echo "PREVIEW_OK|http://$PREVIEW_HOST:$PREVIEW_PORT|$preview_pid|$LOG_FILE"
    exit 0
  fi

  if ! kill -0 "$preview_pid" 2>/dev/null; then
    first_line="$(head -n 1 "$LOG_FILE" 2>/dev/null || true)"
    echo "PREVIEW_FAIL|process_exited|${first_line:-see_log}|$LOG_FILE"
    exit 6
  fi

  sleep 1
done

echo "PREVIEW_FAIL|timeout_waiting_for_port|$LOG_FILE"
exit 7
