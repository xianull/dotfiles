# Claude Code plugins (manifest only)

不提交 `~/.claude/plugins/cache` 与 marketplace 克隆正文。

| 文件 | 作用 |
|------|------|
| `marketplaces.json` | 插件市场源（GitHub repo / git URL） |
| `plugins-manifest.json` | 已安装 user-scope 插件清单 |

## 重装思路

Claude Code 插件一般用应用内 marketplace / `claude plugin` 流程。
本目录仅作 **备份与迁移参考**，新机器上按 `marketplaces.json` 添加源后，再按 `plugins-manifest.json` 逐个安装。

当前含：obsidian 系列、oh-my-claudecode、superpowers、codex、ppt-master、karpathy-skills、k-dense-scientific 等。
