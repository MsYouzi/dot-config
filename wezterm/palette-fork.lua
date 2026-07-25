-- Catppuccin Mocha WezTerm palette — FORK-OWNED OVERRIDE.
--
-- WHY THIS FILE EXISTS — read before folding it back into wezterm.lua.
-- This repo is a fork of D0n9X1n/dot-config (the `source` remote). Upstream's
-- WezTerm theme is Gruvbox Dark Hard; this fork is Catppuccin Mocha. The
-- palette used to be edited directly into upstream's Theme section and its
-- DARK_BG/FG_* locals, so every upstream touch of those lines collided, and
-- resolving a conflict the natural way ("keep ours") is exactly what restores
-- Gruvbox.
--
-- Instead: upstream's theme block and locals are left EXACTLY as upstream wrote
-- them, and wezterm.lua requires this module immediately afterwards to reassign
-- them. Upstream owns the defaults; the fork owns the override. A pull that
-- retunes Gruvbox merges cleanly and this file still wins.
--
-- Consequences worth knowing:
--   - Edit WezTerm colors HERE, not in wezterm.lua.
--   - Loaded with pcall, so a missing/broken module leaves upstream's Gruvbox
--     in place rather than failing the whole config. Degraded, never broken —
--     a config error in WezTerm means no terminal, so this matters.
--   - Only overrides keys upstream already defines. It cannot mask an upstream
--     feature, only recolor it.
--
-- Palette matches .tmux.fork.conf, themes/apollo/statusline-palette.sh, and
-- .sonicterm/themes/catppuccin-mocha.toml. Values are WezTerm's builtin
-- "Catppuccin Mocha" scheme.

return {
  -- Built-in scheme name. WezTerm ships "Catppuccin Mocha", so unlike the
  -- Gruvbox setup this fork replaces there is no custom color_schemes table to
  -- maintain — the ANSI palette comes straight from the binary, which is what
  -- keeps SonicTerm and WezTerm pixel-identical.
  color_scheme = "Catppuccin Mocha",

  -- Canvas uses Catppuccin's `crust` (#11111b) — one step deeper than the
  -- scheme's `base` (#1e1e2e), the same treatment the Gruvbox setup used when
  -- it dropped from #1d2021 to #141617.
  DARK_BG = "#11111b",

  -- Tab-bar / titlebar foregrounds.
  FG_DIM    = "#6c7086", -- catppuccin overlay0 (inactive — quieter)
  FG        = "#bac2de", -- catppuccin subtext1 (hover — slightly brighter)
  FG_ACCENT = "#f9e2af", -- catppuccin yellow (active title)
}
