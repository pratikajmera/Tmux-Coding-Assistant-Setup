#!/bin/bash
# tmux-install.sh — Set up Tmux Coding Assistant on a new server
# Run as root on Ubuntu/Debian: bash tmux-install.sh
#
# What it does:
#   0. Cleans up any previous installation (service, sessions, scripts)
#   1. Installs tmux if not present
#   2. Copies tmux-sessions.conf (or prompts to create one from example)
#   3. Creates session working directories
#   4. Installs tmux-start-sessions.sh to /root/
#   5. Installs and enables the systemd service
#   6. Starts the service (creates sessions immediately)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSIONS_CONF="$SCRIPT_DIR/tmux-sessions.conf"
SESSIONS_EXAMPLE="$SCRIPT_DIR/tmux-sessions.conf.example"
INSTALL_DIR="/root"
SERVICE_FILE="/etc/systemd/system/tmux-sessions.service"

# ── Helpers ──────────────────────────────────────────────────────────────────

header() { echo; echo "=== $1 ==="; }
ok()     { echo "  ✓ $1"; }
info()   { echo "  → $1"; }

# ── Root check ───────────────────────────────────────────────────────────────

if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root."
  exit 1
fi

header "Tmux Coding Assistant — Server Setup"

# ── 0. Cleanup previous installation ─────────────────────────────────────────

header "Step 0: Cleaning up previous installation"

# Stop and disable the systemd service if it exists
if systemctl is-active --quiet tmux-sessions.service 2>/dev/null; then
  systemctl stop tmux-sessions.service
  ok "Stopped tmux-sessions.service"
fi
if systemctl is-enabled --quiet tmux-sessions.service 2>/dev/null; then
  systemctl disable tmux-sessions.service
  ok "Disabled tmux-sessions.service"
fi

# Remove old service file
if [[ -f "$SERVICE_FILE" ]]; then
  rm -f "$SERVICE_FILE"
  systemctl daemon-reload
  ok "Removed $SERVICE_FILE"
fi

# Kill existing tmux sessions defined in the active conf (or example as fallback)
CLEANUP_CONF="${SESSIONS_CONF:-$SESSIONS_EXAMPLE}"
if [[ -f "$CLEANUP_CONF" ]]; then
  while IFS='|' read -r name dir || [[ -n "$name" ]]; do
    [[ "$name" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${name// }" ]] && continue
    name=$(echo "$name" | xargs)
    if tmux has-session -t "$name" 2>/dev/null; then
      tmux kill-session -t "$name"
      ok "Killed tmux session '$name'"
    fi
  done < "$CLEANUP_CONF"
fi

# Remove old installed scripts (including legacy names from previous installs)
for f in tmux-start-sessions.sh tmux-sessions.conf start_tmux_sessions.sh; do
  if [[ -f "$INSTALL_DIR/$f" ]]; then
    rm -f "$INSTALL_DIR/$f"
    ok "Removed $INSTALL_DIR/$f"
  fi
done

# ── 1. Install tmux ──────────────────────────────────────────────────────────

header "Step 1: tmux"
if command -v tmux &>/dev/null; then
  ok "tmux already installed ($(tmux -V))"
else
  info "Installing tmux..."
  apt-get update -qq
  apt-get install -y tmux
  ok "tmux installed ($(tmux -V))"
fi

# ── 2. Resolve tmux-sessions.conf ────────────────────────────────────────────

header "Step 2: Session configuration"
if [[ ! -f "$SESSIONS_CONF" ]]; then
  info "tmux-sessions.conf not found — copying from example..."
  cp "$SESSIONS_EXAMPLE" "$SESSIONS_CONF"
  echo ""
  echo "  tmux-sessions.conf has been created at:"
  echo "  $SESSIONS_CONF"
  echo ""
  echo "  Edit it to customise session names and directories, then re-run:"
  echo "  bash $0"
  exit 0
fi
ok "Using $SESSIONS_CONF"

# ── 3. Create session directories ────────────────────────────────────────────

header "Step 3: Creating session directories"
while IFS='|' read -r name dir || [[ -n "$name" ]]; do
  [[ "$name" =~ ^[[:space:]]*# ]] && continue
  [[ -z "${name// }" ]] && continue

  dir=$(echo "$dir" | xargs)
  dir="${dir/#\~/$HOME}"
  mkdir -p "$dir"
  ok "Created: $dir"
done < "$SESSIONS_CONF"

# ── 4. Install scripts and config ────────────────────────────────────────────

header "Step 4: Installing scripts and config"
cp "$SCRIPT_DIR/tmux-start-sessions.sh" "$INSTALL_DIR/tmux-start-sessions.sh"
cp "$SESSIONS_CONF" "$INSTALL_DIR/tmux-sessions.conf"
chmod +x "$INSTALL_DIR/tmux-start-sessions.sh"
ok "Installed tmux-start-sessions.sh → $INSTALL_DIR/"
ok "Installed tmux-sessions.conf → $INSTALL_DIR/"

# Deploy tmux config — back up any existing one first
TMUX_CONF="$HOME/.tmux.conf"
if [[ -f "$TMUX_CONF" ]] && ! diff -q "$SCRIPT_DIR/tmux.conf" "$TMUX_CONF" &>/dev/null; then
  cp "$TMUX_CONF" "${TMUX_CONF}.bak"
  ok "Backed up existing ~/.tmux.conf → ~/.tmux.conf.bak"
fi
cp "$SCRIPT_DIR/tmux.conf" "$TMUX_CONF"
ok "Installed tmux.conf → ~/.tmux.conf"

# ── 5. Install systemd service ───────────────────────────────────────────────

header "Step 5: Setting up systemd service"
cp "$SCRIPT_DIR/tmux-sessions.service" "$SERVICE_FILE"
systemctl daemon-reload
systemctl enable tmux-sessions.service
ok "Service installed and enabled (auto-starts on reboot)"

# ── 6. Start service ─────────────────────────────────────────────────────────

header "Step 6: Starting sessions"
systemctl restart tmux-sessions.service
systemctl status tmux-sessions.service --no-pager -l

# ── Summary ──────────────────────────────────────────────────────────────────

header "Setup complete"
echo "Sessions running:"
while IFS='|' read -r name dir || [[ -n "$name" ]]; do
  [[ "$name" =~ ^[[:space:]]*# ]] && continue
  [[ -z "${name// }" ]] && continue
  echo "  • $(echo "$name" | xargs) → $(echo "$dir" | xargs)"
done < "$SESSIONS_CONF"
echo ""
echo "Verify with:  tmux list-sessions"
echo "Attach with:  tmux attach-session -t <name>"
