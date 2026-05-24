# tmux-claude.ps1 -- Shortcut: connect to the 'claude' session on a server
# Usage:
#   tmux-claude.ps1                -> auto-picks server (or shows menu if multiple)
#   tmux-claude.ps1 <server-name>  -> connect to claude on a specific server

param([string]$ServerArg = "")
& "$PSScriptRoot\tmux-connect.ps1" $ServerArg "claude"
