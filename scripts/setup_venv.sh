#!/bin/bash
set -e

USER_HOME="$HOME"
VENV_DIR="$USER_HOME/mocap-env"

activate_venv() {
  if [[ -d "$VENV_DIR" ]]; then
    source "$VENV_DIR/bin/activate"
  else
    echo "🐍 Creating virtual environment..."
    python -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
  fi
}

activate_venv
pip install --upgrade pip
pip install mediapipe opencv-python pynput PyQt5 matplotlib
