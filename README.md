# VSCode Minimal Manager

A lightweight manager for VSCode Remote SSH sessions that automatically cleans up server-side processes and optimizes resource usage.

## Features

- Automatic cleanup of stale VSCode server processes
- Minimal extension loading
- Session monitoring and management
- Automatic service installation
- Logging for troubleshooting

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

The installation will create minimal VSCode settings at `~/.vscode-minimal/settings.json`. You can modify these settings as needed.

## Usage

The script installs as a systemd service and runs automatically. No manual intervention is required.

To check status:
```bash
systemctl status vscode-session-manager
```

To view logs:
```bash
tail -f ~/.vscode-minimal/vscode-minimal.log
```

## License

MIT License
