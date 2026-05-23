# Tmux Coding Assistant Setup

Automated tmux session management for remote coding servers. Starts persistent, pre-configured sessions on boot — connect from any machine with a single command.

## Features

- **Auto-start on boot** via systemd — sessions survive reboots
- **3-pane layout** per session (main left + two stacked right), each in its own working directory
- **Smart client connection** — auto-detects local network vs Tailscale
- **Multi-server support** — manage sessions across multiple servers from one client
- **Configurable** — add/remove sessions via a simple config file
- **One-command install** on new servers

## Repository Structure

```
├── server/
│   ├── tmux-install.sh              # Run once on each new server (cleans up old install first)
│   ├── tmux-start-sessions.sh       # Starts sessions (called by systemd)
│   ├── tmux-sessions.service        # systemd unit file
│   └── tmux-sessions.conf.example   # Session config template
└── client/
    ├── tmux-connect.sh              # Multi-server → session menu
    ├── tmux-claude.sh               # Shortcut: jump to 'claude' session
    ├── tmux-agy.sh                  # Shortcut: jump to 'agy' session
    └── tmux-servers.conf.example    # Server list template
```

---

## Server Setup

### Prerequisites

- Ubuntu / Debian
- Run as `root`

### 1. Clone the repo

```bash
git clone https://github.com/pratikajmera/Tmux-Coding-Assistant-Setup.git
cd Tmux-Coding-Assistant-Setup
```

### 2. Configure sessions

```bash
cp server/tmux-sessions.conf.example server/tmux-sessions.conf
```

Edit `server/tmux-sessions.conf` to define your sessions:

```
# session_name | start_directory
claude | ~/claude
agy    | ~/agy
```

> Add as many sessions as you need. Each gets a 3-pane layout in its directory.

### 3. Run the installer

```bash
bash server/tmux-install.sh
```

The installer will:
0. Clean up any existing installation (stop service, kill sessions, remove old scripts)
1. Install tmux (if not already present)
2. Create the session working directories
3. Copy scripts to `/root/`
4. Install and enable the systemd service
5. Start all sessions immediately

> Safe to re-run — the cleanup step tears down the previous install before setting up fresh.

### 4. Verify

```bash
tmux list-sessions
systemctl status tmux-sessions.service
```

Expected output:
```
claude: 1 windows
agy: 1 windows
```

---

## Client Setup (macOS / Linux)

### 1. Clone the repo on your client machine

```bash
git clone https://github.com/pratikajmera/Tmux-Coding-Assistant-Setup.git
```

### 2. Install scripts

```bash
mkdir -p ~/bin
cp client/tmux-connect.sh  ~/bin/
cp client/tmux-claude.sh   ~/bin/
cp client/tmux-agy.sh      ~/bin/
chmod +x ~/bin/tmux-connect.sh ~/bin/tmux-claude.sh ~/bin/tmux-agy.sh
```

### 3. Add `~/bin` to PATH

**macOS (zsh):**
```bash
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
```

**Linux (bash):**
```bash
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
```

### 4. Configure servers

```bash
cp client/tmux-servers.conf.example ~/bin/tmux-servers.conf
```

Edit `~/bin/tmux-servers.conf` with your server details:

```
# display_name | user | local_ip | tailscale_ip
home-server | root | 192.168.1.100 | 100.x.x.x
```

- **local_ip** — used when on the same LAN (leave blank to always use Tailscale)
- **tailscale_ip** — fallback when local is unreachable (leave blank if not using Tailscale)

> `tmux-servers.conf` is gitignored — never committed, always local.

### 5. (Optional) Add shell aliases

```bash
cat >> ~/.zshrc << 'EOF'
alias tmux-connect='~/bin/tmux-connect.sh'
alias tmux-claude='~/bin/tmux-claude.sh'
alias tmux-agy='~/bin/tmux-agy.sh'
EOF
source ~/.zshrc
```

---

## Usage

### Connect (with menu)
```bash
tmux-connect            # pick server → pick session
tmux-connect home-server  # pick session on a specific server
```

### Connect directly to a session
```bash
tmux-claude             # → claude session (auto-picks server if only one)
tmux-agy                # → agy (antigravity) session
tmux-claude home-server # → claude on a named server
```

### Inside tmux — useful shortcuts

| Keys | Action |
|------|--------|
| `Ctrl+b %` | Split pane vertically |
| `Ctrl+b "` | Split pane horizontally |
| `Ctrl+b →/←/↑/↓` | Navigate panes |
| `Ctrl+b d` | Detach (session keeps running) |
| `Ctrl+b $` | Rename session |

---

## Adding a New Session

1. Edit `/root/tmux-sessions.conf` on the server
2. Add a new line: `my-session | ~/my-project`
3. Restart the service:
   ```bash
   systemctl restart tmux-sessions.service
   ```

## Adding a New Server (client side)

Add a line to `~/bin/tmux-servers.conf`:
```
new-server | root | 10.0.0.x | 100.x.x.x
```

No restart needed — the script reads the file on each run.

## Adding a New Server (server side)

SSH into the new server and repeat the [Server Setup](#server-setup) steps.

---

## How It Works

```
systemd boot
    └── tmux-sessions.service (Type=oneshot, RemainAfterExit=yes)
            └── /root/tmux-start-sessions.sh
                    └── reads /root/tmux-sessions.conf
                            └── tmux new-session -d  (one per entry)
                                    └── 3-pane layout in configured directory
```

```
tmux-connect.sh (client)
    ├── reads ~/bin/tmux-servers.conf
    ├── shows server menu (if >1 server)
    ├── ping local_ip → use it if reachable, else try tailscale_ip
    ├── ssh into server → tmux list-sessions
    ├── shows session menu
    └── ssh -t → tmux attach-session
```

---

## Troubleshooting

**Sessions not starting on boot:**
```bash
systemctl status tmux-sessions.service
journalctl -u tmux-sessions.service
```

**Can't connect from client:**
```bash
ssh root@<server-ip>          # test SSH first
tmux list-sessions            # check sessions exist on server
```

**Tailscale not working:**
```bash
tailscale status              # check Tailscale is connected
tailscale ip                  # verify your Tailscale IP
```

**Wrong directory on pane start:**  
Check `/root/tmux-sessions.conf` on the server — paths must exist or the script creates them.
