#!/bin/bash
# Shortcut: connect to the 'agy' session on a server
# Usage:
#   tmux-agy.sh              → auto-picks server (or shows menu if multiple)
#   tmux-agy.sh <server-name>→ connect to agy on a specific server

"$(dirname "$0")/tmux-connect.sh" "$1" agy
