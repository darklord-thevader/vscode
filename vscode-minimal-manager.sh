#!/bin/bash
# vscode-minimal-manager.sh
# A comprehensive solution for managing VSCode remote SSH sessions

# Configuration
INSTALL_DIR="$HOME/.vscode-minimal"
LOG_FILE="$INSTALL_DIR/vscode-minimal.log"
SETTINGS_FILE="$INSTALL_DIR/settings.json"
SERVICE_NAME="vscode-session-manager"

# Create installation directory
mkdir -p "$INSTALL_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to check and kill stale VSCode processes
cleanup_stale_sessions() {
    log "Checking for stale VSCode sessions..."
    
    # Find all VSCode server processes
    for pid in $(pgrep -f "vscode-server"); do
        # Get the parent SSH process
        ppid=$(ps -o ppid= -p "$pid" | tr -d ' ')
        
        # Check if parent SSH session is still active
        if ! ss -tp | grep -q "pid=$ppid"; then
            log "Killing stale VSCode server process: $pid"
            kill -15 "$pid" 2>/dev/null
            sleep 2
            kill -9 "$pid" 2>/dev/null
        fi
    done
    
    # Cleanup any leftover extension processes
    pkill -f "vscode-remote-extension-host" 2>/dev/null
    
    # Clean up temporary files
    rm -rf /tmp/vscode-remote-* 2>/dev/null
    rm -rf /tmp/vscode-ipc-* 2>/dev/null
}

# Function to create minimal VSCode settings
create_minimal_settings() {
    cat > "$SETTINGS_FILE" << EOL
{
    "remote.SSH.defaultExtensions": [
        "ms-vscode.remote-ssh"
    ],
    "remote.SSH.serverDownload": "auto",
    "remote.SSH.connectTimeout": 30,
    "remote.SSH.showLoginTerminal": false,
    "remote.SSH.useLocalServer": false,
    "remote.SSH.enableDynamicForwarding": false,
    "files.watcherExclude": {
        "**/.git/objects/**": true,
        "**/node_modules/**": true,
        "**/tmp/**": true
    }
}
EOL
    log "Created minimal VSCode settings"
}

# Function to install systemd service
install_service() {
    local service_file="/etc/systemd/system/$SERVICE_NAME.service"
    
    # Create service file
    sudo tee "$service_file" > /dev/null << EOL
[Unit]
Description=VSCode Session Manager
After=network.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/session-monitor.sh
Restart=always
User=$USER

[Install]
WantedBy=multi-user.target
EOL

    # Create monitor script
    cat > "$INSTALL_DIR/session-monitor.sh" << EOL
#!/bin/bash
while true; do
    $INSTALL_DIR/vscode-minimal-manager.sh --cleanup
    sleep 60
done
EOL

    chmod +x "$INSTALL_DIR/session-monitor.sh"
    
    # Enable and start service
    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME"
    sudo systemctl start "$SERVICE_NAME"
    
    log "Installed and started VSCode session manager service"
}

# Function to handle connection events
handle_connection() {
    cleanup_stale_sessions
    log "Prepared environment for new VSCode connection"
}

# Function to handle disconnection events
handle_disconnection() {
    cleanup_stale_sessions
    log "Cleaned up after VSCode disconnection"
}

# Main script logic
case "$1" in
    --install)
        log "Starting installation..."
        create_minimal_settings
        install_service
        handle_connection
        log "Installation complete"
        ;;
    --cleanup)
        cleanup_stale_sessions
        ;;
    --connect)
        handle_connection
        ;;
    --disconnect)
        handle_disconnection
        ;;
    *)
        echo "Usage: $0 {--install|--cleanup|--connect|--disconnect}"
        exit 1
        ;;
esac

exit 0
