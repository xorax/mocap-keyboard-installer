#!/bin/bash
set -e

# == Settings ==
USER_HOME="$HOME"
CACHE_DIR="$USER_HOME/.cache/mocap-install"
VENV_DIR="$USER_HOME/mocap-env"
PROJECT_DIR="$USER_HOME/mocap-input"
SERVICE_NAME="mocap-input.service"
TOGGLE_SCRIPT="$USER_HOME/.local/bin/mocap-toggle.sh"

# == Logging Functions ==
log_error() {
  echo "❌ Error: $1" >&2
}

log_info() {
  echo "ℹ️  $1"
}

# == Main Installation Function ==
install_all() {
  log_info "📦 Updating system..."
  sudo pacman -Syu --noconfirm

  log_info "🔍 Checking and installing dependencies..."
  ./scripts/install_dependencies.sh

  log_info "🐍 Setting up virtual environment..."
  ./scripts/setup_venv.sh

  log_info "🤖 Cloning and building OpenPose..."
  ./scripts/build_openpose.sh

  log_info "📂 Setting up project directory..."
  ./scripts/setup_project.sh

  log_info "⚙️ Creating systemd service..."
  ./scripts/create_service.sh

  log_info "✅ Installation complete!"
  log_info "Run GUI: python $PROJECT_DIR/mocap_mapper_gui.py"
  log_info "Toggle via: $TOGGLE_SCRIPT"
}

# == Main Uninstallation Function ==
uninstall_all() {
  read -p "Are you sure you want to uninstall? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Uninstall aborted."
    exit 0
  fi

  log_info "🔧 Running uninstallation script..."
  ./scripts/uninstall.sh
}

# == Main ==
if [[ "$1" == "uninstall" ]]; then
  uninstall_all
else
  install_all
fi
