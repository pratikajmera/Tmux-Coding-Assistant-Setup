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
│   ├── tmux-sessions.conf.example   # Session config template
│   └── tmux.conf                    # Default tmux config (deployed to ~/.tmux.conf)
└── client/
    ├── tmux-connect.sh              # Multi-server → session menu     (macOS / Linux)
    ├── tmux-claude.sh               # Shortcut: jump to 'claude'      (macOS / Linux)
    ├── tmux-agy.sh                  # Shortcut: jump to 'agy'         (macOS / Linux)
    ├── tmux-connect.ps1             # Multi-server → session menu     (Windows)
    ├── tmux-claude.ps1              # Shortcut: jump to 'claude'      (Windows)
    ├── tmux-agy.ps1                 # Shortcut: jump to 'agy'         (Windows)
    └── tmux-servers.conf.example    # Server list template (shared)
```

---

## Prerequisites — SSH Key Access

The client scripts connect to your server over SSH using key-based authentication. **Password prompts are not supported** — you must have passwordless SSH access set up before using these scripts.

### 1. Generate an SSH key pair (if you don't have one)

**macOS / Linux:**
```bash
ssh-keygen -t ed25519 -C "your-comment"
# Accept the default path (~/.ssh/id_ed25519) or specify one
# Set a passphrase or leave blank for fully passwordless access
```

**Windows (PowerShell):**
```powershell
ssh-keygen -t ed25519 -C "your-comment"
# Key is saved to C:\Users\<you>\.ssh\id_ed25519 by default
```

### 2. Copy your public key to the server

**macOS / Linux:**
```bash
ssh-copy-id root@<server-ip>
# Enter your server password once — never again after this
```

**Windows** (`ssh-copy-id` is not built in — use this one-liner instead):
```powershell
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh root@<server-ip> "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
# Enter your server password once when prompted
```

### 3. Test passwordless access

```bash
ssh root@<server-ip>
# Should log in immediately with no password prompt
```

If it still asks for a password, check that `~/.ssh/authorized_keys` on the server contains your public key and has permissions `600`.

### 4. Repeat for each server

Run steps 2–3 for every server you add to `tmux-servers.conf`.

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
4. Deploy `server/tmux.conf` to `~/.tmux.conf` (backs up any existing config to `~/.tmux.conf.bak`)
5. Install and enable the systemd service
6. Start all sessions immediately

> Safe to re-run — the cleanup step tears down the previous install before setting up fresh.

### Default tmux config

`server/tmux.conf` is installed to `~/.tmux.conf` on the server and includes:

| Setting | Detail |
|---------|--------|
| Prefix key | `Ctrl+A` instead of `Ctrl+B` |
| Mouse mode | Click to select panes, resize, scroll |
| Base index | Windows and panes start at 1 |
| Splits | `Prefix + \|` horizontal, `Prefix + -` vertical |
| Pane navigation | `Alt + Arrow` (no prefix needed) |
| Reload config | `Prefix + r` |
| Scrollback | 50,000 lines |

To customise, edit `~/.tmux.conf` on the server after install and run `Prefix + r` to reload, or edit `server/tmux.conf` in this repo before running the installer.

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

## Client Setup (Windows)

> **Requirements:** Windows 10 1809 or later (OpenSSH client built in). PowerShell 5.1+ (included in all modern Windows installs).

### 1. Allow PowerShell scripts (one-time)

Open PowerShell **as Administrator** and run:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 2. Clone the repo

```powershell
git clone https://github.com/pratikajmera/Tmux-Coding-Assistant-Setup.git
cd Tmux-Coding-Assistant-Setup
```

### 3. Install scripts

```powershell
New-Item -ItemType Directory -Force "$HOME\bin" | Out-Null
Copy-Item client\tmux-connect.ps1 "$HOME\bin\"
Copy-Item client\tmux-claude.ps1  "$HOME\bin\"
Copy-Item client\tmux-agy.ps1    "$HOME\bin\"
```

### 4. Add `$HOME\bin` to PATH

```powershell
$path = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($path -notlike "*$HOME\bin*") {
    [Environment]::SetEnvironmentVariable("PATH", "$HOME\bin;$path", "User")
}
```

Restart your terminal (or open a new window) for the PATH change to take effect.

### 5. Configure servers

```powershell
Copy-Item client\tmux-servers.conf.example "$HOME\bin\tmux-servers.conf"
notepad "$HOME\bin\tmux-servers.conf"
```

Use the same format as macOS/Linux:

```
# display_name | user | local_ip | tailscale_ip
home-server | root | 192.168.1.100 | 100.x.x.x
```

> `tmux-servers.conf` is gitignored — never committed, always local.

### 6. (Optional) Add PowerShell aliases

Add to your PowerShell profile (`notepad $PROFILE`):

```powershell
Set-Alias tmux-connect "$HOME\bin\tmux-connect.ps1"
Set-Alias tmux-claude  "$HOME\bin\tmux-claude.ps1"
Set-Alias tmux-agy     "$HOME\bin\tmux-agy.ps1"
```

### Usage (Windows)

```powershell
tmux-connect                  # pick server → pick session
tmux-connect home-server      # pick session on a specific server
tmux-claude                   # jump straight to the 'claude' session
tmux-agy home-server          # jump to 'agy' on a named server
```

> **Note:** If OpenSSH is not installed, enable it via **Settings → Apps → Optional Features → OpenSSH Client**, or install [Windows Terminal](https://aka.ms/terminal) which bundles it.

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
