# Apollo 主题

[English](Apollo-Theme.md) | 简体中文

release 管理的主题管线由当前终端、multiplexer、shell、CLI 状态栏和文件列表共享。本 fork 通过该管线应用 Catppuccin Mocha。

上游从 [Apollo Theme organization](https://github.com/apollo-theme) 固定规范 Apollo releases。本 fork 在 `scripts/theme/` 保存一份精简的 Catppuccin Mocha palette 和 adapter 输入；生成的运行时文件仍不进入 Git。

## 生效范围

| 范围 | 来源 |
|---|---|
| SonicTerm | 应用于已验证 bundle 的 fork Catppuccin adapter |
| RMUX | 应用于已验证 bundle 的 fork Catppuccin adapter |
| eza | 应用于已验证 bundle 的 fork Catppuccin adapter |
| Claude Code UI | 从 fork Catppuccin palette 在本机生成 |
| Claude 与 Copilot 状态栏 | 从 fork Catppuccin palette 生成一个本机共享 include |
| Oh My Zsh prompt（可选） | 结构在本仓库；颜色在本机生成；仅通过 `.zshrc` 选择 |
| fast-syntax-highlighting | 使用它的 Base16 主题和终端 ANSI palette |
| Copilot CLI UI | 使用内置 `default` 主题和终端 ANSI palette |

Neovim 在另一个仓库中管理。本安装器不会修改 Neovim 配置、plugins 或运行状态。

## Release lock

`scripts/apollo-releases.tsv` 仍固定每个上游仓库、tag、artifact 和 SHA-256。随后 `scripts/catppuccin-theme.sh` 会在验证和生成之前，用 `scripts/theme/` 中 fork 自有的 palette 与 adapters 替换下载内容。Bundle hash 包含这些 fork 输入，因此任何 palette 文件变化都会创建新的不可变 set。

安装器下载精确 tag 文件。它不跟踪 `main`，也不查询 `latest`。维护者可以在线检查发布文件：

```sh
scripts/check.sh apollo-online
```

普通 `scripts/check.sh all` 仍然离线运行。

## 本机 bundle

已验证文件位于：

```text
~/.local/share/dot-configs/apollo/
  blobs/
  sets/
  current -> sets/<bundle-hash>
  fsh/
```

Bundle hash 包含 release lock 和 adapter code。安装器会先验证每个下载，再创建完整 set；所有 release 文件和生成 adapters 都通过检查后，才切换 `current`。有效 bundle 可以离线使用。下载失败或 checksum 不匹配时，旧 bundle 保持生效。

使用者链接到 `current`：

```text
~/.sonicterm/themes/apollo.toml
~/.config/rmux-apollo-theme/apollo-rmux.conf
~/.config/eza-apollo-theme/theme.yml
~/.claude/themes/apollo.json
```

生成的运行文件是本机状态。不要提交它们。

### 状态栏颜色角色

共享 include 从规范 `foregroundBright` 颜色生成 `C_FG_BRIGHT`。Copilot 用它显示 Model、Effort、Path 和 Branch 的值。旧 bundle 回退到普通前景色；无色模式仍输出纯文本。Claude 保持原有颜色。

## 更新

更新 fork 主题：

1. 编辑 `scripts/theme/` 中的 Catppuccin 输入。JSON 用于生成 Claude、状态栏和 prompt 颜色；SonicTerm TOML、RMUX 配置和 eza YAML 则独立复制，因此共享颜色角色变化时需要更新每个受影响的输入。
2. 保持 `scripts/catppuccin-theme.sh` 为接入上游 bundle builder 的唯一 hook。
3. 运行 `scripts/check.sh all`。
4. 运行两次 `./install.sh`。
5. 重载 SonicTerm 和 RMUX，然后启动新的 Claude 与 Copilot session。

更新上游 Apollo release pins 时，仍要运行 `scripts/check.sh apollo-online`。不要把 palette 值嵌入 `config/` 下的 active consumers；它们必须继续读取生成的 bundle。

## 安全清理

旧 `themes/apollo/` 副本已经删除。Fork 颜色现在位于 `scripts/theme/`，不再占用已停用路径。安装器只会在旧 SonicTerm `wezterm.toml`、`catppuccin-mocha.toml` 和 `~/.tmux.fork.conf` 链接精确指向已停用的仓库源路径时移除它们。用户文件和其他来源的链接不会被修改。

手动创建的 Vim、Neovim、VS Code、Windows Terminal 或 WezTerm 主题文件都属于用户，安装器永远不会删除。

请看 [SonicTerm 与 Shell](SonicTerm-and-Shell-zh-CN.md)、[RMUX](RMUX-zh-CN.md)和[开发与发布](Development-and-Releases-zh-CN.md)。
