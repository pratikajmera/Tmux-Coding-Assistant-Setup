# tmux-agy.ps1 -- Shortcut: connect to the 'agy' session on a server
# Usage:
#   tmux-agy.ps1                -> auto-picks server (or shows menu if multiple)
#   tmux-agy.ps1 <server-name>  -> connect to agy on a specific server

param([string]$ServerArg = "")
& "$PSScriptRoot\tmux-connect.ps1" $ServerArg "agy"
