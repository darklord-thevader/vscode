# VSCode Minimal Manager

A lightweight manager for VSCode Remote SSH sessions that automatically cleans up server-side processes and optimizes resource usage.

## Features

- **Automatic cleanup** of stale VSCode server processes
- **Resource throttling** to prevent VSCode from consuming excessive system resources
- **Extension profiles** for different project types (Python, Web, etc.)
- **Auto-suspend** functionality for idle sessions with session state preservation
- **Session resumption** to continue where you left off
- **Minimal extension loading**
- **Session monitoring and management**
- **Automatic service installation**
- **Logging for troubleshooting**

## Installation

### Quick Install
```bash
curl -o vscode-minimal-manager.sh https://raw.githubusercontent.com/yourusername/vscode-minimal-manager/main/vscode-minimal-manager.sh
chmod +x vscode-minimal-manager.sh
./vscode-minimal-manager.sh --install
```

### Manual Install
1. Clone the repository:
```bash
git clone https://github.com/yourusername/vscode-minimal-manager.git
```

2. Enter the directory and install:
```bash
cd vscode-minimal-manager
chmod +x vscode-minimal-manager.sh
./vscode-minimal-manager.sh --install
```

## Configuration

The installation will create the following files:

- `~/.vscode-minimal/settings.json` - Primary VSCode settings
- `~/.vscode-minimal/profiles.json` - Extension profiles for different project types

### Customizing Settings

You can modify the settings.json file to adjust behavior:

```json
{
    "vscode-minimal-manager.idleTimeout": 3600,  // Idle time in seconds before suspending (default: 1 hour)
    "vscode-minimal-manager.enableAutoSuspend": true,  // Enable/disable auto-suspend
    "vscode-minimal-manager.enableResourceLimits": true,  // Enable/disable resource limiting
    "vscode-minimal-manager.activeProfile": "default"  // Set the active profile
}
```

### Extension Profiles

Configure different sets of extensions for different project types in profiles.json:

```json
{
    "profiles": {
        "python": {
            "extensions": ["ms-vscode.remote-ssh", "ms-python.python"],
            "resourceLimits": {
                "cpuPriority": 5,
                "memoryLimit": "2G"
            }
        }
    }
}
```

## Usage

The script installs as a systemd service and runs automatically. 

### Basic Commands

Check service status:
```bash
systemctl status vscode-session-manager
```

View logs:
```bash
tail -f ~/.vscode-minimal/vscode-minimal.log
```

List suspended sessions:
```bash
~/.vscode-minimal/vscode-minimal-manager.sh --list-sessions
```

Resume a suspended session:
```bash
~/.vscode-minimal/resume-session.sh <session-id>
```

### Manual Resource Management

Apply resource limits:
```bash
~/.vscode-minimal/vscode-minimal-manager.sh --resource-limits
```

Manually trigger auto-suspend check:
```bash
~/.vscode-minimal/vscode-minimal-manager.sh --auto-suspend
```

## License

MIT License
