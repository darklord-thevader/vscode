#!/bin/bash
# Resume a suspended VSCode session

INSTALL_DIR="$HOME/.vscode-minimal"
SESSION_DIR="$INSTALL_DIR/sessions"

if [ -z "$1" ]; then
    echo "Usage: $0 <session-id>"
    echo "Available sessions:"
    for session in "$SESSION_DIR"/*.session; do
        if [ -f "$session" ]; then
            source "$session"
            echo "$(basename "$session" .session): Started: $START_TIME"
        fi
    done
    exit 1
fi

$INSTALL_DIR/vscode-minimal-manager.sh --resume "$1"
