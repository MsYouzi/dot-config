---
name: sync-upstream
description: Pull the latest source/main into this fork with a merge, preserve the fork's Catppuccin and local settings, run checks, and apply locally. TRIGGER when asked to pull, merge, or sync D0n9X1n upstream. SKIP for a plain push or an unrelated repo.
---

# Sync upstream

This repository has two remotes:

| Remote | Role |
|---|---|
| `origin` (`MsYouzi/dot-config`) | this fork |
| `source` (`D0n9X1n/dot-config`) | upstream, read-only |

Never rebase and never push to `source`.

## 1. Protect local work

Read `wiki/README.md` and `wiki/Repository-Operations.md`. Inspect the branch,
working tree, remotes, and existing stashes. If the tree is dirty, preserve the
index, worktree, and untracked files with a named stash before merging. Do not
drop that recovery stash until all ported work is verified.

## 2. Fetch and inspect

```sh
git fetch source
git log --oneline main..source/main
git rev-list --left-right --count source/main...main
git diff --stat main...source/main
```

If the behind count is zero, report that and stop. Work on `main` and use:

```sh
git merge source/main
```

## 3. Resolve for the current architecture

`config/manifest.tsv` is the active install contract. Upstream owns the current
layout and behavior under `config/`, `scripts/`, and `wiki/`; this fork owns the
policy overrides below.

- Accept upstream moves into `config/` and `scripts/` and its retirement of old
  root paths. Do not restore the removed root quick-reference file, old `claude/`
  sources, or old `themes/apollo/` files. The fork's optional tmux and WezTerm
  compatibility configs belong only under `config/legacy/`.
- Port real local changes to their new canonical paths instead of choosing an
  old side wholesale.
- Preserve `scripts/theme/catppuccin-mocha.*` and
  `scripts/catppuccin-theme.sh`. `install.sh` applies those assets inside the
  release-managed Apollo bundle, so SonicTerm, RMUX, eza, Claude UI, zsh, and
  both status lines remain Catppuccin without embedding colors in active
  consumers.
- Preserve Claude cleanup files under `scripts/claude/`, their manifest rows,
  lifecycle hooks, isolated Playwright MCP entry, wrapper integration, and tests.
- Preserve model policy intentionally: Claude keeps native Sonnet/Haiku client
  ids; relay and Copilot use `gpt-6-astra`; Opus remains `claude-opus-5`; effort
  remains `max`; native concurrent-subagent admission remains `20`.
- Keep English and `-zh-CN` Wiki pages aligned. Keep the root README short.

Unexpected conflicts must be read and merged semantically. Do not use blanket
`ours`/`theirs` for shared config or documentation.

## 4. Verify

```sh
git diff --check
git grep -nE '^(<<<<<<<|=======|>>>>>>>)'
git rev-list --left-right --count source/main...main
scripts/check.sh all
./install.sh
./install.sh
```

Then verify the effective fork invariants:

```sh
jq -e '.env.CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS == "20"' config/claude/settings.json
grep -Eq '^gptModel:[[:space:]]*gpt-6-astra$' config/copilot-relay/config.yaml
grep -Eq '^thinkEffort:[[:space:]]*max$' config/copilot-relay/config.yaml
grep -Fq 'theme = "apollo"' config/sonicterm/sonicterm.toml
grep -Fq 'background = "#11111b"' ~/.sonicterm/themes/apollo.toml
grep -Fq 'status-style "bg=#1e1e2e,fg=#cdd6f4"' ~/.config/rmux-apollo-theme/apollo-rmux.conf
printf '{}' | bash config/claude/statusline.sh | grep -qE '38;2;(205;214;244|249;226;175|137;180;250)'
printf '{}' | bash config/copilot/statusline.sh | grep -qE '38;2;(205;214;244|249;226;175|137;180;250)'
```

Inspect duplicate assignments in shared config when upstream and the fork touched
the same setting. Only after the checks pass may you remove the recovery stash.

Do not push unless the user asked for a push. Report incoming commits, conflicts,
verification, remaining local changes, and restart/reload needs.
