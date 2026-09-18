#!/usr/bin/env bash
set -euo pipefail

umask 077

SCRIPT_NAME="${0##*/}"
BASE_DIR="${CLAUDE_CLEANUP_BASE:-/tmp/claude-code-$(id -u)-cleanup}"
if [[ "$BASE_DIR" != /* ]]; then
  BASE_DIR="$PWD/$BASE_DIR"
fi
ROOTS_DIR="${BASE_DIR}/roots"
REGISTRY_DIR="${BASE_DIR}/registry"
MARKER_NAME=".claude-cleanup-owner"
VALID_ROOT=""
VALID_TOKEN=""
VALID_KIND=""
RESOLVED_ROOT=""
RESOLVED_TOKEN=""
LAUNCH_ROOT=""
LAUNCH_TOKEN=""

log_error() {
  printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2
}

fail() {
  log_error "$*"
  return 1
}

path_uid() {
  if [ "$(uname -s)" = "Darwin" ]; then
    stat -f '%u' "$1"
  else
    stat -c '%u' "$1"
  fi
}

path_mode() {
  if [ "$(uname -s)" = "Darwin" ]; then
    stat -f '%Lp' "$1"
  else
    stat -c '%a' "$1"
  fi
}

path_mtime() {
  if [ "$(uname -s)" = "Darwin" ]; then
    stat -f '%m' "$1"
  else
    stat -c '%Y' "$1"
  fi
}

ensure_private_dir() {
  local dir="$1"
  if [ -L "$dir" ]; then
    fail "refusing symlinked directory: $dir"
    return 1
  fi
  mkdir -p "$dir"
  chmod 700 "$dir"
  if [ "$(path_uid "$dir")" != "$(id -u)" ]; then
    fail "directory is not owned by the current user: $dir"
    return 1
  fi
}

ensure_layout() {
  case "$BASE_DIR" in
    /*) ;;
    *) fail "cleanup base must be absolute: $BASE_DIR"; return 1 ;;
  esac
  ensure_private_dir "$BASE_DIR"
  ensure_private_dir "$ROOTS_DIR"
  ensure_private_dir "$REGISTRY_DIR"
}

marker_value() {
  local key="$1"
  local marker="$2"
  local current value
  while IFS='=' read -r current value; do
    if [ "$current" = "$key" ]; then
      printf '%s\n' "$value"
      return 0
    fi
  done <"$marker"
  return 1
}

new_token() {
  local token
  if command -v uuidgen >/dev/null 2>&1; then
    token="$(uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '-')"
  elif command -v openssl >/dev/null 2>&1; then
    token="$(openssl rand -hex 16)"
  else
    token="$(date +%s)-$$-${RANDOM}-${RANDOM}"
  fi
  printf '%s\n' "$token"
}

hash_text() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | cut -d ' ' -f 1
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum | cut -d ' ' -f 1
  else
    cksum | tr ' ' '-'
  fi
}

validate_root() {
  local root="$1"
  local expected_token="$2"
  local canonical_roots canonical_root marker marker_uid marker_token marker_name marker_version marker_kind

  VALID_ROOT=""
  VALID_TOKEN=""
  VALID_KIND=""
  [ -n "$root" ] || { fail "empty cleanup root"; return 1; }
  [ -n "$expected_token" ] || { fail "empty cleanup token"; return 1; }
  ensure_layout
  [ -d "$root" ] || { fail "cleanup root does not exist: $root"; return 1; }
  [ ! -L "$root" ] || { fail "refusing symlinked cleanup root: $root"; return 1; }

  canonical_roots="$(realpath "$ROOTS_DIR")"
  canonical_root="$(realpath "$root")"
  case "$canonical_root" in
    "$canonical_roots"/*) ;;
    *) fail "cleanup root is outside the owned namespace: $canonical_root"; return 1 ;;
  esac
  [ "$canonical_root" != "$canonical_roots" ] || { fail "refusing cleanup namespace root"; return 1; }
  [ "$(path_uid "$canonical_root")" = "$(id -u)" ] || {
    fail "cleanup root belongs to another uid: $canonical_root"
    return 1
  }
  [ "$(path_mode "$canonical_root")" = "700" ] || {
    fail "cleanup root permissions are not 0700: $canonical_root"
    return 1
  }

  marker="$canonical_root/$MARKER_NAME"
  [ -f "$marker" ] && [ ! -L "$marker" ] || {
    fail "cleanup ownership marker is missing or unsafe: $canonical_root"
    return 1
  }
  [ "$(path_uid "$marker")" = "$(id -u)" ] || {
    fail "cleanup marker belongs to another uid: $marker"
    return 1
  }

  marker_version="$(marker_value version "$marker" || true)"
  marker_uid="$(marker_value uid "$marker" || true)"
  marker_token="$(marker_value token "$marker" || true)"
  marker_name="$(marker_value root_name "$marker" || true)"
  marker_kind="$(marker_value kind "$marker" || true)"
  [ "$marker_version" = "1" ] || { fail "unsupported cleanup marker version"; return 1; }
  [ "$marker_uid" = "$(id -u)" ] || { fail "cleanup marker uid mismatch"; return 1; }
  [ "$marker_token" = "$expected_token" ] || { fail "cleanup token mismatch"; return 1; }
  [ "$marker_name" = "${canonical_root##*/}" ] || { fail "cleanup root-name mismatch"; return 1; }
  case "$marker_kind" in
    launch|session|playwright) ;;
    *) fail "invalid cleanup root kind"; return 1 ;;
  esac

  VALID_ROOT="$canonical_root"
  VALID_TOKEN="$marker_token"
  VALID_KIND="$marker_kind"
}

allocate_root() {
  local kind="$1"
  local root token marker_tmp
  case "$kind" in
    launch|session|playwright) ;;
    *) fail "invalid root kind: $kind"; return 1 ;;
  esac
  ensure_layout
  root="$(mktemp -d "$ROOTS_DIR/runtime.XXXXXXXX")"
  chmod 700 "$root"
  token="$(new_token)"
  marker_tmp="$root/.owner.$$"
  printf 'version=1\nuid=%s\ntoken=%s\nroot_name=%s\nkind=%s\ncreated_at=%s\n' \
    "$(id -u)" "$token" "${root##*/}" "$kind" "$(date +%s)" >"$marker_tmp"
  chmod 600 "$marker_tmp"
  mv "$marker_tmp" "$root/$MARKER_NAME"
  mkdir -m 700 "$root/tools" "$root/playwright-tmp" "$root/playwright-output"
  printf '%s\t%s\n' "$root" "$token"
}

session_key() {
  local session_id="$1"
  [ -n "$session_id" ] || return 1
  printf '%s' "$session_id" | hash_text
}

register_session() {
  local session_id="$1"
  local root="$2"
  local token="$3"
  local key mapping_tmp mapping
  validate_root "$root" "$token"
  root="$VALID_ROOT"
  key="$(session_key "$session_id")"
  mapping="$REGISTRY_DIR/session-$key"
  mapping_tmp="$REGISTRY_DIR/.session-$key.$$.$RANDOM"
  printf 'version=1\nsession_hash=%s\nroot_name=%s\ntoken=%s\n' \
    "$key" "${root##*/}" "$token" >"$mapping_tmp"
  chmod 600 "$mapping_tmp"
  mv "$mapping_tmp" "$mapping"
}

resolve_session() {
  local session_id="$1"
  local key mapping version stored_hash root_name token root

  RESOLVED_ROOT=""
  RESOLVED_TOKEN=""
  ensure_layout

  if [ -n "${CLAUDE_CLEANUP_ROOT:-}" ] || [ -n "${CLAUDE_CLEANUP_TOKEN:-}" ]; then
    [ -n "${CLAUDE_CLEANUP_ROOT:-}" ] && [ -n "${CLAUDE_CLEANUP_TOKEN:-}" ] || {
      fail "partial cleanup ownership environment"
      return 1
    }
    validate_root "$CLAUDE_CLEANUP_ROOT" "$CLAUDE_CLEANUP_TOKEN"
    RESOLVED_ROOT="$VALID_ROOT"
    RESOLVED_TOKEN="$VALID_TOKEN"
    return 0
  fi

  key="$(session_key "$session_id")"
  mapping="$REGISTRY_DIR/session-$key"
  [ -f "$mapping" ] || return 2
  [ ! -L "$mapping" ] || { fail "refusing symlinked session mapping"; return 1; }
  [ "$(path_uid "$mapping")" = "$(id -u)" ] || { fail "session mapping uid mismatch"; return 1; }
  version="$(marker_value version "$mapping" || true)"
  stored_hash="$(marker_value session_hash "$mapping" || true)"
  root_name="$(marker_value root_name "$mapping" || true)"
  token="$(marker_value token "$mapping" || true)"
  [ "$version" = "1" ] && [ "$stored_hash" = "$key" ] || {
    fail "invalid session mapping"
    return 1
  }
  [ -n "$root_name" ] && [ "$root_name" = "${root_name##*/}" ] || {
    fail "unsafe root name in session mapping"
    return 1
  }
  case "$root_name" in
    runtime.*) ;;
    *) fail "unexpected root name in session mapping"; return 1 ;;
  esac
  root="$ROOTS_DIR/$root_name"
  validate_root "$root" "$token"
  RESOLVED_ROOT="$VALID_ROOT"
  RESOLVED_TOKEN="$VALID_TOKEN"
}

remove_mappings_for_root() {
  local root_name="$1"
  local mapping mapped_name
  ensure_layout
  for mapping in "$REGISTRY_DIR"/session-*; do
    [ -f "$mapping" ] || continue
    [ ! -L "$mapping" ] || continue
    mapped_name="$(marker_value root_name "$mapping" || true)"
    if [ "$mapped_name" = "$root_name" ]; then
      rm -f -- "$mapping"
    fi
  done
}

owned_child_path() {
  local root="$1"
  local name="$2"
  case "$name" in
    tools|playwright-tmp|playwright-output) ;;
    *) fail "invalid cleanup child: $name"; return 1 ;;
  esac
  printf '%s/%s\n' "$root" "$name"
}

reset_child() {
  local root="$1"
  local name="$2"
  local child
  child="$(owned_child_path "$root" "$name")"
  rm -rf -- "$child"
  mkdir -m 700 "$child"
}

child_busy() {
  local root="$1"
  local name="$2"
  local path open_pids
  command -v lsof >/dev/null 2>&1 || return 1
  path="$(owned_child_path "$root" "$name")"
  [ -d "$path" ] || return 1
  open_pids="$(lsof -t +D "$path" 2>/dev/null || true)"
  [ -n "$open_pids" ]
}

mark_playwright_close() {
  local root="$1"
  local token="$2"
  local marker_tmp
  validate_root "$root" "$token"
  root="$VALID_ROOT"
  marker_tmp="$root/.playwright-close-active.$$.$RANDOM"
  printf 'token=%s\n' "$token" >"$marker_tmp"
  chmod 600 "$marker_tmp"
  mv "$marker_tmp" "$root/.playwright-close-active"
}

unmark_playwright_close() {
  local root="$1"
  local token="$2"
  validate_root "$root" "$token"
  rm -f -- "$VALID_ROOT/.playwright-close-active"
}

cleanup_playwright_children() {
  local root="$1"
  local token="$2"
  local deferred=0
  validate_root "$root" "$token"
  root="$VALID_ROOT"

  if child_busy "$root" playwright-tmp; then
    deferred=1
  else
    reset_child "$root" playwright-tmp
  fi
  if child_busy "$root" playwright-output; then
    deferred=1
  else
    reset_child "$root" playwright-output
  fi

  if [ "$deferred" -eq 1 ]; then
    : >"$root/.playwright-cleanup-deferred"
  else
    rm -f -- "$root/.playwright-cleanup-deferred"
  fi
}

cleanup_turn_root() {
  local root="$1"
  local token="$2"
  local attempt=0
  validate_root "$root" "$token"
  root="$VALID_ROOT"

  if child_busy "$root" tools; then
    : >"$root/.tools-cleanup-deferred"
  else
    reset_child "$root" tools
    rm -f -- "$root/.tools-cleanup-deferred"
  fi

  while [ -f "$root/.playwright-close-active" ] && [ "$attempt" -lt 50 ]; do
    attempt=$((attempt + 1))
    sleep 0.1
  done
  if [ -f "$root/.playwright-close-active" ]; then
    : >"$root/.playwright-cleanup-deferred"
  fi
}

cleanup_owned_root() {
  local root="$1"
  local token="$2"
  validate_root "$root" "$token"
  root="$VALID_ROOT"
  if child_busy "$root" tools || child_busy "$root" playwright-tmp || \
     child_busy "$root" playwright-output; then
    : >"$root/.root-cleanup-deferred"
    return 0
  fi
  remove_mappings_for_root "${root##*/}"
  rm -rf -- "$root"
}

read_hook_input() {
  HOOK_INPUT="$(cat)"
  HOOK_SESSION_ID="$(printf '%s' "$HOOK_INPUT" | jq -er '.session_id | strings | select(length > 0)')" || {
    fail "hook input has no valid session_id"
    return 1
  }
}

session_start() {
  local allocation root token tools env_file
  read_hook_input
  if resolve_session "$HOOK_SESSION_ID"; then
    root="$RESOLVED_ROOT"
    token="$RESOLVED_TOKEN"
  else
    case "$?" in
      2)
        allocation="$(allocate_root session)"
        root="${allocation%%$'\t'*}"
        token="${allocation#*$'\t'}"
        ;;
      *) return 1 ;;
    esac
  fi
  register_session "$HOOK_SESSION_ID" "$root" "$token"
  tools="$(owned_child_path "$root" tools)"
  env_file="${CLAUDE_ENV_FILE:-}"
  if [ -n "$env_file" ]; then
    printf 'export TMPDIR=%q\nexport TMP=%q\nexport TEMP=%q\n' \
      "$tools/" "$tools/" "$tools/" >>"$env_file"
    printf 'export CLAUDE_CLEANUP_ROOT=%q\nexport CLAUDE_CLEANUP_TOKEN=%q\n' \
      "$root" "$token" >>"$env_file"
  fi
}

turn_cleanup() {
  read_hook_input
  if resolve_session "$HOOK_SESSION_ID"; then
    cleanup_turn_root "$RESOLVED_ROOT" "$RESOLVED_TOKEN"
  else
    case "$?" in
      2) return 0 ;;
      *) return 1 ;;
    esac
  fi
}

session_end() {
  read_hook_input
  if resolve_session "$HOOK_SESSION_ID"; then
    validate_root "$RESOLVED_ROOT" "$RESOLVED_TOKEN"
    if [ "$VALID_KIND" = "launch" ]; then
      cleanup_turn_root "$VALID_ROOT" "$VALID_TOKEN"
    else
      cleanup_owned_root "$VALID_ROOT" "$VALID_TOKEN"
    fi
  else
    case "$?" in
      2) return 0 ;;
      *) return 1 ;;
    esac
  fi
}

launch_claude() {
  local allocation root token rc
  local child_pid=""
  local forwarded_signal=""
  [ "$#" -gt 0 ] || { fail "launch requires a Claude executable and arguments"; return 2; }
  [ -x "$1" ] || { fail "Claude executable is not executable: $1"; return 2; }
  allocation="$(allocate_root launch)"
  root="${allocation%%$'\t'*}"
  token="${allocation#*$'\t'}"

  LAUNCH_ROOT="$root"
  LAUNCH_TOKEN="$token"
  cleanup_launch_root() {
    if [ -n "${LAUNCH_ROOT:-}" ] && [ -d "$LAUNCH_ROOT" ]; then
      cleanup_owned_root "$LAUNCH_ROOT" "$LAUNCH_TOKEN" || true
    fi
  }
  forward_launch_signal() {
    forwarded_signal="$1"
    if [ -n "$child_pid" ]; then
      kill -"$1" "$child_pid" >/dev/null 2>&1 || true
    fi
  }
  trap cleanup_launch_root EXIT
  trap 'forward_launch_signal HUP' HUP
  trap 'forward_launch_signal INT' INT
  trap 'forward_launch_signal TERM' TERM

  set +e
  CLAUDE_CLEANUP_ROOT="$root" CLAUDE_CLEANUP_TOKEN="$token" "$@" <&0 &
  child_pid=$!
  while :; do
    wait "$child_pid"
    rc=$?
    if kill -0 "$child_pid" >/dev/null 2>&1; then
      continue
    fi
    break
  done
  child_pid=""
  set -e
  case "$forwarded_signal" in
    HUP) return 129 ;;
    INT) return 130 ;;
    TERM) return 143 ;;
  esac
  return "$rc"
}

inventory_row() {
  local classification="$1"
  local path="$2"
  local policy="$3"
  local size_kib=0 count=0 modified=0
  if [ -e "$path" ]; then
    size_kib="$(du -sk "$path" 2>/dev/null | cut -f 1 || printf '0')"
    modified="$(path_mtime "$path" 2>/dev/null || printf '0')"
    if [ -d "$path" ]; then
      count="$(find "$path" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')"
    else
      count=1
    fi
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$classification" "$path" "$size_kib" "$count" "$modified" "$policy"
}

inventory() {
  local system_tmp artifact_count artifact_size path
  printf 'classification\tpath\tsize_kib\tentries\tmtime_epoch\tpolicy\n'
  inventory_row owned-runtime "$ROOTS_DIR" auto-managed

  system_tmp="${TMPDIR:-/tmp}"
  artifact_count=0
  artifact_size=0
  for path in "$system_tmp"/playwright-artifacts-*; do
    [ -d "$path" ] || continue
    artifact_count=$((artifact_count + 1))
    artifact_size=$((artifact_size + $(du -sk "$path" 2>/dev/null | cut -f 1 || printf '0')))
  done
  printf 'legacy-playwright-artifacts\t%s/playwright-artifacts-*\t%s\t%s\t0\treview-delete-candidate\n' \
    "$system_tmp" "$artifact_size" "$artifact_count"

  inventory_row project-playwright-output "$PWD/.playwright-mcp" review-delete-candidate
  if [ "$PWD/.playwright-mcp" != "$HOME/Workspace/.playwright-mcp" ]; then
    inventory_row project-playwright-output "$HOME/Workspace/.playwright-mcp" review-delete-candidate
  fi
  inventory_row persistent-mcp-profile "$HOME/Library/Caches/ms-playwright-mcp" review-required
  inventory_row browser-binaries "$HOME/Library/Caches/ms-playwright" keep
}

usage() {
  cat >&2 <<'USAGE'
usage: session-cleanup.sh <command> [args]
  launch <claude-bin> [args...]       run Claude in an owned cleanup namespace
  session-start                       initialize from SessionStart hook JSON
  turn                               clean this turn's owned temporary files
  session-end                         final cleanup from SessionEnd hook JSON
  allocate <launch|session|playwright>
  validate <root> <token>             verify ownership without changing files
  cleanup-owned <root> <token>        remove one validated owned root
  cleanup-playwright <root> <token>   clear only Playwright-owned children
  mark-playwright-close <root> <token>
  unmark-playwright-close <root> <token>
  inventory                           report legacy residue; never deletes it
USAGE
}

command_name="${1:-}"
[ "$#" -gt 0 ] && shift || true
case "$command_name" in
  launch) launch_claude "$@" ;;
  session-start) session_start "$@" ;;
  turn) turn_cleanup "$@" ;;
  session-end) session_end "$@" ;;
  allocate) [ "$#" -eq 1 ] || { usage; exit 2; }; allocate_root "$1" ;;
  validate) [ "$#" -eq 2 ] || { usage; exit 2; }; validate_root "$1" "$2" ;;
  cleanup-owned) [ "$#" -eq 2 ] || { usage; exit 2; }; cleanup_owned_root "$1" "$2" ;;
  cleanup-playwright)
    [ "$#" -eq 2 ] || { usage; exit 2; }
    cleanup_playwright_children "$1" "$2"
    ;;
  mark-playwright-close)
    [ "$#" -eq 2 ] || { usage; exit 2; }
    mark_playwright_close "$1" "$2"
    ;;
  unmark-playwright-close)
    [ "$#" -eq 2 ] || { usage; exit 2; }
    unmark_playwright_close "$1" "$2"
    ;;
  inventory) inventory "$@" ;;
  *) usage; exit 2 ;;
esac
