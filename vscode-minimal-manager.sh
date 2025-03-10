#!/bin/bash
# vscode-minimal-manager.sh
# A comprehensive solution for managing VSCode remote SSH sessions

# Configuration
INSTALL_DIR="$HOME/.vscode-minimal"
LOG_FILE="$INSTALL_DIR/vscode-minimal.log"
SETTINGS_FILE="$INSTALL_DIR/settings.json"
PROFILES_FILE="$INSTALL_DIR/profiles.json"
SESSION_DIR="$INSTALL_DIR/sessions"
SERVICE_NAME="vscode-session-manager"
IDLE_TIMEOUT=3600  # Default idle timeout in seconds (1 hour)

# Create installation directories
mkdir -p "$INSTALL_DIR"
mkdir -p "$SESSION_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to apply resource limits to VSCode processes
apply_resource_limits() {
    log "Applying resource limits to VSCode processes..."
    
    for pid in $(pgrep -f "vscode-server"); do
        # Set CPU priority to low
        renice 10 -p "$pid" 2>/dev/null
        
        # Limit CPU usage using cgroups if available
        if command -v cgcreate &> /dev/null && [ -d "/sys/fs/cgroup/cpu" ]; then
            cgcreate -g cpu:/vscode-limited 2>/dev/null
            echo 50000 > /sys/fs/cgroup/cpu/vscode-limited/cpu.shares 2>/dev/null
            echo "$pid" > /sys/fs/cgroup/cpu/vscode-limited/tasks 2>/dev/null
            log "Applied cgroup CPU limits to process $pid"
        fi
        
        log "Set nice value for VSCode process: $pid"
    done
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

# Function to detect and auto-suspend idle sessions
auto_suspend() {
    log "Checking for idle VSCode sessions..."
    
    for pid in $(pgrep -f "vscode-server"); do
        # Get process start time
        start_time=$(ps -o lstart= -p "$pid")
        start_epoch=$(date -d "$start_time" +%s)
        
        # Get last activity time from file activity
        last_activity=$(find ~/.vscode-server -type f -name "*.log" -newer /proc/$pid -print -quit 2>/dev/null)
        
        # If no activity found, use process start time
        if [ -z "$last_activity" ]; then
            last_activity_epoch=$start_epoch
        else
            last_activity_epoch=$(stat -c %Y "$last_activity")
        fi
        
        # Calculate idle time
        current_epoch=$(date +%s)
        idle_time=$((current_epoch - last_activity_epoch))
        
        # If idle for more than timeout, suspend
        if [ $idle_time -gt $IDLE_TIMEOUT ]; then
            log "Session $pid idle for $idle_time seconds, suspending..."
            
            # Save session state
            session_id=$(date +%Y%m%d%H%M%S)-$pid
            session_file="$SESSION_DIR/$session_id.session"
            
            # Get open files and terminals
            open_files=$(lsof -p "$pid" | grep REG | awk '{print $9}' | grep -v "/lib/" | grep -v "/proc/")
            
            # Save session data
            echo "PID=$pid" > "$session_file"
            echo "START_TIME=$start_time" >> "$session_file"
            echo "OPEN_FILES=$open_files" >> "$session_file"
            
            # Use SIGSTOP to suspend the process instead of killing it
            kill -SIGSTOP "$pid" 2>/dev/null
            log "Session suspended and saved to $session_file"
        fi
    done
}

# Function to resume a suspended session
resume_session() {
    local session_id=$1
    
    if [ -f "$SESSION_DIR/$session_id.session" ]; then
        source "$SESSION_DIR/$session_id.session"
        
        # Resume the process
        if kill -0 "$PID" 2>/dev/null; then
            kill -SIGCONT "$PID" 2>/dev/null
            log "Resumed session $session_id (PID: $PID)"
            return 0
        else
            log "Cannot resume session $session_id, process no longer exists"
            rm "$SESSION_DIR/$session_id.session"
            return 1
        fi
    else
        log "Session $session_id not found"
        return 1
    fi
}

# Function to list available sessions
list_sessions() {
    echo "Available suspended sessions:"
    for session in "$SESSION_DIR"/*.session; do
        if [ -f "$session" ]; then
            source "$session"
            echo "$(basename "$session" .session): Started: $START_TIME"
        fi
    done
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
    },
    "vscode-minimal-manager.idleTimeout": 3600,
    "vscode-minimal-manager.enableAutoSuspend": true,
    "vscode-minimal-manager.enableResourceLimits": true,
    "vscode-minimal-manager.activeProfile": "default"
}
EOL
    log "Created minimal VSCode settings"
    
    # Create profiles configuration
    cat > "$PROFILES_FILE" << EOL
{
    "profiles": {
        "default": {
            "extensions": ["ms-vscode.remote-ssh"],
            "resourceLimits": {
                "cpuPriority": 10,
                "memoryLimit": "1G"
            }
        },
        "python": {
            "extensions": ["ms-vscode.remote-ssh", "ms-python.python"],
            "resourceLimits": {
                "cpuPriority": 5,
                "memoryLimit": "2G"
            }
        },
        "web": {
            "extensions": ["ms-vscode.remote-ssh", "dbaeumer.vscode-eslint", "ritwickdey.liveserver"],
            "resourceLimits": {
                "cpuPriority": 5,
                "memoryLimit": "1.5G"
            }
        }
    }
}
EOL
    log "Created extension profiles configuration"
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
    $INSTALL_DIR/vscode-minimal-manager.sh --resource-limits
    $INSTALL_DIR/vscode-minimal-manager.sh --auto-suspend
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

# Create the resume session script
create_resume_script() {
    cat > "$INSTALL_DIR/resume-session.sh" << EOL
#!/bin/bash
# Resume a suspended VSCode session

INSTALL_DIR="$HOME/.vscode-minimal"
SESSION_DIR="$INSTALL_DIR/sessions"

if [ -z "\$1" ]; then
    echo "Usage: \$0 <session-id>"
    echo "Available sessions:"
    for session in "$SESSION_DIR"/*.session; do
        if [ -f "\$session" ]; then
            source "\$session"
            echo "\$(basename "\$session" .session): Started: \$START_TIME"
        fi
    done
    exit 1
fi

$INSTALL_DIR/vscode-minimal-manager.sh --resume "\$1"
EOL

    chmod +x "$INSTALL_DIR/resume-session.sh"
    log "Created resume session script"
}

# Function to handle connection events
handle_connection() {
    cleanup_stale_sessions
    apply_resource_limits
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
        create_resume_script
        install_service
        handle_connection
        log "Installation complete"
        ;;
    --cleanup)
        cleanup_stale_sessions
        ;;
    --resource-limits)
        apply_resource_limits
        ;;
    --auto-suspend)
        auto_suspend
        ;;
    --resume)
        if [ -z "$2" ]; then
            list_sessions
        else
            resume_session "$2"
        fi
        ;;
    --connect)
        handle_connection
        ;;
    --disconnect)
        handle_disconnection
        ;;
    --list-sessions)
        list_sessions
        ;;
    *)
        echo "Usage: $0 {--install|--cleanup|--resource-limits|--auto-suspend|--resume [session-id]|--connect|--disconnect|--list-sessions}"
        exit 1
        ;;
esac

exit 0
