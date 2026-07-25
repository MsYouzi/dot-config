-- Apollo — wezterm color_scheme
-- Catppuccin Mocha base + deeper crust canvas (#11111b).
-- ANSI/brights pinned to WezTerm's builtin "Catppuccin Mocha" so this
-- matches what the terminal renders natively.
-- Drop into wezterm config:
--   local apollo = require("apollo")
--   config.color_schemes = { Apollo = apollo }
--   config.color_scheme  = "Apollo"
return {
  foreground    = "#cdd6f4",
  background    = "#11111b",
  cursor_bg     = "#cdd6f4",
  cursor_fg     = "#11111b",
  cursor_border = "#cdd6f4",
  selection_fg  = "#cdd6f4",
  selection_bg  = "#585b70",
  ansi = {
    "#45475a", "#f38ba8", "#a6e3a1", "#f9e2af",
    "#89b4fa", "#f5c2e7", "#94e2d5", "#bac2de",
  },
  brights = {
    "#585b70", "#f38ba8", "#a6e3a1", "#f9e2af",
    "#89b4fa", "#f5c2e7", "#94e2d5", "#a6adc8",
  },
}
