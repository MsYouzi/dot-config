# Fork 自定义

[English](Fork-Customization.md) | 简体中文

本 fork（`MsYouzi/dot-config`）跟随 [D0n9X1n/dot-config](https://github.com/D0n9X1n/dot-config)。仅属于 fork 的改动放在独立文件中，合并上游时不会冲突。

## 仅属于 fork 的文件

| 文件 | 用途 |
|---|---|
| `config/zsh/zz-local.zsh` | Intel Homebrew 前缀的 autojump 回退，以及 `uu` 命令 |
| `scripts/local-check.sh` | fork 专属 shell 助手的测试 |
| `wiki/Fork-Customization-zh-CN.md` 及其英文页 | 本页 |

共享文件只增加单行内容：一行 manifest 记录和两条侧边栏条目。

## `j`

安装器通过 Homebrew 安装 `autojump`。`custom.zsh` 从 `/opt/homebrew` 加载其 hook。当 `j` 仍不存在时，`zz-local.zsh` 还会尝试 `$HOMEBREW_PREFIX` 和 `/usr/local`，因此 Intel Mac 上也能使用 `j NAME`。

## `uu`

`uu` 把本机更新到上游最新提交并应用：

1. `cd` 到仓库（`$DOT_CONFIG_DIR`，由链接文件解析得到）。
2. 工作区有未提交改动或当前分支不是 `main` 时停止。
3. 从 `$DOT_CONFIG_UPSTREAM`（默认 `https://github.com/D0n9X1n/dot-config.git`）获取 `main`。
4. 使用 `git merge --no-edit` 合并。发生冲突时运行 `git merge --abort` 并停止，不执行安装。
5. 运行 `./install.sh`。

`uu` 不会 push。需要保存到 fork 时，请自行 push `main`。

## 检查

```sh
scripts/local-check.sh
```

它会检查 zsh 语法，然后在临时仓库中针对干净合并、冲突和脏工作区运行 `uu`。请与 `scripts/check.sh all` 一起运行。
