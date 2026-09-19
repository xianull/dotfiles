#!/usr/bin/env bash
FZF=$(command -v fzf || echo /opt/homebrew/bin/fzf)
[[ -x "$FZF" ]] || { echo "fzf not found"; sleep 2; exit 1; }

FMT="#{session_name}  #{session_windows}w  #{?session_attached,● ,  }"

session=$(tmux list-sessions -F "$FMT" 2>/dev/null | \
    "$FZF" --reverse --no-info --no-sort \
        --prompt="  sessions  " \
        --color="bg:#282828,bg+:#3c3836,fg:#ebdbb2,fg+:#ebdbb2,hl:#fabd2f,hl+:#fe8019,prompt:#fb4934,pointer:#fe8019,gutter:#282828,border:#504945" \
        --bind="ctrl-d:execute-silent(tmux kill-session -t {1})+reload(tmux list-sessions -F '$FMT')" \
    | awk '{print $1}')

[ -n "$session" ] && tmux switch-client -t "$session"
