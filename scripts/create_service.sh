#!/bin/bash
set -e

USER_HOME="$HOME"
VENV_DIR="$USER_HOME/mocap-env"
PROJECT_DIR="$USER_HOME/mocap-input"
SERVICE_NAME="mocap-input.service"
TOGGLE_SCRIPT="$USER_HOME/.local/bin/mocap-toggle.sh"

create_service() {
  if systemctl --user is-enabled "$SERVICE_NAME" &> /dev/null; then
    echo "⚙️ Systemd service $SERVICE_NAME already exists. Skipping creation."
  else
    echo "⚙️ Creating systemd service..."
    cat << EOF | sudo tee /etc/systemd/system/$SERVICE_NAME
[Unit]
Description=Real-time Mocap Key Mapper
After=graphical.target

[Service]
ExecStart=$VENV_DIR/bin/python $PROJECT_DIR/mocap_keymap.py
Restart=on-failure
Environment=DISPLAY=:0
Environment=XAUTHORITY=$USER_HOME/.Xauthority

[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload
    systemctl --user enable "$SERVICE_NAME"
    systemctl --user start "$SERVICE_NAME"
    echo "⚙️ Service $SERVICE_NAME created and started."
  fi
}

create_service

echo " Semiconductor toggle script..."
mkdir -p "$USER_HOME/.local/bin"
cat << EOF > "$TOGGLE_SCRIPT"
#!/bin/bash
SERVICE="$SERVICE_NAME"
STATUS=\$(systemctl --user is-active \$SERVICE)

if [ "\$STATUS" = "active" ]; then
  systemctl --user stop \$SERVICE
  notify-send " Mocap Input Disabled"
else
  systemctl --user start \$SERVICE
  notify-send "✅ Mocap Input Enabled"
fi
EOF

chmod +x "$TOGGLE_SCRIPT"

echo " Reloading systemd daemon..."
loginctl enable-linger "$USER"
systemctl --user daemon-reexec
systemctl --user daemon-reload
