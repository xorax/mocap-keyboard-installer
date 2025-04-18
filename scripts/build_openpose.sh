#!/bin/bash
set -e

USER_HOME="$HOME"
CACHE_DIR="$USER_HOME/.cache/mocap-install"

echo "🤖 Cloning OpenPose..."
mkdir -p "$CACHE_DIR"
git clone https://github.com/CMU-Perceptual-Computing-Lab/openpose.git "$CACHE_DIR/openpose" || true
cd "$CACHE_DIR/openpose" && mkdir -p build && cd build

echo "🛠️  Configuring OpenPose build..."
cmake .. -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_PYTHON=ON \
        -DBUILD_EXAMPLES=OFF \
        -DCUDA_ARCH_BIN="89" \
        -DUSE_CUDNN=ON \
        -DBUILD_SHARED_LIBS=ON \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5

echo "🛠️  Building OpenPose..."
make -j$(nproc)
