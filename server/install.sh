#!/bin/bash
# install.sh — Set up Tmux Coding Assistant on a new server
# Run as root on Ubuntu/Debian: bash install.sh
#
# What it does:
#   1. Installs tmux if not present
#   2. Copies sessions.conf (or prompts to create one from example)
#   3. Creates session working directories
#   4. Installs start_tmux_sessions.sh to /root/
#   5. Installs and enables the systemd service
#   6. Starts the service (creates sessions immediately)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSIONS_CONF="$SCRIPT_DIR/sessions.conf"
SESSIONS_EXAMPLE="$SCRIPT_DIR/sessions.conf.example"
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

# ── 2. Resolve sessions.conf ─────────────────────────────────────────────────

header "Step 2: Session configuration"
if [[ ! -f "$SESSIONS_CONF" ]]; then
  info "sessions.conf not found — copying from example..."
  cp "$SESSIONS_EXAMPLE" "$SESSIONS_CONF"
  echo ""
  echo "  sessions.conf has been created at:"
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

# ── 4. Install scripts ───────────────────────────────────────────────────────

header "Step 4: Installing scripts"
cp "$SCRIPT_DIR/start_tmux_sessions.sh" "$INSTALL_DIR/start_tmux_sessions.sh"
cp "$SESSIONS_CONF" "$INSTALL_DIR/sessions.conf"
chmod +x "$INSTALL_DIR/start_tmux_sessions.sh"
ok "Installed start_tmux_sessions.sh → $INSTALL_DIR/"
ok "Installed sessions.conf → $INSTALL_DIR/"

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
