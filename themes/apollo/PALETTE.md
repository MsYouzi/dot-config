# Apollo palette

Catppuccin Mocha base + deeper canvas (`#11111b` / crust, one step below
the scheme's own `#1e1e2e` base). One source of truth for every editor
file in this directory.

| Role             | Hex       | Catppuccin name |
| ---------------- | --------- | --------------- |
| background       | `#11111b` | crust           |
| chrome / bg1     | `#181825` | mantle          |
| foreground       | `#cdd6f4` | text            |
| cursor           | `#cdd6f4` | text            |
| selection bg     | `#585b70` | surface2        |
| fg dim           | `#6c7086` | overlay0        |
| fg               | `#bac2de` | subtext1        |
| fg accent        | `#f9e2af` | yellow          |

ANSI 0–7  : `#45475a` `#f38ba8` `#a6e3a1` `#f9e2af` `#89b4fa` `#f5c2e7` `#94e2d5` `#bac2de`
Bright 8–15: `#585b70` `#f38ba8` `#a6e3a1` `#f9e2af` `#89b4fa` `#f5c2e7` `#94e2d5` `#a6adc8`

Notes:

- ANSI/bright values are pinned to **WezTerm's builtin "Catppuccin Mocha"**
  (read out of the binary, not copied from catppuccin/palette). The two
  sources disagree: WezTerm puts subtext1 in normal-white and subtext0 in
  bright-white, and reuses the same hex for normal+bright on
  red/green/yellow/blue/magenta/cyan. Pinning to the binary keeps Apollo,
  SonicTerm, and WezTerm identical — re-deriving these from the palette
  site will silently break parity.
- Because Mocha has no separate bright ramp, most normal/bright pairs are
  intentionally the same value. Only black, white, and purple differ.
- `chrome / bg1` (mantle) is what popups, floats, cursorline, statusline
  and borders sit on. It must stay *between* crust and base so chrome
  recedes against the canvas rather than reading as a raised panel.
