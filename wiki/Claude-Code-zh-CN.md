# Claude Code

[English](Claude-Code.md) | 简体中文

在本设置中，Claude Code 使用本机 copilot-relay 服务。

```mermaid
flowchart LR
    C[Claude Code] --> R[127.0.0.1:4142]
    R --> G[GitHub Copilot]
```

源文件在 `config/claude/`。它们安装到 `~/.claude/`。

## 一次设置

```sh
./install.sh
npx copilot-relay auth
./install.sh
```

Claude Code 第一次启动时会问是否允许自定义 `dummy` API key。请选择允许。这个值只是 Claude Code 需要的占位符。真实 GitHub 登录由 copilot-relay 保存。

## 模型路由

受管默认值：

```text
Claude 端名称： claude-sonnet-5[1m]
Picker 名称：    原生 Sonnet 名称
Sonnet 保存偏好：max
启动器 effort：  max
Relay 路由：     gptModel
上游模型：       gpt-6-astra
```

Claude Code 保留原生客户端身份。名称不含 `opus`，因此 copilot-relay 会将其发送到 `gptModel`。

其他路由：

| Claude 端名称 | Relay lane | 上游 |
|---|---|---|
| `claude-opus-5[1m]` | `opusModel` | `claude-opus-5` |
| `claude-haiku-4-5-20251001`（Haiku / small-fast） | `gptModel` | `gpt-6-astra` |

客户端名称和上游模型是不同层。客户端保留原生 Anthropic ID，由 relay 选择上游模型。不要在 Claude 端设置中写入 GPT ID 或 `_NAME` / `_DESCRIPTION` 显示覆盖。

`[1m]` 后缀让 Claude Code 使用一百万 token 的模型 context 计数；relay 向上游发送规范 ID `gpt-6-astra`。Haiku ID 是已安装 CLI 自身的 small-fast ID，不加 `[1m]` 后缀。这不保证保留完整的 1M-token 对话历史；自动压缩取决于模型和输出预算。Relay 端默认 thinking 在 `config/copilot-relay/config.yaml` 中设为 `max`；Sonnet 保存的偏好和 shell 启动器也使用 `max`。

使用支持 GPT-6 Astra 的 relay 版本（见 [copilot-relay issue #57](https://github.com/D0n9X1n/copilot-relay/issues/57)）。修改模型和 effort 默认值时应同时更新 `config/claude/settings.json`、`config/zsh/claude.zsh` 和 `config/zsh/cc.zsh`；wrapper 的 `--model` 和 `--effort` flags 优先于保存的设置。Relay 的 `gptModel` 不带后缀，空白 `webSearchBackend` 也使用 Astra。保持 Opus 路由独立。

切换模型前，运行 `copilot` 并输入 `/model`，检查账号可用性和 effort 选项。这是 Copilot 的选择器，不是 Claude Code 的选择器，也不是 relay 本地的 `/v1/models`。`scripts/check.sh all` 通过后，运行两次 `./install.sh` 应用配置，再启动新的 shell 和 Claude Code 会话。安装器会保留健康的 relay 进程；恢复不健康的 relay 时可能中断请求。

Sonnet 槽位通过 `gptModel` 路由到 GPT-6 Astra；Opus 保留独立的 `opusModel` 路由。任务只涉及一个模型系列时，不要同时修改另一个。Relay 路由和 effort 修改会热重载，无需重启。

## 主要设置

`config/claude/settings.json` 设置：

| Key | 值或作用 |
|---|---|
| `ANTHROPIC_BASE_URL` | `http://127.0.0.1:4142` |
| `ANTHROPIC_AUTH_TOKEN` | 本机占位符 `dummy` |
| `ANTHROPIC_MODEL` | `claude-sonnet-5[1m]` |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | `claude-sonnet-5[1m]` |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | `claude-haiku-4-5-20251001` |
| `ANTHROPIC_SMALL_FAST_MODEL` | `claude-haiku-4-5-20251001` |
| `model` | `sonnet`；选择器自身的短别名 |
| `modelSettings.claude-sonnet-5.effortLevel` | `max`；Sonnet 保存的 effort 偏好 |
| `MODEL_REASONING_EFFORT` | `max`；状态栏回退值与启动器的 `--effort max` 保持一致 |
| `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` | `20` |
| `statusLine.refreshInterval` | `100` |
| `theme` | `custom:apollo`；生成的主题资源仍保留在本机 |
| `CLAUDE_CODE_TMUX_TRUECOLOR` | `"1"`；跳过 Claude 的 tmux 256 色限制 |
| `autoCompactEnabled` | `true` |
| `autoCompactWindow` | `770000`；保留的配置窗口，不是实测触发阈值 |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | `"100"`；保留的百分比覆盖值 |
| `feedbackDrafts` | `off` |

`refreshInterval` 必须放在 `statusLine` 里面。Sonnet 的 `modelSettings` 偏好、`MODEL_REASONING_EFFORT` 和两个启动器应统一为 `max`。`MODEL_REASONING_EFFORT` 是状态栏回退值，不控制 API effort。除非显式提供其他 effort flag，否则启动器的 `--effort` 会覆盖保存的偏好。不管理顶层 `effortLevel`。`max` 是 Claude Code 和 [Copilot CLI](Copilot-CLI-zh-CN.md) 共同的默认推理强度，不是模型名称。

Fork 保留原生 `/model` 选择器，不添加自定义 GPT 行或显示覆盖。不管理 `modelPicker` 或 `availableModels` 覆盖。

### 自动压缩

配置窗口不等于压缩触发阈值。`autoCompactWindow: 770000` 和 `100` 百分比覆盖值保持不变。按 Claude Code 2.1.261 原生 Sonnet 的输出预留量，计算为 `(770000 - 20000) × 100% = 750000`。这不是新的运行时实测，也不代表其他模型的阈值。

CLI 版本、模型、输出预算和环境覆盖都可能改变压缩时机；某一轮可能先越过触发点再开始压缩。不要把这些设置当作对话大小硬上限或历史保留保证。编辑源设置后请启动新的 Claude Code 会话。

`~/.claude/settings.json` 和 `~/.claude.json` 是不同文件：

- `settings.json` 是链接的配置，包括 `custom:apollo` 主题偏好。
- `~/.claude.json` 是本机状态。它保存 onboarding、API key 允许项、安装器同步选择的 Apollo 主题、项目数据和导入的 MCP servers。

`install.sh` 会从已验证的规范 Apollo release 生成 `~/.claude/themes/apollo.json`，并在选择 `custom:apollo` 时保留所有无关字段。生成主题是本机状态，不是 Git 源文件。

不要把本机状态文件放进 Git。

## 确定性清理

`claude` 和 `cc` wrappers 通过 `~/.claude/session-cleanup.sh` 启动真实 CLI。每次调用都会在 `/tmp/claude-code-<uid>-cleanup/roots/` 下得到独立的 mode-0700 root。生命周期 hooks 只清理经过验证的 root：`SessionStart` 把其中的 `tools/` 目录设为 `TMPDIR`，`Stop` 关闭 Playwright 并清理本轮文件，`StopFailure` 尽力执行本轮清理，`SessionEnd` 与 launcher trap 执行最终清理。

Playwright MCP 通过 `~/.claude/playwright-mcp.sh` 运行，固定为 `0.0.79` 并启用 `--isolated`。JSON-RPC proxy 避免空闲的 `browser_close` hook 启动 Chromium，并把生成输出限制在受管 root 中。`~/Library/Caches/ms-playwright` 下的浏览器二进制会保留。所有删除都先验证 ownership token、UID、mode 和 symlink，避免删除其他 session 或任意路径。只读清单：

```sh
~/.claude/session-cleanup.sh inventory
```

清理脚本保存在 `scripts/claude/`，并通过 `config/manifest.tsv` 安装。浏览器操作的 generation 计数避免较早的关闭响应覆盖较新的导航状态，确保最终关闭请求仍会发送给 Playwright。

## 全局指令

`config/claude/CLAUDE.md` 安装为 `~/.claude/CLAUDE.md`，并设置用户级回复风格。对话文字默认直接、简短。明确要求更多细节时仍按要求回答；代码、命令、检查结果、证据、必要说明、安全信息和技术准确性必须保持完整。

全局文件只保留可复用行为，加一条条件指针：这些设置从 `~/Public/dot-configs` 同步；要修改它们，先读该目录的 `.claude/CLAUDE.md`。仓库专属规则——Wiki 是完整信息源、manifest、检查、双语页面——留在本仓库自己的 `.claude/CLAUDE.md`，这样无关项目不会加载它们。

PR 合并后，全局规则要求先完成本机清理，再宣布任务完成：确认合并，移除该 PR 干净且闲置的 worktree 和本地分支，清理失效引用，移除任务创建的临时文件，并停止不再需要的任务专属进程。保留未提交或未合并的工作、stash、活跃会话和锁、无关文件及共享进程。检查最终状态，并说明保留项。这是 agent 指令，不是无人值守的合并 hook。

## 启动器

`config/zsh/claude.zsh` 包装 `claude` 并添加：

```text
--permission-mode bypassPermissions
--model claude-sonnet-5[1m]
--effort max
```

命令行上显式给出 `--model`、`--model=`、`--effort` 或 `--effort=` 时，对应的默认值不再注入；另一个默认值仍然生效。

安装后打开新 shell，或在空闲 shell 提示符中重新加载两个启动器，再启动新的 Claude 会话：

```zsh
source ~/.oh-my-zsh/custom/claude.zsh
source ~/.oh-my-zsh/custom/cc.zsh
```

二进制会拒绝 settings 中的 `permissions.defaultMode: bypassPermissions`。命令行 flag 可以工作。Claude Code 可能在运行时重写 settings，所以 wrapper 也固定模型和 effort。

`settings.json` 是符号链接，因此 CLI 持久化的偏好可能表现为源文件改动。提交前检查 `git diff -- config/claude/settings.json`，只按上面的受支持设置核对变动的键，再运行 `scripts/check.sh all`。不要整份恢复文件，以免丢失其他有意保留的修改。

`cc [标题]` 会设置 SonicTerm 标题，并用相同默认值启动 Claude Code。它先检查 RMUX 并直接重命名其窗口。在原生 tmux 中，通过 `tmux-store` 重命名当前 socket 的当前窗口，不添加 `PATH` shim，也不替换真正的全局 `tmux` 可执行文件。请看 [Tmux](Tmux-zh-CN.md)。

只有当 Claude Code 需要创建 agent-team 窗格时才使用 `rmux claude`。RMUX 会给这个进程一个私有 tmux 兼容 shim。不会安装全局 tmux shim。

## Agent 限制

需要 Claude Code v2.1.217 或更高版本。

原生 admission 值是 20。它不是全局硬上限：

- 用户启动的 `/subtask` 会占一个 slot，但不被同一个边界拦截；
- 恢复的 agent 可以超过设置数量；
- ultracode 不受此限制；
- workflow agents 和 team workers 使用其他限制。

不要恢复旧生命周期计数 hook。

## 状态栏

Claude 与 Copilot 状态栏共享五行布局、本机生成的 Apollo 颜色和每目录五秒 Git cache：

1. 时间、运行时间、费用、WakaTime
2. 模型、effort、context
3. MCP、skills、agents、style
4. 当前路径
5. repo、branch、diff、stash、worktree

两个脚本读取同一个本机生成 Apollo 颜色 include。文件缺失或禁用颜色时，它们仍会输出可读的无色内容。Claude 自定义状态栏没有 live-subagent 数量或树，因为 Claude Code 已有原生 subagent UI。Copilot 保留自定义 rows。

## Plugins

受管设置启用：

- `frontend-design@claude-plugins-official`
- `rust-analyzer-lsp@claude-plugins-official`
- `clangd-lsp@claude-plugins-official`
- `swift-lsp@claude-plugins-official`
- `claude-code-wakatime@wakatime`

WakaTime marketplace 指向官方 `wakatime/claude-code-wakatime` Git 仓库。

## 常见问题

### RMUX 内的颜色不同

Claude Code 2.1.278 在存在 `TMUX` 时会把输出限制为 256 色，即使已设置 `COLORTERM=truecolor` 和 `FORCE_COLOR=3`。RMUX 为兼容性导出 `TMUX`，但支持真彩色。受管的 `env.CLAUDE_CODE_TMUX_TRUECOLOR: "1"` 跳过这个客户端限制，不改动 Apollo 配色。原生 SonicTerm 没有 `TMUX` 时，也没有这个限制需要绕过。

应用设置后请启动新的 Claude Code 进程；已有进程已完成颜色初始化。可以用 `claude --continue` 恢复对话。不要重启 RMUX 服务器：它已经支持真彩色，重启会停止窗格内的应用。重载或重新连接 RMUX 不会重新初始化运行中 Claude 进程的颜色。保留 `TERM=tmux-256color`、`TERM_PROGRAM=rmux` 和 `rmux claude` 私有 teammate shim，不需要修改它们。

### Claude 每次都显示 onboarding

本机 `~/.claude.json` 缺少 `hasCompletedOnboarding`。在这台 Mac 上完成一次 onboarding。

### `dummy` key 被拒绝

第一次提示选择了拒绝。在本机 `~/.claude.json` 中，把 `dummy` 从 `customApiKeyResponses.rejected` 移到 `approved`，或重新完成允许流程。

### 小任务出现 `model_not_supported`

保持 Haiku 和 small-fast aliases 都是 `claude-haiku-4-5-20251001`，即已安装 CLI 自身的 small-fast ID，不要添加 `[1m]` 后缀。检查 `gptModel` 仍是 `gpt-6-astra`，并确认 relay base URL 正确。

### Relay 重写 settings

`config/copilot-relay/config.yaml` 中的 `claudeSetup` 必须是 `false`。重新运行 `./install.sh`。

### Relay token 过期

```sh
npx copilot-relay auth
./install.sh
```

Deep relay 检查退出码为 2 时，一般需要重新登录，不是重启。

## 检查

```sh
launchctl print "gui/$(id -u)/com.d0n9x1n.copilot-relay" | grep state
curl -fsS http://127.0.0.1:4142/healthz
scripts/check.sh instructions
scripts/check.sh all
```

launchd 和健康检查请看[服务与自动化](Services-and-Automation-zh-CN.md)。
