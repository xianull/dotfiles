# fzf shell integration (requires fzf >= 0.48, install: brew install fzf)
command -v fzf &>/dev/null && source <(fzf --zsh)

# Gruvbox Dark
export FZF_DEFAULT_OPTS="
  --color=bg:#282828,bg+:#3c3836,fg:#ebdbb2,fg+:#ebdbb2
  --color=hl:#fabd2f,hl+:#fe8019,info:#8ec07c,prompt:#fb4934
  --color=pointer:#fe8019,marker:#fabd2f,spinner:#8ec07c,header:#928374
  --color=border:#504945,gutter:#282828
  --layout=reverse
  --border=rounded
  --prompt='  '
  --pointer='▶'
  --marker='●'
  --height=40%
  --bind=ctrl-/:toggle-preview
"

# Use fd for file listing if available (brew install fd)
if command -v fd &>/dev/null; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
fi
