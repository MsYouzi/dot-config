#!/usr/bin/env bash
# zsh -c scripts below expand their own arguments.
# shellcheck disable=SC2016
# Fork-only checks for config/zsh/zz-local.zsh. Kept outside scripts/check.sh
# so upstream merges do not conflict.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
helper="$repo_root/config/zsh/zz-local.zsh"

zsh -n "$helper"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

git_q() { git -c user.name=t -c user.email=t@example.com -c init.defaultBranch=main "$@"; }

make_repos() {
  rm -rf "$tmp/up" "$tmp/fork"
  git_q init -q "$tmp/up"
  printf 'shared\n' >"$tmp/up/shared.txt"
  git_q -C "$tmp/up" add . && git_q -C "$tmp/up" commit -qm base
  git_q clone -q "$tmp/up" "$tmp/fork"
  printf '#!/bin/sh\ntouch installed\n' >"$tmp/fork/install.sh"
  chmod +x "$tmp/fork/install.sh"
  printf 'installed\n' >"$tmp/fork/.gitignore"
  printf 'fork\n' >"$tmp/fork/fork.txt"
  git_q -C "$tmp/fork" add . && git_q -C "$tmp/fork" commit -qm fork
}

run_uu() {
  (cd / && HOME="$tmp" GIT_CONFIG_GLOBAL=/dev/null \
    GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com \
    GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com \
    DOT_CONFIG_DIR="$tmp/fork" DOT_CONFIG_UPSTREAM="$tmp/up" \
    zsh -f -c 'source "$1"; (( $+functions[uu] )) && uu' _ "$helper")
}

# Repo root resolves from the linked file, three levels up.
mkdir -p "$tmp/omz"
ln -s "$helper" "$tmp/omz/zz-local.zsh"
root="$(cd / && env -u DOT_CONFIG_DIR zsh -f -c 'source "$1"; print -r -- "$DOT_CONFIG_DIR"' _ "$tmp/omz/zz-local.zsh")"
[ "$root" = "$repo_root" ] || { echo "DOT_CONFIG_DIR resolved to $root, want $repo_root" >&2; exit 1; }

# Clean merge: upstream commit lands, install runs.
make_repos
printf 'new\n' >"$tmp/up/new.txt"
git_q -C "$tmp/up" add . && git_q -C "$tmp/up" commit -qm upstream
run_uu >/dev/null
[ -f "$tmp/fork/new.txt" ] && [ -f "$tmp/fork/fork.txt" ] && [ -f "$tmp/fork/installed" ]
git -C "$tmp/fork" merge-base --is-ancestor "$(git -C "$tmp/up" rev-parse HEAD)" HEAD

# Conflict: merge aborted, nothing installed.
make_repos
printf 'upstream\n' >"$tmp/up/shared.txt"
git_q -C "$tmp/up" commit -qam upstream
printf 'fork edit\n' >"$tmp/fork/shared.txt"
git_q -C "$tmp/fork" commit -qam fork-edit
if run_uu >/dev/null 2>&1; then echo "uu should fail on conflict" >&2; exit 1; fi
if git -C "$tmp/fork" rev-parse --quiet --verify MERGE_HEAD >/dev/null; then
  echo "uu left a merge in progress" >&2; exit 1
fi
[ -z "$(git -C "$tmp/fork" status --porcelain)" ]
[ ! -e "$tmp/fork/installed" ]

# Dirty tree: refused before fetching.
make_repos
printf 'dirty\n' >>"$tmp/fork/fork.txt"
if run_uu >/dev/null 2>&1; then echo "uu should refuse a dirty tree" >&2; exit 1; fi
[ ! -e "$tmp/fork/installed" ]

# Not on main: refused.
make_repos
git -C "$tmp/fork" switch -qc other
if run_uu >/dev/null 2>&1; then echo "uu should refuse a non-main branch" >&2; exit 1; fi
[ ! -e "$tmp/fork/installed" ]

echo "fork-local zsh helpers ok"
