#!/usr/bin/env bash
# Fork checks, run by `scripts/check.sh all|smoke|local` from the repo root.
# zsh -c scripts below expand their own arguments.
# shellcheck disable=SC2016
set -euo pipefail

overlay="${DOT_CONFIGS_LOCAL:-$PWD/local}"
helper="$overlay/zsh/uu.zsh"

shellcheck -S warning "$overlay/check.sh"
for file in "$overlay"/zsh/*.zsh; do zsh -n "$file"; done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
g() { git -c init.defaultBranch=main "$@"; }

# up = D0n9X1n, fork.git = MsYouzi on GitHub, work = this machine's checkout.
make_repos() {
  rm -rf "$tmp/up" "$tmp/fork.git" "$tmp/work" "$tmp/other"
  g init -q "$tmp/up"
  printf 'shared\n' >"$tmp/up/shared.txt"
  g -C "$tmp/up" add . && g -C "$tmp/up" commit -qm base
  g clone -q --bare "$tmp/up" "$tmp/fork.git"
  g clone -q "$tmp/fork.git" "$tmp/work"
  printf '#!/bin/sh\ntouch installed\n' >"$tmp/work/install.sh"
  chmod +x "$tmp/work/install.sh"
  printf 'installed\n' >"$tmp/work/.gitignore"
  printf 'fork\n' >"$tmp/work/fork.txt"
  g -C "$tmp/work" add . && g -C "$tmp/work" commit -qm fork && g -C "$tmp/work" push -q
}

run_uu() {
  (cd / && DOT_CONFIGS_DIR="$tmp/work" DOT_CONFIGS_UPSTREAM_URL="$tmp/up" \
    zsh -f -c 'source "$1"; uu' _ "$helper")
}

# Root resolves through the zzz-local link: local/zsh -> repo.
mkdir -p "$tmp/omz"
ln -s "$helper" "$tmp/omz/zzz-local-uu.zsh"
root="$(cd / && zsh -f -c 'source "$1"; print -r -- "$_DOT_CONFIGS_FORK_ROOT"' _ "$tmp/omz/zzz-local-uu.zsh")"
[ "$root" = "$(cd "$overlay/.." && pwd -P)" ] || { echo "uu root resolved to $root" >&2; exit 1; }

# Diverged fork: pulls the fork, merges upstream, installs.
make_repos
g clone -q "$tmp/fork.git" "$tmp/other"
printf 'other\n' >"$tmp/other/other.txt"
g -C "$tmp/other" add . && g -C "$tmp/other" commit -qm other && g -C "$tmp/other" push -q
printf 'new\n' >"$tmp/up/new.txt"
g -C "$tmp/up" add . && g -C "$tmp/up" commit -qm upstream
run_uu >/dev/null
for f in new.txt other.txt fork.txt installed; do [ -f "$tmp/work/$f" ] || { echo "missing $f after uu" >&2; exit 1; }; done
git -C "$tmp/work" merge-base --is-ancestor "$(git -C "$tmp/up" rev-parse HEAD)" HEAD

# Already current: still installs.
rm "$tmp/work/installed"
run_uu >/dev/null
[ -f "$tmp/work/installed" ]

# Conflict: merge aborted, tree clean, nothing installed.
make_repos
printf 'upstream\n' >"$tmp/up/shared.txt"
g -C "$tmp/up" commit -qam upstream
printf 'fork edit\n' >"$tmp/work/shared.txt"
g -C "$tmp/work" commit -qam fork-edit
if run_uu >/dev/null 2>&1; then echo "uu should fail on conflict" >&2; exit 1; fi
if git -C "$tmp/work" rev-parse --quiet --verify MERGE_HEAD >/dev/null; then echo "merge left in progress" >&2; exit 1; fi
[ -z "$(git -C "$tmp/work" status --porcelain)" ] && [ ! -e "$tmp/work/installed" ]

# Dirty tree and non-main branch: refused, nothing installed.
make_repos
printf 'dirty\n' >>"$tmp/work/fork.txt"
if run_uu >/dev/null 2>&1; then echo "uu should refuse a dirty tree" >&2; exit 1; fi
git -C "$tmp/work" checkout -q -- fork.txt
git -C "$tmp/work" switch -qc other
if run_uu >/dev/null 2>&1; then echo "uu should refuse a non-main branch" >&2; exit 1; fi
[ ! -e "$tmp/work/installed" ]

echo "fork uu override ok"
