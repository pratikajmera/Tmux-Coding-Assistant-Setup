#!/bin/bash
# Shortcut: connect to the 'gemini' session on a server
# Usage:
#   tmux-gemini.sh              → auto-picks server (or shows menu if multiple)
#   tmux-gemini.sh <server-name>→ connect to gemini on a specific server

"$(dirname "$0")/tmux-connect.sh" "$1" gemini
