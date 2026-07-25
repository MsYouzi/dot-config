#!/usr/bin/env bash
# Catppuccin Mocha statusline palette — FORK-OWNED OVERRIDE.
#
# WHY THIS FILE EXISTS — read before "simplifying" it away.
# This repo is a fork of D0n9X1n/dot-config (the `source` remote). Upstream's
# statuslines are Gruvbox Dark Hard; this fork is Catppuccin Mocha. The palette
# used to be edited directly into the C_*/CB_* block inside each statusline, so
# every upstream touch of that block collided head-on and a careless merge
# silently restored Gruvbox.
#
# Instead: upstream's color block is left EXACTLY as upstream wrote it, and each
# statusline sources this file immediately afterwards to reassign the same
# variables. Upstream owns the defaults; the fork owns the override. A pull that
# rewrites upstream's block merges cleanly and this file wins at runtime
# regardless of what the defaults became.
#
# Consequences worth knowing:
#   - Editing the palette means editing THIS file, not the statuslines.
#   - Both statuslines source the same file, so they cannot drift apart — the
#     parity rule in CLAUDE.md is enforced structurally, not by review.
#   - If this file is missing (statusline copied somewhere without the repo),
#     the statusline still runs and renders in upstream's Gruvbox. Degraded,
#     never broken.
#   - Sourced only when colors are ON. Callers check that first, so
#     CLAUDE_STATUSLINE_NO_COLOR / COPILOT_STATUSLINE_NO_COLOR still produce
#     completely uncolored output.
#
# Values are pinned to WezTerm's builtin "Catppuccin Mocha" scheme, matching
# .sonicterm/themes/catppuccin-mocha.toml, wezterm/wezterm.lua, and .tmux.conf.
# 24-bit ANSI so we do not depend on the terminal's 256-color cube.

# --- Foreground accents ---------------------------------------------------
C_RED=$'\033[38;2;243;139;168m'                   # #f38ba8 — mocha red
C_GREEN=$'\033[38;2;166;227;161m'                 # #a6e3a1 — mocha green
C_YELLOW=$'\033[38;2;249;226;175m'                # #f9e2af — mocha yellow
C_BLUE=$'\033[38;2;137;180;250m'                  # #89b4fa — mocha blue
C_PURPLE=$'\033[38;2;203;166;247m'                # #cba6f7 — mocha mauve
C_AQUA=$'\033[38;2;148;226;213m'                  # #94e2d5 — mocha teal
C_ORANGE=$'\033[38;2;250;179;135m'                # #fab387 — mocha peach
C_FG=$'\033[38;2;205;214;244m'                    # #cdd6f4 — mocha text

# Copilot-only: dimmer foreground for secondary text. Guarded so sourcing this
# file from the Claude statusline (which has no such variable) stays harmless.
C_FG_DIM=$'\033[38;2;166;173;200m'                # #a6adc8 — mocha subtext0

# --- Background variants (vim-mode badge) ---------------------------------
# Role assignment follows vim-airline's convention:
#   NORMAL → yellow · INSERT → blue · VISUAL → orange · REPLACE → red
# Catppuccin's accents are pastels, bright enough to carry dark text directly
# (unlike Gruvbox, which needed its dimmer "neutral" variants for backgrounds).
CB_RED=$'\033[48;2;243;139;168m'                  # #f38ba8 — mocha red
CB_BLUE=$'\033[48;2;137;180;250m'                 # #89b4fa — mocha blue
CB_YELLOW=$'\033[48;2;249;226;175m'               # #f9e2af — mocha yellow
CB_ORANGE=$'\033[48;2;250;179;135m'               # #fab387 — mocha peach
CB_GREEN=$'\033[48;2;166;227;161m'                # #a6e3a1 — mocha green (back-compat)
C_BG_FG=$'\033[38;2;30;30;46m'                    # #1e1e2e — mocha base, dark text on bright bg
