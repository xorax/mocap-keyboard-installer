#!/bin/bash
set -e

USER_HOME="$HOME"
VENV_DIR="$USER_HOME/mocap-env"
PROJECT_DIR="$USER_HOME/mocap-input"
SERVICE_NAME="mocap-input.service"
TOGGLE_SCRIPT="$USER_HOME/.local/bin/mocap-toggle.sh"

uninstall_all() {
  echo "🔧 Removing virtual environment..."
  rm -rf "$VENV_DIR"

  echo "🔧 Removing project files..."
  rm -rf "$PROJECT_DIR"

  echo "🔧 Removing toggle script..."
  rm -f "$TOGGLE_SCRIPT"

  echo "🔧 Disabling and removing systemd service..."
  systemctl --user stop "$SERVICE_NAME" || true
  systemctl --user disable "$SERVICE_NAME" || true
  sudo rm -f "/etc/systemd/system/$SERVICE_NAME"
  systemctl --user daemon-reload

  echo "🔧 Optionally remove OpenPose (not deleting automatically)..."
  echo "Run: rm -rf \$HOME/openpose"

  echo "🔧 Uninstall complete."
}

uninstall_all
