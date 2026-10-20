#!/bin/bash

# ==========================================================
# 新机器部署：git clone 到 ~/dotfiles 后运行 ./install.sh
# 可以重复跑：装过的跳过；目标是真实文件/目录的先备份成 .bak.<时间戳> 再链接
# ==========================================================

DOTFILES="$HOME/dotfiles"

echo "🚀 开始环境部署..."

# 1. 基础依赖
echo "📦 正在安装基础依赖..."
if ! command -v brew &> /dev/null; then
    echo "❌ 未检测到 Homebrew，请先安装 Homebrew 再运行此脚本。"
    exit 1
fi

brew tap asmvik/formulae      # yabai, skhd
brew tap FelixKratz/formulae  # sketchybar, borders
brew install yabai skhd sketchybar borders \
    tmux neovim fzf jq btop neofetch git-lfs node@22 jenv spicetify-cli
brew install --cask ghostty kitty font-hack-nerd-font font-maple-mono-cn font-sf-pro

# 2. 系统设置优化
echo "⚙️ 正在优化 macOS 系统设置..."
# 关闭最近使用的空间自动排序 (防止 yabai 索引错乱)
defaults write com.apple.dock mru-spaces -bool false
# 几乎移除窗口缩放动画时间
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
killall Dock

# 3. oh-my-zsh + powerlevel10k + 插件（zshrc 依赖它们）
echo "🐚 正在安装 oh-my-zsh 与插件..."
clone() { [ -d "$2" ] || git clone --depth=1 "https://github.com/$1.git" "$2"; }
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
clone ohmyzsh/ohmyzsh                   "$HOME/.oh-my-zsh"
clone romkatv/powerlevel10k             "$ZSH_CUSTOM/themes/powerlevel10k"
clone zsh-users/zsh-autosuggestions     "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
clone zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

# 4. 软链
echo "🔗 正在建立软连接..."
link() {
    local src="$DOTFILES/$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        mv "$dst" "$dst.bak.$(date +%s)"
        echo "  已备份原有的 $dst"
    fi
    ln -sfn "$src" "$dst"
}

# TPM 插件目录不进仓库（gitignore），先建出来再链接
mkdir -p "$DOTFILES/tmux/plugins"

link zsh/zshrc                       "$HOME/.zshrc"
link zsh/zprofile                    "$HOME/.zprofile"
link zsh/p10k.zsh                    "$HOME/.p10k.zsh"
link git/config                      "$HOME/.config/git/config"
link npm/npmrc                       "$HOME/.npmrc"
link conda/condarc                   "$HOME/.condarc"
link tmux/.tmux.conf                 "$HOME/.tmux.conf"
link tmux                            "$HOME/.config/tmux"
link tmux/plugins                    "$HOME/.tmux/plugins"
link nvim                            "$HOME/.config/nvim"
link ghostty                         "$HOME/.config/ghostty"
link kitty                           "$HOME/.config/kitty"
link otty                            "$HOME/.config/otty"
link iterm2                          "$HOME/.config/iterm2"
link yabai                           "$HOME/.config/yabai"
link skhd                            "$HOME/.config/skhd"
link sketchybar                      "$HOME/.config/sketchybar"
link sketchybar/scripts/sbar-layout  "$HOME/.local/bin/sbar-layout"
link borders                         "$HOME/.config/borders"
link btop                            "$HOME/.config/btop"
link neofetch                        "$HOME/.config/neofetch"
link raycast                         "$HOME/.config/raycast"
link spicetify                       "$HOME/.config/spicetify"
# herdr: 只链配置，session / 日志留在本机
link herdr/config.toml               "$HOME/.config/herdr/config.toml"
# pi agent settings + 插件清单（auth.json / models.json / sessions / Otty extensions 留在本机）
link pi/settings.json                "$HOME/.pi/agent/settings.json"
link pi/npm/package.json             "$HOME/.pi/agent/npm/package.json"
link pi/npm/package-lock.json        "$HOME/.pi/agent/npm/package-lock.json"

if command -v npm &> /dev/null; then
    (cd "$HOME/.pi/agent/npm" && npm install --omit=dev) \
        || echo "⚠️ pi npm 插件安装失败，可稍后: cd ~/.pi/agent/npm && npm install"
fi

# 5. tmux 插件
echo "🧩 正在安装 tmux 插件..."
clone tmux-plugins/tpm "$DOTFILES/tmux/plugins/tpm"
"$DOTFILES/tmux/plugins/tpm/bin/install_plugins" > /dev/null \
    || echo "⚠️ tmux 插件安装失败，可稍后在 tmux 里按 prefix + M-F12"

# 6. SketchyBar（命令行依赖、图标字体、SbarLua、helper 编译）
echo "📊 正在配置 SketchyBar..."
bash "$DOTFILES/sketchybar/install.sh" || echo "⚠️ SketchyBar 依赖安装失败，可稍后运行 ~/dotfiles/sketchybar/install.sh"

# 7. 后台服务
echo "🪟 正在启动 yabai / skhd / sketchybar..."
yabai --start-service 2> /dev/null || true
skhd --start-service 2> /dev/null || true
brew services start sketchybar
# yabai 卡死自愈，每分钟检查一次
cp "$DOTFILES/yabai/com.user.yabai-watchdog.plist" "$HOME/Library/LaunchAgents/"
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.user.yabai-watchdog.plist" 2> /dev/null || true

# 8. Spicetify
echo "🛠 正在初始化 Spicetify..."
chmod +x "$DOTFILES/spicetify/CustomApps" &> /dev/null
spicetify backup apply &> /dev/null || echo "⚠️ Spicetify 注入失败，可能需要手动重装 Spotify。"

# 9. Agent skills (npx skills; 正文不进 git，按清单重装)
if command -v npx &> /dev/null; then
    echo "🧠 正在安装 agent skills..."
    bash "$DOTFILES/skills/install.sh" || echo "⚠️ skills 安装失败，可稍后手动运行 ~/dotfiles/skills/install.sh"
else
    echo "⚠️ 未检测到 npx，跳过 skills 安装"
fi

echo "✅ 安装完成！"
echo "👉 请运行 'exec zsh' 使配置立即生效。"
echo "👉 在系统设置里给 yabai、skhd 授予「辅助功能」权限，给 yabai 授予「屏幕录制」权限。"
echo "👉 yabai 脚本扩展（透明度、动画、空间操作）需先在恢复模式里部分关闭 SIP，再运行 ~/dotfiles/yabai/init.sh。"
echo "👉 需手动安装：miniconda（装到 ~/.miniconda）、uv（官方安装脚本）、霞鹜文楷等宽 Medium 字体（Ghostty 中文字形）。"
echo "👉 Claude 插件清单见 ~/dotfiles/claude/（需在 Claude Code 内按 marketplace 重装）。"
