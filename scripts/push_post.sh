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

BLOG_REPO_PATH="$(expand_path "${BLOG_REPO_PATH:-$HOME/blog}")"
POSTS_SUBDIR="${POSTS_SUBDIR:-source/_posts}"
EXPORT_DIR="$(expand_path "${EXPORT_DIR:-$HOME/.openclaw/workspace/exports}")"
TRASH_EXPORT_DIR="$(expand_path "${TRASH_EXPORT_DIR:-$HOME/.openclaw/trash/exports}")"
REMOTE_NAME="${REMOTE_NAME:-origin}"
BRANCH="${BRANCH:-master}"
REPO_SSH_URL="${REPO_SSH_URL:-<repo-ssh-url>}"

post_input="${1:-}"
commit_message="${2:-}"

if [[ -z "$post_input" ]]; then
  echo "USAGE|bash scripts/push_post.sh <post_filename_or_path> [commit_message]"
  exit 64
fi

if [[ ! -d "$BLOG_REPO_PATH" ]]; then
  echo "REPO_NOT_FOUND|$BLOG_REPO_PATH|git clone $REPO_SSH_URL $BLOG_REPO_PATH"
  exit 2
fi

if ! git -C "$BLOG_REPO_PATH" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "NOT_A_GIT_REPO|$BLOG_REPO_PATH"
  exit 3
fi

if [[ "$post_input" = /* ]]; then
  post_abs="$post_input"
elif [[ "$post_input" == */* ]]; then
  post_abs="$BLOG_REPO_PATH/$post_input"
else
  post_abs="$BLOG_REPO_PATH/$POSTS_SUBDIR/$post_input"
fi

if [[ ! -f "$post_abs" ]]; then
  echo "POST_NOT_FOUND|$post_abs"
  exit 4
fi

case "$post_abs" in
  "$BLOG_REPO_PATH"/*)
    post_rel="${post_abs#"$BLOG_REPO_PATH"/}"
    ;;
  *)
    echo "POST_OUTSIDE_REPO|$post_abs|$BLOG_REPO_PATH"
    exit 5
    ;;
esac

git -C "$BLOG_REPO_PATH" add -- "$post_rel"

if git -C "$BLOG_REPO_PATH" diff --cached --quiet -- "$post_rel"; then
  echo "NO_CHANGES|$post_rel"
  exit 0
fi

if [[ -z "$commit_message" ]]; then
  commit_message="post: update $(basename "$post_rel")"
fi

git -C "$BLOG_REPO_PATH" commit -m "$commit_message" -- "$post_rel"

if ! git -C "$BLOG_REPO_PATH" push "$REMOTE_NAME" "$BRANCH" >/dev/null; then
  echo "PUSH_FAIL|$REMOTE_NAME|$BRANCH|$post_rel"
  exit 6
fi

commit_hash="$(git -C "$BLOG_REPO_PATH" rev-parse --short HEAD)"

# Best-effort cleanup: remove preview artifact from EXPORT_DIR after a successful push.
# (Move to trash to avoid destructive deletes.)
export_file="$EXPORT_DIR/$(basename "$post_rel")"
if [[ -f "$export_file" ]]; then
  mkdir -p "$TRASH_EXPORT_DIR" >/dev/null 2>&1 || true
  base="$(basename "$export_file")"
  dest="$TRASH_EXPORT_DIR/$base"
  if [[ -e "$dest" ]]; then
    name="${base%.*}"
    ext="${base##*.}"
    dest="$TRASH_EXPORT_DIR/${name}_$(date +%Y%m%d_%H%M%S).$ext"
  fi
  mv "$export_file" "$dest" >/dev/null 2>&1 || true
fi

echo "PUSH_OK|$commit_hash|$REMOTE_NAME|$BRANCH|$post_rel"
