#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
helper="$repo_root/scripts/claude/session-cleanup.sh"
proxy="$repo_root/scripts/claude/playwright-mcp-proxy.js"
state="$(mktemp -d)"
outside="$(mktemp -d)"
fake_bin="$(mktemp -d)"
server_pid=""

cleanup_test() {
  if [ -n "$server_pid" ]; then
    kill "$server_pid" >/dev/null 2>&1 || true
    wait "$server_pid" >/dev/null 2>&1 || true
  fi
  rm -rf "$state" "$outside" "$fake_bin"
}
trap cleanup_test EXIT

export HOME="$state/home"
export CLAUDE_CLEANUP_BASE="$state/cleanup"
mkdir -p "$HOME/.claude"
ln -s "$helper" "$HOME/.claude/session-cleanup.sh"
ln -s "$proxy" "$HOME/.claude/playwright-mcp-proxy.js"

allocate() {
  "$helper" allocate "$1"
}

root_from() {
  printf '%s\n' "${1%%$'\t'*}"
}

token_from() {
  printf '%s\n' "${1#*$'\t'}"
}

assert_exists() {
  [ -e "$1" ] || { echo "expected path to exist: $1" >&2; exit 1; }
}

assert_missing() {
  [ ! -e "$1" ] || { echo "expected path to be absent: $1" >&2; exit 1; }
}

# Concurrent allocations are unique and private.
a1="$(allocate launch)"
a2="$(allocate launch)"
r1="$(root_from "$a1")"; t1="$(token_from "$a1")"
r2="$(root_from "$a2")"; t2="$(token_from "$a2")"
[ "$r1" != "$r2" ]
[ "$(stat -f '%Lp' "$r1" 2>/dev/null || stat -c '%a' "$r1")" = "700" ]

# SessionStart writes only the session's tool directory to CLAUDE_ENV_FILE.
env_file="$state/session.env"
printf '{"session_id":"session-one","hook_event_name":"SessionStart"}' |
  CLAUDE_ENV_FILE="$env_file" CLAUDE_CLEANUP_ROOT="$r1" CLAUDE_CLEANUP_TOKEN="$t1" \
  "$helper" session-start
canonical_r1="$(realpath "$r1")"
grep -Fq "export TMPDIR=$canonical_r1/tools/" "$env_file"
grep -Fq "export CLAUDE_CLEANUP_ROOT=$canonical_r1" "$env_file"

# A different direct session gets its own fallback root and mapping.
env_file2="$state/session-two.env"
printf '{"session_id":"session-two","hook_event_name":"SessionStart"}' |
  CLAUDE_ENV_FILE="$env_file2" env -u CLAUDE_CLEANUP_ROOT -u CLAUDE_CLEANUP_TOKEN \
  "$helper" session-start
fallback_root="$(grep '^export CLAUDE_CLEANUP_ROOT=' "$env_file2" | cut -d= -f2-)"
[ "$fallback_root" != "$r1" ]
assert_exists "$fallback_root/.claude-cleanup-owner"

# Turn cleanup removes owned tool payloads and leaves everything else alone.
printf 'remove me\n' >"$r1/tools/turn.tmp"
printf 'keep me\n' >"$outside/user-file.txt"
printf '{"session_id":"session-one","hook_event_name":"Stop"}' |
  CLAUDE_CLEANUP_ROOT="$r1" CLAUDE_CLEANUP_TOKEN="$t1" "$helper" turn
assert_missing "$r1/tools/turn.tmp"
assert_exists "$r1/tools"
assert_exists "$outside/user-file.txt"

# A busy tool file is deferred rather than unlinked underneath a running process.
printf 'busy\n' >"$r1/tools/busy.tmp"
python3 - "$r1/tools/busy.tmp" <<'PY' &
import sys, time
with open(sys.argv[1], "r", encoding="utf-8"):
    time.sleep(4)
PY
server_pid=$!
sleep 0.2
printf '{"session_id":"session-one","hook_event_name":"Stop"}' |
  CLAUDE_CLEANUP_ROOT="$r1" CLAUDE_CLEANUP_TOKEN="$t1" "$helper" turn
assert_exists "$r1/tools/busy.tmp"
assert_exists "$r1/.tools-cleanup-deferred"
wait "$server_pid"
server_pid=""

# Playwright close marker serializes the parallel Stop cleanup attempt.
"$helper" mark-playwright-close "$r1" "$t1"
printf '{"session_id":"session-one","hook_event_name":"Stop"}' |
  CLAUDE_CLEANUP_ROOT="$r1" CLAUDE_CLEANUP_TOKEN="$t1" "$helper" turn
assert_exists "$r1/.playwright-cleanup-deferred"
"$helper" unmark-playwright-close "$r1" "$t1"

# Playwright cleanup affects only its validated children.
printf 'pw tmp\n' >"$r1/playwright-tmp/a"
printf 'pw output\n' >"$r1/playwright-output/b"
printf 'tool survives pw cleanup\n' >"$r1/tools/c"
"$helper" cleanup-playwright "$r1" "$t1"
assert_missing "$r1/playwright-tmp/a"
assert_missing "$r1/playwright-output/b"
assert_exists "$r1/tools/c"

# Wrong token, external paths, base root, and symlinks are rejected.
if "$helper" cleanup-owned "$r1" wrong-token >/dev/null 2>&1; then exit 1; fi
if "$helper" cleanup-owned "$outside" "$t1" >/dev/null 2>&1; then exit 1; fi
if "$helper" cleanup-owned "$CLAUDE_CLEANUP_BASE/roots" "$t1" >/dev/null 2>&1; then exit 1; fi
ln -s "$r1" "$state/root-link"
if "$helper" cleanup-owned "$state/root-link" "$t1" >/dev/null 2>&1; then exit 1; fi
assert_exists "$outside/user-file.txt"

# Complete-root cleanup also defers while an owned child is still open.
printf 'busy root\n' >"$r2/tools/busy-root.tmp"
python3 - "$r2/tools/busy-root.tmp" <<'PY' &
import sys, time
with open(sys.argv[1], "r", encoding="utf-8"):
    time.sleep(2)
PY
server_pid=$!
sleep 0.2
"$helper" cleanup-owned "$r2" "$t2"
assert_exists "$r2/tools/busy-root.tmp"
assert_exists "$r2/.root-cleanup-deferred"
wait "$server_pid"
server_pid=""

# SessionEnd removes a direct-session root; launcher roots remain until process exit.
printf '{"session_id":"session-two","hook_event_name":"SessionEnd"}' |
  env -u CLAUDE_CLEANUP_ROOT -u CLAUDE_CLEANUP_TOKEN "$helper" session-end
assert_missing "$fallback_root"

printf '{"session_id":"session-one","hook_event_name":"SessionEnd"}' |
  CLAUDE_CLEANUP_ROOT="$r1" CLAUDE_CLEANUP_TOKEN="$t1" "$helper" session-end
assert_exists "$r1"
assert_missing "$r1/tools/c"

# Launcher process always removes its complete owned root on normal exit.
cat >"$fake_bin/claude" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[ -d "$CLAUDE_CLEANUP_ROOT" ]
printf '%s\t%s\n' "$CLAUDE_CLEANUP_ROOT" "$CLAUDE_CLEANUP_TOKEN" >"$LAUNCH_CAPTURE"
printf 'payload\n' >"$CLAUDE_CLEANUP_ROOT/tools/payload"
SH
chmod +x "$fake_bin/claude"
launch_capture="$state/launch-capture"
LAUNCH_CAPTURE="$launch_capture" "$helper" launch "$fake_bin/claude"
launch_root="$(cut -f1 "$launch_capture")"
assert_missing "$launch_root"

# The MCP proxy suppresses an idle browser_close without starting browser state.
cat >"$fake_bin/npx" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >"$FAKE_NPX_ARGS"
while IFS= read -r line; do
  case "$line" in
    *'"method":"initialize"'*)
      id="$(printf '%s' "$line" | jq -c '.id')"
      printf '{"jsonrpc":"2.0","id":%s,"result":{"protocolVersion":"2025-03-26","capabilities":{},"serverInfo":{"name":"fake","version":"1"}}}\n' "$id"
      ;;
    *'"method":"tools/call"'*)
      id="$(printf '%s' "$line" | jq -c '.id')"
      printf '{"jsonrpc":"2.0","id":%s,"result":{"content":[{"type":"text","text":"closed"}],"isError":false}}\n' "$id"
      ;;
  esac
done
SH
chmod +x "$fake_bin/npx"
p3="$(allocate playwright)"; r3="$(root_from "$p3")"; t3="$(token_from "$p3")"
fake_args="$state/npx-args"
response="$(printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"browser_close","arguments":{}}}' |
  PATH="$fake_bin:$PATH" FAKE_NPX_ARGS="$fake_args" \
  CLAUDE_CLEANUP_ROOT="$r3" CLAUDE_CLEANUP_TOKEN="$t3" \
  CLAUDE_CLEANUP_HELPER="$helper" PLAYWRIGHT_MCP_VERSION=0.0.79 \
  node "$proxy")"
printf '%s' "$response" | grep -Fq '"id":2'
printf '%s' "$response" | grep -Fq 'No open Playwright browser session.'
grep -Fq '@playwright/mcp@0.0.79' "$fake_args"
grep -Fq -- '--isolated' "$fake_args"
grep -Fq -- "--output-dir $r3/playwright-output" "$fake_args"

# Cleanup cost stays roughly constant as output file count grows: one directory
# lsof scan, never one lsof process per file.
perf="$(allocate playwright)"; perf_root="$(root_from "$perf")"; perf_token="$(token_from "$perf")"
i=0
while [ "$i" -lt 100 ]; do
  : >"$perf_root/playwright-output/f$i"
  i=$((i + 1))
done
perf_start="$(python3 -c 'import time; print(time.monotonic())')"
"$helper" cleanup-playwright "$perf_root" "$perf_token"
perf_elapsed="$(python3 -c "import time; print(time.monotonic() - $perf_start)")"
python3 - "$perf_elapsed" <<'PY'
import sys
if float(sys.argv[1]) >= 3.0:
    raise SystemExit(f"cleanup took too long for 100 files: {sys.argv[1]}s")
PY
"$helper" cleanup-owned "$perf_root" "$perf_token"

# Static config checks catch hook or MCP drift.
jq -e '
  .mcpServers.playwright.command == "/bin/bash" and
  (.mcpServers.playwright.args | index("-c") != null) and
  (.mcpServers.playwright.args | any(contains("playwright-mcp.sh")))
' "$repo_root/config/mcp/mcp-shared.json" >/dev/null
jq -e '
  any(.hooks.SessionStart[].hooks[]; .type == "command" and (.command | contains("session-cleanup.sh session-start"))) and
  any(.hooks.Stop[].hooks[]; .type == "mcp_tool" and .server == "playwright" and .tool == "browser_close") and
  any(.hooks.Stop[].hooks[]; .type == "command" and (.command | contains("session-cleanup.sh turn"))) and
  any(.hooks.StopFailure[].hooks[]; .type == "command" and (.command | contains("session-cleanup.sh turn"))) and
  any(.hooks.SessionEnd[].hooks[]; .type == "command" and (.command | contains("session-cleanup.sh session-end")))
' "$repo_root/config/claude/settings.json" >/dev/null
grep -Fq "process.env.PLAYWRIGHT_MCP_VERSION || '0.0.79'" "$proxy"
grep -Fq "'--isolated'" "$proxy"

"$helper" cleanup-owned "$r1" "$t1"
"$helper" cleanup-owned "$r2" "$t2"
"$helper" cleanup-owned "$r3" "$t3" 2>/dev/null || true

echo "claude cleanup isolation and lifecycle ok"
