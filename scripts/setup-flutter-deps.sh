#!/bin/bash
set -e

# Ensure Flutter SDK is installed
if ! command -v flutter &> /dev/null; then
  echo "Flutter SDK not found. Installing..."
  sudo apt-get update && sudo apt-get install -y curl git unzip xz-utils
  git clone https://github.com/flutter/flutter.git -b stable $HOME/flutter
  export PATH="$HOME/flutter/bin:$PATH"
  echo 'export PATH="$HOME/flutter/bin:[36m$PATH"' >> ~/.bashrc
  flutter --version
else
  echo "Flutter SDK found: $(flutter --version | head -n 1)"
fi

# Run pub get to install dependencies
cd /workspaces/angel-or-devil
flutter pub get

echo "Flutter/Dart dependencies installed."
