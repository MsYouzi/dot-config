# Fork-local zsh additions for MsYouzi/dot-config.
#
# This file only exists in the fork. Keeping fork changes in their own file
# lets `uu` merge D0n9X1n/dot-config without touching files upstream edits.

# Repo root: this file is linked from ~/.oh-my-zsh/custom, so resolve the link.
# shellcheck disable=SC2296,SC2298 # zsh-only: %x is this file, :A resolves links.
typeset -g DOT_CONFIG_DIR="${DOT_CONFIG_DIR:-${${(%):-%x}:A:h:h:h}}"
typeset -g DOT_CONFIG_UPSTREAM="${DOT_CONFIG_UPSTREAM:-https://github.com/D0n9X1n/dot-config.git}"

# autojump provides `j`. custom.zsh only checks the Apple Silicon prefix, so
# also try the Intel Homebrew prefix when `j` is still missing.
if ! (( $+functions[j] )); then
  for _dot_autojump_sh in \
    "${HOMEBREW_PREFIX:-/opt/homebrew}/etc/profile.d/autojump.sh" \
    /opt/homebrew/etc/profile.d/autojump.sh \
    /usr/local/etc/profile.d/autojump.sh; do
    if [[ -f "$_dot_autojump_sh" ]]; then
      . "$_dot_autojump_sh"
      break
    fi
  done
  unset _dot_autojump_sh
fi

# uu: go to this repo, merge the latest upstream main, then run install.sh.
# It refuses a dirty tree or a branch other than main, and aborts on conflict.
uu() {
  emulate -L zsh
  local branch

  cd "$DOT_CONFIG_DIR" || return 1

  if [[ -n "$(git status --porcelain)" ]]; then
    print -u2 "uu: $DOT_CONFIG_DIR has uncommitted changes; commit or stash them first."
    return 1
  fi

  branch="$(git symbolic-ref --quiet --short HEAD)"
  if [[ "$branch" != main ]]; then
    print -u2 "uu: switch to main first (current: ${branch:-detached HEAD})."
    return 1
  fi

  print "uu: fetching main from $DOT_CONFIG_UPSTREAM"
  git fetch --quiet "$DOT_CONFIG_UPSTREAM" main || {
    print -u2 "uu: fetch failed."
    return 1
  }

  if ! git merge --no-edit FETCH_HEAD; then
    git rev-parse --quiet --verify MERGE_HEAD >/dev/null && git merge --abort
    print -u2 "uu: merge conflict with upstream; merge aborted and nothing installed."
    return 1
  fi

  ./install.sh
}
