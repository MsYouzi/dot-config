# Fork customization

English | [简体中文](Fork-Customization-zh-CN.md)

This fork (`MsYouzi/dot-config`) tracks [D0n9X1n/dot-config](https://github.com/D0n9X1n/dot-config). Fork-only changes live in their own files so upstream merges do not conflict.

## Fork-only files

| File | Purpose |
|---|---|
| `config/zsh/zz-local.zsh` | autojump fallback for the Intel Homebrew prefix, and the `uu` command |
| `scripts/local-check.sh` | Tests for the fork-only shell helpers |
| `wiki/Fork-Customization.md` and its Chinese pair | This page |

Shared files only get one-line additions: a manifest row and two sidebar entries.

## `j`

The installer installs `autojump` with Homebrew. `custom.zsh` loads its hook from `/opt/homebrew`. `zz-local.zsh` also tries `$HOMEBREW_PREFIX` and `/usr/local` when `j` is still missing, so `j NAME` works on Intel Macs too.

## `uu`

`uu` updates this machine to the latest upstream commit and applies it:

1. `cd` to the repo (`$DOT_CONFIG_DIR`, resolved from the linked file).
2. Stop when the working tree is dirty or the branch is not `main`.
3. Fetch `main` from `$DOT_CONFIG_UPSTREAM` (default `https://github.com/D0n9X1n/dot-config.git`).
4. Merge it with `git merge --no-edit`. On conflict, run `git merge --abort` and stop without installing.
5. Run `./install.sh`.

`uu` does not push. Push `main` to the fork yourself when you want it saved there.

## Check

```sh
scripts/local-check.sh
```

It checks zsh syntax, then runs `uu` against temporary repos for a clean merge, a conflict, and a dirty tree. Run it with `scripts/check.sh all`.
