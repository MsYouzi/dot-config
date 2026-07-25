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

# 5. Statuslines still render the fork's Catppuccin palette, not upstream's
#    Gruvbox. Checks what is ACTUALLY EMITTED, so it stays valid however
#    upstream rewrote its own defaults.
for f in claude copilot; do
  printf '%s: ' "$f"
  printf '{}' | bash "$f/statusline.sh" | grep -qE '38;2;(205;214;244|249;226;175|137;180;250)' \
    && echo "mocha ok" || echo "FAIL — check themes/apollo/statusline-palette.sh is sourced"
done

# 6. tmux applies the fork's palette. Uses a throwaway socket (-L) so it does
#    not disturb a running session.
tmux -L syncheck -f .tmux.conf new-session -d -s c 2>/dev/null
[ "$(tmux -L syncheck show -gv status-style)" = "bg=#1e1e2e,fg=#cdd6f4" ] \
  && echo "tmux: mocha ok" || echo "tmux: FAIL — check .tmux.fork.conf is sourced last"
tmux -L syncheck kill-server 2>/dev/null

# 7. WezTerm resolves the fork palette. Loading the config is the only honest
#    check — the override runs at config-eval time.
wezterm --config-file wezterm/wezterm.lua show-keys >/dev/null 2>&1 \
  && echo "wezterm: config loads" || echo "wezterm: FAIL — config error"
grep -q 'FORK.color_scheme' wezterm/wezterm.lua \
  && echo "wezterm: override hook present" || echo "wezterm: FAIL — hook lost in merge"
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
| `claude/statusline.sh` | nothing in the color block — upstream's | take upstream wholesale; keep the fork's palette-override hook after the `fi` |
| `copilot/statusline.sh` | same | same |
| `.tmux.conf` | nothing in the theme block — upstream's | take upstream wholesale; keep the `source-file -q ~/.tmux.fork.conf` block at the end |
| `wezterm/wezterm.lua` | nothing in the theme block — upstream's | take upstream wholesale; keep the two `FORK` override blocks |
| `themes/apollo/statusline-palette.sh` | fork-only file | upstream cannot touch it; keep as-is |
| `.tmux.fork.conf` | fork-only file | upstream cannot touch it; keep as-is |
| `wezterm/palette-fork.lua` | fork-only file | upstream cannot touch it; keep as-is |
| `themes/apollo/*` (rest) | whole Catppuccin palette | fork-owned; keep the fork's version |
| `ReadMe.md`, `QUICKREF.md`, `CLAUDE.md`, `copilot-instructions.md` | heavy prose rewrites | **expect conflicts on most pulls.** No structural fix exists for prose. Keep the fork's sections describing fork-only machinery (palette files, sync-upstream, the two-remote setup); take upstream's new content everywhere else. |

**None of the color files need hand-repair any more.** Every theme this fork
overrides now keeps upstream's block byte-identical and re-applies the fork's
palette from a fork-only file afterwards:

| Consumer | Upstream's block | Fork's override |
| --- | --- | --- |
| statuslines | inline `C_*`/`CB_*` | `themes/apollo/statusline-palette.sh` (sourced) |
| tmux | its theme block | `.tmux.fork.conf` (`source-file -q`, last wins) |
| WezTerm | its theme block + locals | `wezterm/palette-fork.lua` (`dofile`, reassigns) |
| SonicTerm | `themes/wezterm.toml` | `themes/catppuccin-mocha.toml` (selected by name) |

So for any conflict *inside* one of those upstream blocks: take upstream's
version. The override wins at runtime regardless. Only hand-resolve the docs.

Two repo rules that bite during this phase:

- **The two statuslines must stay functionally aligned.** Same segments, same
  output shape, same per-cwd git cache. Colors are now aligned structurally
  (one shared palette file), so what needs watching is *logic*. The one
  intentional difference: Claude's has **no** live-subagent rendering (Claude
  Code ships its own UI); Copilot's keeps both the inline count and the agent
  tree. If upstream changes one statusline's logic, port it to the other.
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

**Check for silently duplicated settings.** A clean auto-merge is not proof of a
clean result. When upstream adds a setting this fork already had, git often
keeps *both* — the hunks do not overlap, so there is no conflict to report. In
`.tmux.conf` and the statuslines the last assignment wins, so nothing visibly
breaks, and the duplicate survives unnoticed:

```bash
# flag options set more than once
grep -oE '^set(-option)? -g [a-z-]+' .tmux.conf | sort | uniq -d
```

Investigate each hit: keep the fork's line if the values differ, otherwise drop
the redundant one.

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
