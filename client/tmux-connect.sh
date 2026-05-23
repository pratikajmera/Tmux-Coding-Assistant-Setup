#!/bin/bash
# tmux-connect.sh — Connect to a tmux session on a remote server
#
# Usage:
#   tmux-connect.sh                        → pick server, then session
#   tmux-connect.sh <server-name>          → pick session on named server
#   tmux-connect.sh <server-name> <session>→ connect directly
#
# Requires: ~/bin/servers.conf  (copy from servers.conf.example and fill in)

SERVERS_CONF="${HOME}/bin/servers.conf"

# ── Load servers ──────────────────────────────────────────────────────────────

load_servers() {
  if [[ ! -f "$SERVERS_CONF" ]]; then
    echo "Error: servers.conf not found at $SERVERS_CONF"
    echo ""
    echo "Create it by copying the example from the repo:"
    echo "  cp servers.conf.example ~/bin/servers.conf"
    echo "Then fill in your server IPs."
    exit 1
  fi

  # Read non-comment, non-empty lines into array
  mapfile -t SERVER_LINES < <(grep -v '^\s*#' "$SERVERS_CONF" | grep -v '^\s*$')

  if [[ ${#SERVER_LINES[@]} -eq 0 ]]; then
    echo "No servers found in $SERVERS_CONF"
    exit 1
  fi
}

# ── Pick / resolve a server ───────────────────────────────────────────────────

pick_server() {
  local filter=$1
  load_servers

  # Direct match by name
  if [[ -n "$filter" ]]; then
    for line in "${SERVER_LINES[@]}"; do
      IFS='|' read -r name user local_ip tailscale_ip <<< "$line"
      name=$(echo "$name" | xargs)
      if [[ "$name" == "$filter" ]]; then
        SERVER_NAME="$name"
        SERVER_USER=$(echo "$user" | xargs)
        SERVER_LOCAL=$(echo "$local_ip" | xargs)
        SERVER_TAILSCALE=$(echo "$tailscale_ip" | xargs)
        return
      fi
    done
    echo "Server '$filter' not found in $SERVERS_CONF"
    exit 1
  fi

  # Only one server — use it silently
  if [[ ${#SERVER_LINES[@]} -eq 1 ]]; then
    IFS='|' read -r name user local_ip tailscale_ip <<< "${SERVER_LINES[0]}"
    SERVER_NAME=$(echo "$name" | xargs)
    SERVER_USER=$(echo "$user" | xargs)
    SERVER_LOCAL=$(echo "$local_ip" | xargs)
    SERVER_TAILSCALE=$(echo "$tailscale_ip" | xargs)
    return
  fi

  # Multiple servers — show menu
  echo "Select a server:"
  echo "────────────────"
  local i=1
  for line in "${SERVER_LINES[@]}"; do
    IFS='|' read -r name user local_ip tailscale_ip <<< "$line"
    echo "  [$i] $(echo "$name" | xargs)"
    ((i++))
  done
  echo ""
  read -rp "Server (number): " choice

  local chosen="${SERVER_LINES[$((choice-1))]}"
  if [[ -z "$chosen" ]]; then
    echo "Invalid choice."
    exit 1
  fi

  IFS='|' read -r name user local_ip tailscale_ip <<< "$chosen"
  SERVER_NAME=$(echo "$name" | xargs)
  SERVER_USER=$(echo "$user" | xargs)
  SERVER_LOCAL=$(echo "$local_ip" | xargs)
  SERVER_TAILSCALE=$(echo "$tailscale_ip" | xargs)
}

# ── Resolve IP: local preferred, Tailscale as fallback ───────────────────────

resolve_ip() {
  if [[ -n "$SERVER_LOCAL" ]] && ping -c 1 -W 1 "$SERVER_LOCAL" &>/dev/null; then
    SERVER_IP="$SERVER_LOCAL"
    echo "[local → $SERVER_NAME]"
  elif [[ -n "$SERVER_TAILSCALE" ]]; then
    SERVER_IP="$SERVER_TAILSCALE"
    echo "[tailscale → $SERVER_NAME]"
  elif [[ -n "$SERVER_LOCAL" ]]; then
    SERVER_IP="$SERVER_LOCAL"
    echo "[local → $SERVER_NAME]"
  else
    echo "Error: No IP configured for '$SERVER_NAME'"
    exit 1
  fi
}

# ── Pick a session ────────────────────────────────────────────────────────────

pick_session() {
  local filter=$1

  # Session name provided directly
  if [[ -n "$filter" ]]; then
    SESSION="$filter"
    return
  fi

  echo "Fetching sessions..."
  SESSIONS=$(ssh "$SERVER_USER@$SERVER_IP" "tmux list-sessions -F '#{session_name}' 2>/dev/null")

  if [[ -z "$SESSIONS" ]]; then
    echo "No tmux sessions found on $SERVER_NAME."
    exit 1
  fi

  echo ""
  echo "Available sessions:"
  echo "───────────────────"
  local i=1
  while IFS= read -r s; do
    echo "  [$i] $s"
    ((i++))
  done <<< "$SESSIONS"
  echo ""

  read -rp "Session (number): " choice
  SESSION=$(echo "$SESSIONS" | sed -n "${choice}p")

  if [[ -z "$SESSION" ]]; then
    echo "Invalid choice."
    exit 1
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────────

pick_server "$1"
resolve_ip
pick_session "$2"

echo "Connecting to '$SESSION'..."
ssh -t "$SERVER_USER@$SERVER_IP" \
  "tmux attach-session -t '$SESSION' 2>/dev/null || \
   (echo \"Session '$SESSION' not found — creating it...\"; tmux new-session -s '$SESSION')"
