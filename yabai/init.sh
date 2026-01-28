# 需要手动关闭sip
# csrutil enable --without fs --without debug --without nvram
cat << 'EOF' > fix_yabai.sh
#!/bin/bash

# 1. 设置 NVRAM 参数
echo "正在设置 nvram boot-args..."
sudo nvram boot-args="-arm64e_preview_abi"

# 2. 获取 yabai 的绝对路径
YABAI_PATH=$(which yabai)
USER_NAME=$(whoami)

# 3. 配置 sudoers 免密和环境变量保留
echo "正在配置 sudoers 权限..."
sudo tee /etc/sudoers.d/yabai <<SUDOEOF
# 保留终端变量，解决 TERMINFO 报错
Defaults env_keep += "TERMINFO TERMINFO_DIRS"

# 允许当前用户免密执行 yabai --load-sa
$USER_NAME ALL=(root) NOPASSWD: $YABAI_PATH --load-sa
SUDOEOF

# 4. 设置文件权限
sudo chmod 440 /etc/sudoers.d/yabai

echo "------------------------------------------------"
echo "✅ 配置完成！"
echo "⚠️  重要：你必须立即重启电脑，nvram 参数才会生效。"
echo "重启后，yabai 即可正常加载 Scripting Addition。"
echo "------------------------------------------------"
EOF

# 赋予执行权限并运行
chmod +x fix_yabai.sh
./fix_yabai.sh

