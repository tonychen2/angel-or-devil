#!/bin/bash
set -e

# Install OpenJDK
sudo apt-get update && sudo apt-get install -y openjdk-17-jdk unzip wget

# Set JAVA_HOME
export JAVA_HOME="$(dirname $(dirname $(readlink -f $(which javac))))"

# Download Android SDK command-line tools
ANDROID_SDK_ROOT="$HOME/Android/Sdk"
mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"
cd "$ANDROID_SDK_ROOT/cmdline-tools"
wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O cmdline-tools.zip
unzip -q cmdline-tools.zip
rm cmdline-tools.zip
mv cmdline-tools latest

# Set environment variables
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$PATH"

# Install platform-tools and build-tools
yes | "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" "platform-tools" "platforms;android-34" "build-tools;34.0.0"

# Accept licenses
yes | "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" --licenses

echo "Android SDK and toolchain setup complete."
