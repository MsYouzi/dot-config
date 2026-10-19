# MsYouzi/dot-config fork overlay

Upstream ([D0n9X1n/dot-config](https://github.com/D0n9X1n/dot-config)) never tracks `local/`, so these files never conflict with an upstream merge. See the upstream Customization Wiki page.

| File | Purpose |
|---|---|
| `zsh/uu.zsh` | Replaces upstream `uu` (installed as `~/.oh-my-zsh/custom/zzz-local-uu.zsh`) |
| `check.sh` | Fork tests; run by `scripts/check.sh all`, `smoke`, and `local` |

## `uu`

Upstream `uu` only fast-forwards from `origin`. This fork's `main` has its own commits, so it cannot fast-forward to upstream. The override:

1. Refuses a dirty tree or a branch other than `main`.
2. Fast-forwards `main` from the fork (`origin/main`).
3. Merges `main` from `$DOT_CONFIGS_UPSTREAM_URL` (default D0n9X1n/dot-config). On conflict it aborts the merge and installs nothing.
4. Runs `./install.sh` with any arguments.

It never pushes. Run `git push` to save the merge to the fork.

## Fork-only commits outside `local/`

The Catppuccin Mocha theme commit (`ce993c0`) edits upstream theme files, so it can conflict when upstream changes the same lines. `uu` then stops; resolve with `git merge` by hand.

`autojump`/`j` needs nothing here: upstream `custom.zsh` loads it from `/opt/homebrew` or `/usr/local`.
