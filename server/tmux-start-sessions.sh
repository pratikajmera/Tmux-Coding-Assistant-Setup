#!/bin/bash
# tmux-start-sessions.sh
# Creates tmux sessions with a 3-pane layout as defined in tmux-sessions.conf.
# Installed to /root/ by tmux-install.sh. Sessions are skipped if they already exist.
#
# Layout per session:
# ┌────────┬────────┐
# │        │        │
# │        │ Pane 2 │
# │ Pane 1 │        │
# │        ├────────┤
# │        │        │
# │        │ Pane 3 │
# └────────┴────────┘

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSIONS_CONF="$SCRIPT_DIR/tmux-sessions.conf"

# Fall back to example config if tmux-sessions.conf doesn't exist
if [[ ! -f "$SESSIONS_CONF" ]]; then
  SESSIONS_CONF="$SCRIPT_DIR/tmux-sessions.conf.example"
fi

create_session() {
  local name=$1
  local dir=$2

  # Expand ~ to $HOME
  dir="${dir/#\~/$HOME}"

  # Create directory if it doesn't exist
  mkdir -p "$dir"

  tmux new-session -d -s "$name" -n "$name" -c "$dir"  # pane 1: main left
  tmux split-window -h -t "$name" -c "$dir"             # pane 2: right
  tmux split-window -v -t "$name" -c "$dir"             # pane 3: bottom-right
  tmux select-pane -t "$name:1.1"                       # focus main left pane on attach

  echo "  ✓ Session '$name' created → $dir"
}

echo "Starting tmux sessions..."

while IFS='|' read -r name dir || [[ -n "$name" ]]; do
  # Skip comments and blank lines
  [[ "$name" =~ ^[[:space:]]*# ]] && continue
  [[ -z "${name// }" ]] && continue

  name=$(echo "$name" | xargs)
  dir=$(echo "$dir" | xargs)

  if tmux has-session -t "$name" 2>/dev/null; then
    echo "  – Session '$name' already exists, skipping."
  else
    create_session "$name" "$dir"
  fi
done < "$SESSIONS_CONF"
