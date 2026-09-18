# Apollo theme

English | [简体中文](Apollo-Theme-zh-CN.md)

The release-managed theme pipeline is shared by the active terminal, multiplexer, shell, CLI status lines, and file listings. This fork applies Catppuccin Mocha through that pipeline.

Upstream pins canonical Apollo releases from the [Apollo Theme organization](https://github.com/apollo-theme). This fork keeps one small tracked Catppuccin Mocha palette plus generated adapter inputs under `scripts/theme/`; generated runtime artifacts remain outside Git.

## Active surfaces

| Surface | Source |
|---|---|
| SonicTerm | Fork Catppuccin adapter applied to the verified bundle |
| RMUX | Fork Catppuccin adapter applied to the verified bundle |
| eza | Fork Catppuccin adapter applied to the verified bundle |
| Claude Code UI | Generated locally from the fork Catppuccin palette |
| Claude and Copilot status lines | One local include generated from the fork Catppuccin palette |
| Oh My Zsh prompt (optional) | Structure in this repo; colors generated locally; selected only through `.zshrc` |
| fast-syntax-highlighting | Its Base16 theme, using the terminal ANSI palette |
| Copilot CLI UI | Built-in `default` theme, using the terminal ANSI palette |

Neovim is managed in a different repository. This installer does not modify Neovim config, plugins, or runtime state.

## Release lock

`scripts/apollo-releases.tsv` still pins each upstream repository, tag, artifact, and SHA-256. `scripts/catppuccin-theme.sh` then replaces the downloaded palette and adapters with the fork-owned files in `scripts/theme/` before validation and generation. The bundle hash includes those fork inputs, so changing any palette file creates a new immutable set.

The installer downloads exact tagged files. It does not follow `main` or query `latest`. An online maintainer check verifies published bytes:

```sh
scripts/check.sh apollo-online
```

Ordinary `scripts/check.sh all` remains offline.

## Local bundle

Verified files live under:

```text
~/.local/share/dot-configs/apollo/
  blobs/
  sets/
  current -> sets/<bundle-hash>
  fsh/
```

The bundle hash covers the release lock and adapter code. The installer verifies every download before creating a complete set, then switches `current` only after all release files and generated adapters validate. A valid bundle works offline. A failed download or checksum leaves the previous bundle active.

Installed consumers link to `current`:

```text
~/.sonicterm/themes/apollo.toml
~/.config/rmux-apollo-theme/apollo-rmux.conf
~/.config/eza-apollo-theme/theme.yml
~/.claude/themes/apollo.json
```

Generated runtime files are local state. Do not commit them.

### Status-line color roles

The shared include generates `C_FG_BRIGHT` from the canonical `foregroundBright` color. Copilot uses it for Model, Effort, Path, and Branch values. Older bundles fall back to the normal foreground; no-color mode remains plain text. Claude keeps its existing colors.

## Updates

To update the fork theme:

1. Edit the Catppuccin inputs in `scripts/theme/`. The JSON drives generated Claude, status-line, and prompt colors; the SonicTerm TOML, RMUX config, and eza YAML are copied independently, so update shared color roles in each affected input.
2. Keep `scripts/catppuccin-theme.sh` as the only integration hook into the upstream bundle builder.
3. Run `scripts/check.sh all`.
4. Run `./install.sh` twice.
5. Reload SonicTerm and RMUX, then start new Claude and Copilot sessions.

When updating upstream Apollo release pins, still run `scripts/check.sh apollo-online`. Do not embed palette values in active consumers under `config/`; they must continue to read the generated bundle.

## Safe cleanup

The old `themes/apollo/` copies are gone. Fork colors now live under `scripts/theme/`, outside the retired path. The installer removes the former SonicTerm `wezterm.toml`, `catppuccin-mocha.toml`, and `~/.tmux.fork.conf` links only when they point exactly to their retired repository sources. User files and foreign links remain untouched.

Manual Vim, Neovim, VS Code, Windows Terminal, or WezTerm theme files are user-owned and are never removed.

See [SonicTerm and shell](SonicTerm-and-Shell.md), [RMUX](RMUX.md), and [Development and releases](Development-and-Releases.md).
