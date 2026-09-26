#!/bin/bash
set -e

# If Flutter is not installed in the environment (e.g. Vercel build container), install it
if ! command -v flutter &> /dev/null
then
    echo "Flutter not found. Installing Flutter stable SDK..."
    git clone https://github.com/flutter/flutter.git --depth 1 -b stable _flutter
    export PATH="$PATH:$(pwd)/_flutter/bin"
fi

echo "Flutter version:"
flutter --version

echo "Configuring Flutter..."
flutter config --no-analytics

echo "Getting dependencies..."
flutter pub get

echo "Building Flutter Web (release)..."
flutter build web --release --base-href /

echo "Build complete! Output in build/web"
