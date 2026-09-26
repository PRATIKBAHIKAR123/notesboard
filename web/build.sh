#!/bin/bash
set -e

echo "=== Notesboard Vercel Build Script Starting ==="

# 1. Resolve repository root (where pubspec.yaml is)
if [ -f "pubspec.yaml" ]; then
    ROOT_DIR="$(pwd)"
elif [ -f "../pubspec.yaml" ]; then
    ROOT_DIR="$(cd .. && pwd)"
elif [ -f "../../pubspec.yaml" ]; then
    ROOT_DIR="$(cd ../.. && pwd)"
else
    FOUND=$(find . -maxdepth 3 -name "pubspec.yaml" 2>/dev/null | head -n 1)
    if [ -n "$FOUND" ]; then
        ROOT_DIR="$(cd "$(dirname "$FOUND")" && pwd)"
    else
        ROOT_DIR="$(pwd)"
    fi
fi

cd "$ROOT_DIR"
echo "Root directory: $(pwd)"

# 2. Check or install Flutter SDK
if ! command -v flutter &> /dev/null
then
    if [ -d "_flutter/bin" ]; then
        echo "Found cached Flutter SDK in _flutter/bin"
        export PATH="$PATH:$(pwd)/_flutter/bin"
    else
        echo "Flutter not found. Installing Flutter stable SDK..."
        git clone https://github.com/flutter/flutter.git --depth 1 -b stable _flutter
        export PATH="$PATH:$(pwd)/_flutter/bin"
    fi
fi

echo "Flutter version:"
flutter --version

echo "Configuring Flutter..."
flutter config --no-analytics

echo "Getting dependencies..."
flutter pub get

echo "Building Flutter Web (release)..."
flutter build web --release --base-href /

# 3. Copy vercel.json configuration to build/web
if [ -f "vercel.json" ]; then
    cp vercel.json build/web/vercel.json 2>/dev/null || true
fi

# 4. If Vercel was configured with Root Directory as 'web', ensure output is also in web/build/web
mkdir -p web/build 2>/dev/null || true
cp -r build/web web/build/ 2>/dev/null || true

echo "=== Build Complete! Output verified in build/web ==="
ls -la build/web
