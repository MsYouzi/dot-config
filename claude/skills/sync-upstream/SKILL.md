---
name: sync-upstream
description: Pull the latest changes from the upstream dot-config repo (`source` = D0n9X1n/dot-config) into this fork and merge them locally without losing the fork's own settings — above all the SonicTerm Catppuccin theme. Fetches, shows what is incoming, merges (never rebases), resolves the known-diverged files with a per-file playbook, verifies the fork's invariants still hold, re-links the machine, and pushes to `origin` (MsYouzi/dot-config). TRIGGER when the user asks to pull/sync/merge/update from upstream, from `source`, from D0n9X1n, or asks to "get the latest changes" while keeping their own settings. SKIP for pushing work that is already merged (plain `git push`), for changing a setting (use update-settings), and for any repo that is not this fork.
---

# sync-upstream

This repo is a **fork with two remotes**:

| Remote | URL | Role |
| --- | --- | --- |
| `origin` | `git@github.com:MsYouzi/dot-config.git` | this fork — where work lands |
| `source` | `https://github.com/D0n9X1n/dot-config.git` | upstream — read-only, never push |

Upstream and this fork edit the same dotfiles. Most of the fork's divergence is
**Catppuccin Mocha applied over upstream's Gruvbox**. Pulling upstream is
therefore not a fast-forward — it is a merge with predictable conflicts in a
known set of files, plus one subsystem (`.sonicterm/`) that was deliberately
restructured so it *never* conflicts.

The job of this skill is to bring upstream in without silently reverting the
fork's colors.

---

## Invariants — must hold before you finish

Check every one of these. If any fails, the merge ate a fork setting.

```bash
# 1. Upstream's theme file is untouched by this fork (MUST print nothing)
git diff source/main -- .sonicterm/themes/wezterm.toml

# 2. The fork's palette file still exists
test -f .sonicterm/themes/catppuccin-mocha.toml && echo ok

# 3. SonicTerm still selects the fork's palette
grep '^theme' .sonicterm/sonicterm.toml     # -> theme = "catppuccin-mocha"

# 4. Config still parses
python3 -c "import tomllib;[tomllib.load(open(p,'rb')) for p in ['.sonicterm/sonicterm.toml','.sonicterm/themes/catppuccin-mocha.toml','.sonicterm/themes/wezterm.toml']];print('toml ok')"
```

**Why `.sonicterm/` is safe and the rest is not.** The palette used to live
inside `themes/wezterm.toml`, which is upstream's own file — every upstream
touch collided head-on. It was split out: `wezterm.toml` is kept byte-identical
to `source/main`, the fork's colors live in `themes/catppuccin-mocha.toml`
(a file upstream does not have), and `sonicterm.toml` selects it with one line.
SonicTerm resolves `theme = "<name>"` against `~/.sonicterm/themes/<name>.toml`.

Do **not** "tidy" this by merging the palette back into `wezterm.toml`.

---

## Never rebase

Use `git merge`. Do **not** use `git pull --rebase source main`.

Rebase replays the fork's commits onto upstream, which inverts the meaning of
*ours* and *theirs* in every conflict. The fork's Catppuccin edits are the side
that gets treated as incoming, and the natural "keep ours" reflex then keeps
**upstream's Gruvbox**. Merge keeps the sides oriented the way the conflict
playbook below assumes.

---

## Procedure

### Phase 1 — Fetch and inspect

```bash
git fetch source
git log --oneline main..source/main            # what is incoming
git rev-list --left-right --count source/main...main   # behind<TAB>ahead
git diff --stat main...source/main             # which files upstream touched
```

If the behind-count is `0`, upstream has nothing new. **Say so plainly and
stop** — do not create an empty merge commit to look busy.

Before merging, make sure the tree is clean (`git status --short`) and you are
on `main` (`git switch main`).

### Phase 2 — Merge

```bash
git merge source/main
```

Expect conflicts only in the files listed in the playbook. Anything else
conflicting is a surprise — read it properly rather than picking a side.

### Phase 3 — Conflict playbook

The rule for every fork-diverged file: **take upstream's logic, keep the fork's
colors.** Upstream owns behavior; the fork owns the palette.

| File | What the fork changed | How to resolve |
| --- | --- | --- |
| `.sonicterm/themes/wezterm.toml` | nothing — upstream's | take upstream wholesale (`git checkout --theirs`) |
| `.sonicterm/themes/catppuccin-mocha.toml` | fork-only file | upstream cannot touch it; keep as-is |
| `.sonicterm/sonicterm.toml` | `theme =` line only | keep the fork's `theme = "catppuccin-mocha"`, take upstream's other hunks |
| `.tmux.conf` | Catppuccin status colors | take upstream's bindings/options, re-apply fork colors |
| `wezterm/wezterm.lua` | `color_scheme`, `background`, tab-bar colors | take upstream's logic, re-apply fork colors |
| `claude/statusline.sh` | Catppuccin segment accents | take upstream's segment logic, re-apply fork accents |
| `copilot/statusline.sh` | same | same — and keep it aligned with the Claude one |
| `themes/apollo/*` | whole Catppuccin palette | fork-owned; keep the fork's version |

Two repo rules that bite during this phase:

- **The two statuslines must stay functionally aligned.** Same segments, same
  output shape, same per-cwd git cache. The one intentional difference: Claude's
  has **no** live-subagent rendering (Claude Code ships its own UI); Copilot's
  keeps both the inline count and the agent tree. If upstream changes one
  statusline, port the change to the other rather than letting them drift.
- **`launchd/*.plist` are templates**, not symlinks. If upstream edits one,
  `install.sh` must re-render it (`__HOME__`, `__SRC_DIR__`) — a merge alone
  does not update `~/Library/LaunchAgents/`.

Finish the merge:

```bash
git add -A && git commit --no-edit
```

### Phase 4 — Verify

Run the invariant block at the top of this file, then the repo's own checks:

```bash
scripts/check.sh all
```

`shellcheck not found` locally is fine — CI runs it on Ubuntu.

If upstream touched `.sonicterm/`, confirm the palette survived byte-for-byte:

```bash
git diff HEAD@{1} -- .sonicterm/themes/catppuccin-mocha.toml   # expect empty
```

### Phase 5 — Apply and push

Symlinks point at the repo, so merged content is live immediately for existing
links. Re-run the installer only if upstream **added** a file (new links) or
touched a launchd template:

```bash
./install.sh
```

If a link was shadowed by a stale real file, `install.sh` backs it up as
`<name>.bak.<timestamp>` and replaces it with the symlink — that is expected,
not data loss.

Then:

```bash
git push origin main
```

Never `git push source`.

---

## Reporting back

State plainly:

- how many commits came in, and what they touched;
- which files conflicted and which side won for each;
- that the four invariants pass (or exactly which one did not);
- anything the user must restart to see (SonicTerm reload, tmux reload, terminal
  restart).

If upstream had nothing new, say that in one line. Do not manufacture work.
