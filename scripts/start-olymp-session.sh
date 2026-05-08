#!/bin/bash
# Re-attach if exists, else create
if tmux has-session -t olymp 2>/dev/null; then
  tmux attach -t olymp
else
  tmux new -d -s olymp -n claude  -c "$HOME/net/olymp-day"
  tmux new-window -t olymp -n shell -c "$HOME/net/olymp-day"
  tmux new-window -t olymp -n monitor 'htop'
  tmux select-window -t olymp:claude
  tmux attach -t olymp
fi
