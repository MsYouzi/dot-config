# uu override for the MsYouzi/dot-config fork.
#
# Upstream uu only fast-forwards to origin. This fork's main has its own
# commits, so it cannot fast-forward to D0n9X1n/dot-config. This uu:
#   1. refuses a dirty tree or a branch other than main;
#   2. fast-forwards main from origin (the fork) when it has an upstream;
#   3. merges main from D0n9X1n/dot-config (aborts on conflict);
#   4. runs ./install.sh with any arguments.
# It never pushes; run `git push` to save the merge to the fork.
#
# Linked as ~/.oh-my-zsh/custom/zzz-local-uu.zsh, so it loads after
# upstream's uu.zsh and replaces it.

# While a file is sourced, zsh sets $0 to its path; :A resolves the link.
typeset -g _DOT_CONFIGS_FORK_ROOT="${0:A:h:h:h}"
typeset -g DOT_CONFIGS_UPSTREAM_URL="${DOT_CONFIGS_UPSTREAM_URL:-https://github.com/D0n9X1n/dot-config.git}"

unalias uu 2>/dev/null
unfunction uu 2>/dev/null
function uu {
  emulate -L zsh
  local repo="${DOT_CONFIGS_DIR:-$_DOT_CONFIGS_FORK_ROOT}" branch before

  if [[ ! -x "$repo/install.sh" ]] || ! command git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
    print -u2 "uu: no dot-configs checkout at $repo (set DOT_CONFIGS_DIR)"
    return 1
  fi
  cd "$repo" || return 1

  if [[ -n "$(command git status --porcelain)" ]]; then
    print -u2 "uu: $repo has uncommitted changes; commit or stash them first"
    return 1
  fi
  branch="$(command git symbolic-ref --quiet --short HEAD)"
  if [[ "$branch" != main ]]; then
    print -u2 "uu: switch to main first (current: ${branch:-detached HEAD})"
    return 1
  fi

  before="$(command git rev-parse --short HEAD)"
  if command git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' >/dev/null 2>&1; then
    print "uu: fast-forwarding main from the fork"
    command git pull --ff-only --quiet || {
      print -u2 "uu: main cannot fast-forward to its fork branch; resolve it in $repo"
      return 1
    }
  fi

  print "uu: merging main from $DOT_CONFIGS_UPSTREAM_URL"
  command git fetch --quiet "$DOT_CONFIGS_UPSTREAM_URL" main || {
    print -u2 "uu: fetch from $DOT_CONFIGS_UPSTREAM_URL failed"
    return 1
  }
  if ! command git merge --no-edit --quiet FETCH_HEAD; then
    command git rev-parse --quiet --verify MERGE_HEAD >/dev/null && command git merge --abort
    print -u2 "uu: upstream merge conflicts; merge aborted and nothing installed"
    return 1
  fi
  if [[ "$before" != "$(command git rev-parse --short HEAD)" ]]; then
    command git --no-pager log --oneline "$before..HEAD" | sed 's/^/  /'
    print "uu: run 'git push' to save this to the fork"
  else
    print "uu: already up to date"
  fi

  ./install.sh "$@" || {
    print -u2 'uu: install.sh failed; see ~/Library/Logs/dot-configs-install.log'
    return 1
  }
  print 'uu: done. Open a new terminal tab to load updated shell files.'
}
