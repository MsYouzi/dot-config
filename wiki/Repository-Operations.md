# Repository operations

English | [简体中文](Repository-Operations-zh-CN.md)

This page explains where files live and how `install.sh` moves them into your home folder.

## Folder rule

```text
config/   config used now
scripts/  code that runs and external release pins
wiki/     full help
```

These files stay at fixed paths because tools look for them there:

```text
.claude/CLAUDE.md
.github/copilot-instructions.md
.github/workflows/*.yml
.gitignore
install.sh
ReadMe.md
```

## The manifest

`config/manifest.tsv` is the active install list. The installer does not scan the root for random dotfiles.

Each row has three tab-separated fields:

```text
type<TAB>source<TAB>home destination
```

Types:

| Type | Work |
|---|---|
| `link` | Make a symlink in `$HOME` |
| `merge` | Merge safe shared data into a local file |
| `render` | Fill a template and write a local file |

The installer checks that every source exists, every destination is unique, and every source is under `config/` or `scripts/`.

The manifest check excludes SonicTerm `*.save.lock` runtime files. Leave these ignored locks in place; never add them to the manifest or Git.

## Active paths

| Repository source | Home destination or work |
|---|---|
| `config/git/ignore` | `~/.config/git/ignore` |
| `config/rmux/rmux.conf` | `~/.rmux.conf` |
| `config/legacy/tmux/tmux.conf` | `~/.tmux.conf` (fork compatibility) |
| `config/legacy/wezterm/wezterm.lua` | `~/.wezterm.lua` (fork compatibility) |
| `config/sonicterm/**.toml` | matching files under `~/.sonicterm/` |
| `config/zsh/**` | matching files under `~/.oh-my-zsh/custom/` |
| `config/claude/**` | `~/.claude/` |
| `config/copilot/**` | `~/.copilot/` |
| `config/copilot-relay/config.yaml` | `~/.copilot-relay/config.yaml` |
| `config/mcp/mcp-shared.json` | merge into local Copilot MCP data |
| `config/launchd/*.plist` | render into `~/Library/LaunchAgents/` |
| `scripts/copilot/cleanup-legacy.sh` | `~/.copilot/cleanup-legacy.sh` |
| `scripts/rmux/rmux-store` | `~/.local/bin/rmux-store` |
| `scripts/rmux/store.py` | `~/.local/lib/rmux-store/store.py` |
| `scripts/claude/session-cleanup.sh` | `~/.claude/session-cleanup.sh` |
| `scripts/claude/playwright-mcp.sh` | `~/.claude/playwright-mcp.sh` |
| `scripts/claude/playwright-mcp-proxy.js` | `~/.claude/playwright-mcp-proxy.js` |

The manifest rejects archived sources. Wiki pages are never installed.

## External theme assets

Upstream Apollo releases remain checksum-pinned by `scripts/apollo-releases.tsv`. This fork stores Catppuccin palette and adapter inputs under `scripts/theme/`; `scripts/catppuccin-theme.sh` applies them while `install.sh` builds the same verified local set under `~/.local/share/dot-configs/apollo/` and links SonicTerm, RMUX, eza, and Claude to it.

Generated status-line, shell-prompt, and Claude theme files are local runtime state derived from the verified canonical palette. A failed download or checksum does not replace the active set. See [Apollo theme](Apollo-Theme.md).

## Safe links

For each `link` row, `install.sh` does this:

1. Leave the link alone when it already points to the right source.
2. Remove an old link only when it points to the exact old repo path.
3. Move any other file or link to `<name>.bak.YYYYMMDDHHMMSS`.
4. Make the new link.
5. Keep the newest backup for that destination.

A user file is not silently deleted. A foreign symlink is not silently deleted. Both become backups before the managed link is made.

The move from old root paths to `config/` is handled in the same install run.

## Add or change config

Edit the repository source. Do not edit the linked file in `$HOME`.

To add a managed file:

1. Put it under `config/` or `scripts/`.
2. Add one row to `config/manifest.tsv`.
3. Add or update its bilingual Wiki page.
4. Run `scripts/check.sh all`.
5. Run `./install.sh` twice.
6. Check the link or rendered file.

A second install should make no unwanted change.

## Installer switches

Use these only when needed:

```sh
SKIP_BREW=1 ./install.sh
SKIP_NPM_GLOBALS=1 ./install.sh
SKIP_OH_MY_ZSH=1 ./install.sh
DOT_CONFIGS_INSTALL_LOG=/tmp/install.log ./install.sh
```

The normal log is `~/Library/Logs/dot-configs-install.log`.

## Shared and secret MCP data

`config/mcp/mcp-shared.json` may contain only safe, public server data.

The installer merges it into:

```text
~/.config/github-copilot/mcp.json
```

Local Copilot entries are kept. Shared entries win when the same server name exists. The merged Copilot server map then replaces the top-level `mcpServers` field in `~/.claude.json`.

A server added only to `~/.claude.json` will be removed by the next install. Put a server in the local Copilot MCP file when both tools need it.

Tokens and API keys for optional MCP servers belong only in the local Copilot MCP file. Do not add them to this repo.

Copilot includes `github-mcp-server` and uses its existing GitHub login. Claude uses authenticated `gh` for GitHub work. This repo does not provision a separate GitHub MCP entry or PAT; shared MCP sync remains in place for Playwright and other configured servers.

Claude's local-scope entries live under `projects[].mcpServers` in `~/.claude.json`. They replace same-name user entries; headers are not merged. The MCP import leaves these local entries untouched.

## Local state

These paths are local and are not config sources:

- `~/.claude.json` — Claude onboarding, approvals, selected Apollo theme, project state, and MCP state
- `~/.local/share/dot-configs/apollo/` — verified Apollo releases and generated runtime adapters
- `~/.copilot-relay/github_token` — relay auth
- `~/.copilot-relay/copilot_token.json` — relay token cache
- `~/.copilot-relay/logs/` — relay logs
- `~/.sonicterm/logs/` — SonicTerm logs
- SonicTerm save locks and backups
- `~/.tmux/plugins/` and old resurrect files

Local state is not the same as a user global. `~/.claude/CLAUDE.md` and `~/.copilot/copilot-instructions.md` are user globals: links to tracked sources in `config/`, edited here and reinstalled. `~/.claude.json` is local state the tools own. The MCP import replaces only its top-level `mcpServers` field and leaves per-project overrides alone. Other installer steps can update local preferences, such as the selected Apollo theme.

## Retired links

Upstream retired tmux and WezTerm, but this fork keeps their last customized Catppuccin configurations under `config/legacy/` and installs them through the manifest for compatibility. RMUX and SonicTerm remain the primary path. The installer removes only the retired SonicTerm `wezterm.toml` link when it points to this repo's exact old source; user-owned files and links stay.

The duplicate `~/.copilot/AGENTS.md` link is also removed only when it points to this repo's current or former managed source. User files and foreign links stay.

The legacy configs are active compatibility files, not the primary terminal stack. New managed files still follow the current manifest rules.

## Apply and check

```sh
./install.sh
./install.sh
scripts/check.sh all
```

Then check the main links:

```sh
ls -l ~/.rmux.conf ~/.tmux.conf ~/.wezterm.lua ~/.claude/settings.json \
  ~/.copilot/settings.json ~/.copilot-relay/config.yaml ~/.sonicterm/sonicterm.toml
```

More service checks are in [Services and automation](Services-and-Automation.md).
