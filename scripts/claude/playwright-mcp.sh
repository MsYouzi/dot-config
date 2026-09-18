#!/usr/bin/env bash
set -euo pipefail

umask 077

CLEANUP_HELPER="${CLAUDE_CLEANUP_HELPER:-${HOME:?HOME is required}/.claude/session-cleanup.sh}"
PROXY_SCRIPT="${PLAYWRIGHT_MCP_PROXY:-${HOME}/.claude/playwright-mcp-proxy.js}"
ROOT="${CLAUDE_CLEANUP_ROOT:-}"
TOKEN="${CLAUDE_CLEANUP_TOKEN:-}"
PRIVATE_ROOT=0

[ -x "$CLEANUP_HELPER" ] || {
  printf 'playwright-mcp.sh: cleanup helper is not executable: %s\n' "$CLEANUP_HELPER" >&2
  exit 1
}
[ -f "$PROXY_SCRIPT" ] || {
  printf 'playwright-mcp.sh: MCP proxy is missing: %s\n' "$PROXY_SCRIPT" >&2
  exit 1
}

if [ -z "$ROOT" ] || [ -z "$TOKEN" ]; then
  [ -z "$ROOT" ] && [ -z "$TOKEN" ] || {
    printf 'playwright-mcp.sh: partial cleanup ownership environment\n' >&2
    exit 1
  }
  allocation="$("$CLEANUP_HELPER" allocate playwright)"
  ROOT="${allocation%%$'\t'*}"
  TOKEN="${allocation#*$'\t'}"
  PRIVATE_ROOT=1
else
  if ! "$CLEANUP_HELPER" validate "$ROOT" "$TOKEN" >/dev/null 2>&1; then
    # Claude Code itself starts MCP servers before SessionStart can persist a
    # direct-launch cleanup namespace. Never trust stale inherited ownership.
    allocation="$("$CLEANUP_HELPER" allocate playwright)"
    ROOT="${allocation%%$'\t'*}"
    TOKEN="${allocation#*$'\t'}"
    PRIVATE_ROOT=1
  fi
fi

PLAYWRIGHT_TMP="$ROOT/playwright-tmp"
PLAYWRIGHT_OUTPUT="$ROOT/playwright-output"
mkdir -p "$PLAYWRIGHT_TMP" "$PLAYWRIGHT_OUTPUT"
chmod 700 "$PLAYWRIGHT_TMP" "$PLAYWRIGHT_OUTPUT"

export CLAUDE_CLEANUP_ROOT="$ROOT"
export CLAUDE_CLEANUP_TOKEN="$TOKEN"
export CLAUDE_CLEANUP_HELPER="$CLEANUP_HELPER"
export PLAYWRIGHT_MCP_PRIVATE_ROOT="$PRIVATE_ROOT"

exec node "$PROXY_SCRIPT"
