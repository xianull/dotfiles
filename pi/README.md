# Pi agent 配置

只管理 **可共享的插件/包声明**，不提交密钥与运行时数据。

## 目录

| 路径 | 作用 | 是否进 git |
|------|------|------------|
| `settings.json` | 主题、默认模型、`packages` 插件列表 | ✅ |
| `npm/package.json` | npm 插件依赖声明（当前 `pi-grok-cli`） | ✅ |
| `npm/package-lock.json` | 锁定版本 | ✅ |
| `~/.pi/agent/npm/node_modules/` | 安装产物 | ❌ 本地 |
| `~/.pi/agent/auth.json` | 登录态 | ❌ |
| `~/.pi/agent/models.json` | 自定义 provider（含 API key） | ❌ |
| `~/.pi/agent/extensions/otty-integration.ts` | Otty 自动写入 | ❌ |
| `~/.pi/agent/sessions/` | 会话记录 | ❌ |

## 软链

```text
~/.pi/agent/settings.json          → ~/dotfiles/pi/settings.json
~/.pi/agent/npm/package.json       → ~/dotfiles/pi/npm/package.json
~/.pi/agent/npm/package-lock.json  → ~/dotfiles/pi/npm/package-lock.json
```

## 插件管理

当前插件通过 `settings.json` 的 `packages` 声明：

```json
"packages": ["npm:pi-grok-cli"]
```

常用命令：

```bash
pi install npm:pi-grok-cli   # 安装并写入 settings
pi list                      # 查看已装包
pi update --extensions       # 更新插件包
pi remove npm:pi-grok-cli
```

新机器：软链配置后执行一次：

```bash
cd ~/.pi/agent/npm && npm install
# 或启动 pi 时会按 packages 自动安装缺失包
```
