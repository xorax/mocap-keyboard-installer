#!/bin/bash
set -e

USER_HOME="$HOME"
PROJECT_DIR="$USER_HOME/mocap-input"

echo "📂 Creating project directory..."
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
