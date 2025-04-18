#!/bin/bash
set -e

# == Dependency Checks ==
check_dependency() {
  if ! command -v $1 &> /dev/null; then
    echo "ℹ️  $1 is not installed. Installing..."
    sudo pacman -S --needed --noconfirm $2
  fi
}

install_dependencies() {
  echo "🔍 Checking and installing dependencies..."
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
}

install_dependencies
