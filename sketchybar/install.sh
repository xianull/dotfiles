#!/bin/bash
# SketchyBar 依赖：命令行工具、图标字体、SbarLua、helper 二进制。
# 主 install.sh 会调用；也可以单独跑。

DIR="$(cd "$(dirname "$0")" && pwd)"

## 组件里用到的命令行工具
brew install lua nowplaying-cli jq switchaudio-osx cava

## 应用图标字体
mkdir -p "$HOME/Library/Fonts"
curl -fsSL https://github.com/kvndrsslr/sketchybar-app-font/releases/download/v2.0.28/sketchybar-app-font.ttf \
    -o "$HOME/Library/Fonts/sketchybar-app-font.ttf"

# SbarLua (must match Homebrew lua; rebuild after `brew upgrade lua`)
rm -rf /tmp/SbarLua
git clone https://github.com/FelixKratz/SbarLua.git /tmp/SbarLua && (cd /tmp/SbarLua && make install) && rm -rf /tmp/SbarLua

## helper 二进制：不预先编译的话，sketchybar 第一次启动会同步 make，期间栏是空的
(cd "$DIR/helpers" && make)
