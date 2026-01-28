#!/bin/bash

# ==========================================================
# 自动化安装脚本 (yabai, kitty, tmux, spicetify, zsh)
# ==========================================================

DOTFILES="$HOME/dotfiles"

echo "🚀 开始环境部署..."

# 1. 基础依赖安装
echo "📦 正在安装基础依赖..."
if ! command -v brew &> /dev/null; then
    echo "❌ 未检测到 Homebrew，请先安装 Homebrew 再运行此脚本。"
    exit 1
fi

brew install nowplaying-cli jq yabai skhd kitty tmux spicetify-cli

# 2. 系统设置优化
echo "⚙️ 正在优化 macOS 系统设置..."
# 关闭最近使用的空间自动排序 (防止 yabai 索引错乱)
defaults write com.apple.dock mru-spaces -bool false
# 几乎移除窗口缩放动画时间
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
killall Dock

# 3. 建立配置文件软连接 (Symbolic Links)
echo "🔗 正在建立软连接..."
mkdir -p "$HOME/.config"

# zsh
ln -sf "$DOTFILES/zsh/zshrc" "$HOME/.zshrc"

# kitty
ln -sfn "$DOTFILES/kitty" "$HOME/.config/kitty"

# yabai & skhd
ln -sfn "$DOTFILES/yabai" "$HOME/.config/yabai"
ln -sfn "$DOTFILES/skhd" "$HOME/.config/skhd"

# tmux
# 采用现代 XDG 路径
ln -sfn "$DOTFILES/tmux" "$HOME/.config/tmux"

# spicetify
ln -sfn "$DOTFILES/spicetify" "$HOME/.config/spicetify"

# 4. 字体安装
echo "🔡 正在安装 SFMono Nerd Font 与 Sketchybar 字体..."
mkdir -p "$HOME/Library/Fonts"

# SFMono Nerd Font
if [ ! -d "/tmp/SFMono_Nerd_Font" ]; then
    git clone git@github.com:shaunsingh/SFMono-Nerd-Font-Ligaturized.git /tmp/SFMono_Nerd_Font
    mv /tmp/SFMono_Nerd_Font/* "$HOME/Library/Fonts/"
    rm -rf /tmp/SFMono_Nerd_Font/
fi

# Sketchybar App Font
curl -L https://github.com/kvndrsslr/sketchybar-app-font/releases/download/v2.0.28/sketchybar-app-font.ttf -o "$HOME/Library/Fonts/sketchybar-app-font.ttf"

# 5. 特殊组件初始化
echo "🛠 正在初始化 Spicetify..."
# 确保权限
chmod +x "$DOTFILES/spicetify/CustomApps" &> /dev/null
spicetify backup apply &> /dev/null || echo "⚠️ Spicetify 注入失败，可能需要手动重装 Spotify。"

echo "✅ 安装完成！"
echo "👉 请运行 'source ~/.zshrc' 使配置立即生效。"
echo "👉 如果是首次安装 yabai，请记得在系统设置中授予 '屏幕录制' 和 '辅助功能' 权限。"
