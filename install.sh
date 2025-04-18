#!/bin/bash
set -e

# == Settings ==
USER_HOME="$HOME"
VENV_DIR="$USER_HOME/mocap-env"
PROJECT_DIR="$USER_HOME/mocap-input"
SERVICE_NAME="mocap-input.service"
TOGGLE_SCRIPT="$USER_HOME/.local/bin/mocap-toggle.sh"

# == Installation ==
install_all() {
  echo "📦 Updating system..."
  sudo pacman -Syu --noconfirm

  echo "📥 Installing dependencies..."
  sudo pacman -S --needed --noconfirm     python python-pip opencv python-opencv ffmpeg cmake     base-devel git qt5-base xdotool     extra-cmake-modules plasma-sdk kde-cli-tools     cuda cudnn google-glog openblas protobuf boost eigen

  echo "🐍 Creating virtual environment..."
  python -m venv "$VENV_DIR"
  source "$VENV_DIR/bin/activate"
  pip install --upgrade pip
  pip install mediapipe opencv-python pynput PyQt5 matplotlib

  echo "🧠 Cloning OpenPose..."
  cd "$USER_HOME"
  git clone https://github.com/CMU-Perceptual-Computing-Lab/openpose.git || true
  cd openpose && mkdir -p build && cd build

  cmake .. -DCMAKE_BUILD_TYPE=Release            -DBUILD_PYTHON=ON            -DBUILD_EXAMPLES=OFF            -DCUDA_ARCH_BIN="89"            -DUSE_CUDNN=ON            -DBUILD_SHARED_LIBS=ON

  make -j$(nproc)

  echo "📁 Creating project directory..."
  mkdir -p "$PROJECT_DIR"

  echo "📜 Writing mocap_keymap.py..."
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

  echo "📜 Writing mocap_mapper_gui.py..."
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

  echo "📜 Creating empty mapping config..."
  echo "[]" > "$PROJECT_DIR/pose_mappings.json"

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

  echo "🖱️ Creating KDE toggle script..."
  mkdir -p "$USER_HOME/.local/bin"
  cat << EOF > "$TOGGLE_SCRIPT"
#!/bin/bash
SERVICE="$SERVICE_NAME"
STATUS=\$(systemctl --user is-active \$SERVICE)

if [ "\$STATUS" = "active" ]; then
  systemctl --user stop \$SERVICE
  notify-send "🛑 Mocap Input Disabled"
else
  systemctl --user start \$SERVICE
  notify-send "✅ Mocap Input Enabled"
fi
EOF

  chmod +x "$TOGGLE_SCRIPT"

  echo "🔄 Reloading systemd daemon..."
  loginctl enable-linger "$USER"
  systemctl --user daemon-reexec
  systemctl --user daemon-reload

  echo "✅ Installation complete!"
  echo "Run GUI: python $PROJECT_DIR/mocap_mapper_gui.py"
  echo "Toggle via: $TOGGLE_SCRIPT"
}

# == Uninstallation ==
uninstall_all() {
  echo "🗑️ Removing virtual environment..."
  rm -rf "$VENV_DIR"

  echo "🗑️ Removing project files..."
  rm -rf "$PROJECT_DIR"

  echo "🗑️ Removing toggle script..."
  rm -f "$TOGGLE_SCRIPT"

  echo "🗑️ Disabling and removing systemd service..."
  systemctl --user stop "$SERVICE_NAME" || true
  systemctl --user disable "$SERVICE_NAME" || true
  sudo rm -f "/etc/systemd/system/$SERVICE_NAME"
  systemctl --user daemon-reload

  echo "🧹 Optionally remove OpenPose (not deleting automatically)..."
  echo "Run: rm -rf \$HOME/openpose"

  echo "✅ Uninstall complete."
}

# == Main ==
if [[ "$1" == "uninstall" ]]; then
  uninstall_all
else
  install_all
fi
