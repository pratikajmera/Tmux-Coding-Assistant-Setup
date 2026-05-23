#!/bin/bash
# Shortcut: connect to the 'claude' session on a server
# Usage:
#   tmux-claude.sh              → auto-picks server (or shows menu if multiple)
#   tmux-claude.sh <server-name>→ connect to claude on a specific server

"$(dirname "$0")/tmux-connect.sh" "$1" claude
