# Agent Skills (npx skills)

通用 skill 统一由 `npx skills` 管理，正文只在 `~/.agents/skills`。

## 当前包

| 源 | 说明 |
|----|------|
| `K-Dense-AI/scientific-agent-skills` | 科研 / 生物信息 |
| `https://open.feishu.cn` | 飞书 Lark |
| `git@github.com:kepano/obsidian-skills.git` | Obsidian：bases / markdown / canvas / cli / defuddle |
| `https://github.com/Yuan1z0825/nature-skills.git` | Nature 向写作 / 配图 / 审稿 / 读论文 / PPT / 专利（19 skills） |

## 目标 agents

`agents.txt`：claude-code、codex、pi、grok

## 命令

```bash
# 重装清单
~/dotfiles/skills/install.sh

# Obsidian 单独装（整仓 5 个 skill）
npx skills add git@github.com:kepano/obsidian-skills.git -g --skill '*' \
  -a claude-code -a pi -a codex -a grok -y

npx skills ls -g
npx skills update -g -y
```

## 说明

- Obsidian skills **就是**通过 `kepano/obsidian-skills` 大仓库一次装齐，不需要按 skill 拆仓库。
- Claude 若仍启用 `obsidian@obsidian-skills` 插件，可能与 npx 软链重复；可禁用插件只留 npx。
- Plugin（OMC、superpowers 等）不在此管理。
