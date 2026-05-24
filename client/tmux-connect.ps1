# tmux-connect.ps1 -- Connect to a tmux session on a remote server
#
# Usage:
#   tmux-connect.ps1                              -> pick server, then session
#   tmux-connect.ps1 <server-name>                -> pick session on named server
#   tmux-connect.ps1 <server-name> <session-name> -> connect directly
#
# Requires: $HOME\bin\tmux-servers.conf  (copy from tmux-servers.conf.example and fill in)
# Requires: OpenSSH client (built into Windows 10 1809+)

param(
    [string]$ServerArg  = "",
    [string]$SessionArg = ""
)

$SERVERS_CONF = "$HOME\bin\tmux-servers.conf"

# -- Load servers --------------------------------------------------------------

function Load-Servers {
    if (-not (Test-Path $SERVERS_CONF)) {
        Write-Host "Error: tmux-servers.conf not found at $SERVERS_CONF"
        Write-Host ""
        Write-Host "Create it by copying the example from the repo:"
        Write-Host "  Copy-Item tmux-servers.conf.example $SERVERS_CONF"
        Write-Host "Then fill in your server IPs."
        exit 1
    }

    $lines = Get-Content $SERVERS_CONF |
             Where-Object { $_ -notmatch '^\s*#' -and $_ -notmatch '^\s*$' }

    if (-not $lines -or $lines.Count -eq 0) {
        Write-Host "No servers found in $SERVERS_CONF"
        exit 1
    }

    return @($lines)   # force array even for a single line
}

# -- Parse a config line into a hashtable --------------------------------------

function Parse-ServerLine {
    param([string]$line)
    $parts = $line -split '\|'
    return @{
        Name        = $parts[0].Trim()
        User        = $parts[1].Trim()
        LocalIp     = if ($parts.Count -gt 2) { $parts[2].Trim() } else { "" }
        TailscaleIp = if ($parts.Count -gt 3) { $parts[3].Trim() } else { "" }
    }
}

# -- Pick / resolve a server ---------------------------------------------------

function Pick-Server {
    param([string]$filter)

    $lines = Load-Servers

    # Direct match by name
    if ($filter -ne "") {
        foreach ($line in $lines) {
            $s = Parse-ServerLine $line
            if ($s.Name -eq $filter) { return $s }
        }
        Write-Host "Server '$filter' not found in $SERVERS_CONF"
        exit 1
    }

    # Only one server -- use it silently
    if ($lines.Count -eq 1) {
        return Parse-ServerLine $lines[0]
    }

    # Multiple servers -- show menu
    Write-Host "Select a server:"
    Write-Host "----------------"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $name = (Parse-ServerLine $lines[$i]).Name
        Write-Host "  [$($i+1)] $name"
    }
    Write-Host ""
    $choice = Read-Host "Server (number)"

    $idx = [int]$choice - 1
    if ($idx -lt 0 -or $idx -ge $lines.Count) {
        Write-Host "Invalid choice."
        exit 1
    }

    return Parse-ServerLine $lines[$idx]
}

# -- Resolve IP: local preferred, Tailscale as fallback ------------------------
# Uses ping (built into all Windows versions) -- avoids PS-version-specific cmdlets.

function Resolve-ServerIp {
    param($server)

    if ($server.LocalIp -ne "") {
        $pingOut = & ping -n 1 -w 1000 $server.LocalIp 2>$null
        if ($pingOut -match "TTL=") {
            Write-Host "[local -> $($server.Name)]"
            return $server.LocalIp
        }
    }

    if ($server.TailscaleIp -ne "") {
        Write-Host "[tailscale -> $($server.Name)]"
        return $server.TailscaleIp
    }

    if ($server.LocalIp -ne "") {
        # No ping response but local IP is all we have -- try anyway
        Write-Host "[local -> $($server.Name)]"
        return $server.LocalIp
    }

    Write-Host "Error: No IP configured for '$($server.Name)'"
    exit 1
}

# -- Pick a session ------------------------------------------------------------

function Pick-Session {
    param([string]$filter, [string]$user, [string]$ip)

    if ($filter -ne "") { return $filter }

    Write-Host "Fetching sessions..."
    $raw = ssh "$user@$ip" "tmux list-sessions -F '#{session_name}' 2>/dev/null"

    if (-not $raw) {
        Write-Host "No tmux sessions found on server."
        exit 1
    }

    # Normalise line endings (ssh may return CRLF on Windows)
    $sessionList = @(($raw -replace "`r", "") -split "`n" | Where-Object { $_ -ne "" })

    Write-Host ""
    Write-Host "Available sessions:"
    Write-Host "-------------------"
    for ($i = 0; $i -lt $sessionList.Count; $i++) {
        Write-Host "  [$($i+1)] $($sessionList[$i])"
    }
    Write-Host ""
    $choice = Read-Host "Session (number)"

    $idx = [int]$choice - 1
    if ($idx -lt 0 -or $idx -ge $sessionList.Count) {
        Write-Host "Invalid choice."
        exit 1
    }

    return $sessionList[$idx]
}

# -- Main ----------------------------------------------------------------------

$server  = Pick-Server $ServerArg
$ip      = Resolve-ServerIp $server
$session = Pick-Session $SessionArg $server.User $ip

Write-Host "Connecting to '$session'..."
$remoteCmd = "tmux attach-session -t '$session' 2>/dev/null || (echo 'Session not found - creating it...'; tmux new-session -s '$session')"
ssh -t "$($server.User)@$ip" $remoteCmd
