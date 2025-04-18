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

# == Dependency Checks ==
check_dependency() {
  if ! command -v $1 &> /dev/null; then
    log_info "$1 is not installed. Installing..."
    sudo pacman -S --needed --noconfirm $2
  fi
}

install_dependencies() {
  log_info "Checking and installing dependencies..."
  check_dependency python python
  check_dependency pip python-pip
  check_dependency ffmpeg ffmpeg
  check_dependency cmake cmake
  check_dependency git git
  check_dependency qt5-base qt5-base
  check_dependency xdotool xdotool
  check_dependency extra-cmake-modules extra-cmake-modules
  check_dependency plasma-sdk plasma-sdk
  check_dependency kde-cli-tools kde-cli-tools
  check_dependency cuda cuda
  check_dependency cudnn cudnn
  check_dependency google-glog google-glog
  check_dependency openblas openblas
  check_dependency protobuf protobuf
  check_dependency boost boost
  check_dependency eigen eigen

  # Install specific version of Protobuf
  log_info "Installing specific version of Protobuf..."
  mkdir -p "$CACHE_DIR"
  wget -P "$CACHE_DIR" https://github.com/protocolbuffers/protobuf/releases/download/v30.1.0/protobuf-cpp-30.1.0.tar.gz
  tar -xzf "$CACHE_DIR/protobuf-cpp-30.1.0.tar.gz" -C "$CACHE_DIR"
  cd "$CACHE_DIR/protobuf-30.1.0"
  ./configure
  make
  sudo make install
  sudo ldconfig
  cd ..
}

# == Virtual Environment Management ==
activate_venv() {
  if [[ -d "$VENV_DIR" ]]; then
    source "$VENV_DIR/bin/activate"
  else
    log_info "Creating virtual environment..."
    python -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
  fi
}

# == Configuration File Management ==
backup_config() {
  if [[ -f "$PROJECT_DIR/pose_mappings.json" ]]; then
    cp "$PROJECT_DIR/pose_mappings.json" "$PROJECT_DIR/pose_mappings.json.bak"
    log_info "Backup of pose_mappings.json created."
  fi
}

restore_config() {
  if [[ -f "$PROJECT_DIR/pose_mappings.json.bak" ]]; then
    cp "$PROJECT_DIR/pose_mappings.json.bak" "$PROJECT_DIR/pose_mappings.json"
    log_info "pose_mappings.json restored from backup."
  fi
}

# == Service Management ==
create_service() {
  if systemctl --user is-enabled "$SERVICE_NAME" &> /dev/null; then
    log_info "Systemd service $SERVICE_NAME already exists. Skipping creation."
  else
    log_info "Creating systemd service..."
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
    log_info "Service $SERVICE_NAME created and started."
  fi
}

# == Main Installation Function ==
install_all() {
  log_info "📦 Updating system..."
  sudo pacman -Syu --noconfirm

  install_dependencies

  activate_venv
  pip install --upgrade pip
  pip install mediapipe opencv-python pynput PyQt5 matplotlib

  log_info "🧠 Cloning OpenPose..."
  mkdir -p "$CACHE_DIR"
  git clone https://github.com/CMU-Perceptual-Computing-Lab/openpose.git "$CACHE_DIR/openpose" || true
  cd "$CACHE_DIR/openpose" && mkdir -p build && cd build

  log_info "🛠️  Configuring OpenPose build..."
  cmake .. -DCMAKE_BUILD_TYPE=Release \
           -DBUILD_PYTHON=ON \
           -DBUILD_EXAMPLES=OFF \
           -DCUDA_ARCH_BIN="89" \
           -DUSE_CUDNN=ON \
           -DBUILD_SHARED_LIBS=ON \
           -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
           -DCMAKE_CXX_COMPILER=g++ \
           -DCMAKE_C_COMPILER=gcc

  log_info "🛠️  Building OpenPose..."
  make -j$(nproc)

  log_info "📁 Creating project directory..."
  mkdir -p "$PROJECT_DIR"

  log_info "📜 Writing mocap_keymap.py..."
  cat << EOF > "$PROJECT_DIR/mocap_keymap.py"
import json
import time
import cv2
import mediapipe as mp
from pynput.keyboard import Controller

keyboard = Controller()
mp_pose = mp.solutions.pose
pose = mp_pose.Pose()
cap = cv2.VideoCapture(0)

with open(f"{PROJECT_DIR}/pose_mappings.json", "r") as f:
    mappings = json.load(f)

def check_condition(landmarks, condition):
    try:
        a = landmarks[condition["point_a"]]
        b = landmarks[condition["point_b"]]
        if condition["axis"] == "y":
            return a.y < b.y if condition["operator"] == "lt" else a.y > b.y
        if condition["axis"] == "x":
            return a.x < b.x if condition["operator"] == "lt" else a.x > b.x
    except:
        return False

while True:
    success, frame = cap.read()
    if not success:
        continue

    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    results = pose.process(rgb)

    if results.pose_landmarks:
        lm = results.pose_landmarks.landmark
        for map_entry in mappings:
            if check_condition(lm, map_entry["condition"]):
                key = map_entry["key"]
                keyboard.press(key)
                keyboard.release(key)

    cv2.imshow("Mocap Input", frame)
    if cv2.waitKey(1) & 0xFF == 27:
        break

cap.release()
cv2.destroyAllWindows()
EOF

  log_info "📜 Writing mocap_mapper_gui.py..."
  cat << EOF > "$PROJECT_DIR/mocap_mapper_gui.py"
import json
import sys
from PyQt5.QtWidgets import QApplication, QWidget, QLabel, QPushButton, QVBoxLayout, QComboBox, QLineEdit

MAPPING_PATH = f"{PROJECT_DIR}/pose_mappings.json"

class Mapper(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Mocap Key Mapper")

        self.dropdown_a = QComboBox()
        self.dropdown_b = QComboBox()
        self.axis = QComboBox()
        self.operator = QComboBox()
        self.key_input = QLineEdit()
        self.save_button = QPushButton("Add Mapping")

        self.dropdown_a.addItems(["RIGHT_WRIST", "LEFT_WRIST", "RIGHT_SHOULDER", "LEFT_SHOULDER"])
        self.dropdown_b.addItems(["RIGHT_WRIST", "LEFT_WRIST", "RIGHT_SHOULDER", "LEFT_SHOULDER"])
        self.axis.addItems(["x", "y"])
        self.operator.addItems(["lt", "gt"])

        layout = QVBoxLayout()
        layout.addWidget(QLabel("Compare:"))
        layout.addWidget(self.dropdown_a)
        layout.addWidget(QLabel("with"))
        layout.addWidget(self.dropdown_b)
        layout.addWidget(QLabel("Axis:"))
        layout.addWidget(self.axis)
        layout.addWidget(QLabel("Operator (lt/gt):"))
        layout.addWidget(self.operator)
        layout.addWidget(QLabel("Key to press:"))
        layout.addWidget(self.key_input)
        layout.addWidget(self.save_button)

        self.setLayout(layout)
        self.save_button.clicked.connect(self.save_mapping)

    def save_mapping(self):
        new_entry = {
            "condition": {
                "point_a": self.dropdown_a.currentText(),
                "point_b": self.dropdown_b.currentText(),
                "axis": self.axis.currentText(),
                "operator": self.operator.currentText()
            },
            "key": self.key_input.text()
        }
        try:
            with open(MAPPING_PATH, "r") as f:
                data = json.load(f)
        except:
            data = []
        data.append(new_entry)
        with open(MAPPING_PATH, "w") as f:
            json.dump(data, f, indent=2)
        self.key_input.clear()

app = QApplication(sys.argv)
window = Mapper()
window.show()
sys.exit(app.exec_())
EOF

  log_info "📜 Creating empty mapping config..."
  echo "[]" > "$PROJECT_DIR/pose_mappings.json"

  create_service

  log_info " Semiconductor toggle script..."
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

  log_info " Reloading systemd daemon..."
  loginctl enable-linger "$USER"
  systemctl --user daemon-reexec
  systemctl --user daemon-reload

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

  log_info "Removing virtual environment..."
  rm -rf "$VENV_DIR"

  log_info "Removing project files..."
  rm -rf "$PROJECT_DIR"

  log_info "Removing toggle script..."
  rm -f "$TOGGLE_SCRIPT"

  log_info "Disabling and removing systemd service..."
  systemctl --user stop "$SERVICE_NAME" || true
  systemctl --user disable "$SERVICE_NAME" || true
  sudo rm -f "/etc/systemd/system/$SERVICE_NAME"
  systemctl --user daemon-reload

  log_info "Optionally remove OpenPose (not deleting automatically)..."
  log_info "Run: rm -rf \$HOME/openpose"

  log_info "Uninstall complete."
}

# == Main ==
if [[ "$1" == "uninstall" ]]; then
  uninstall_all
else
  install_all
fi
