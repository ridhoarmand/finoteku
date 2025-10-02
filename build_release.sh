#!/bin/bash

echo "🚀 Building Flutter app in release mode..."

# Parse command line arguments
NO_TREE_SHAKE=false
if [[ "$1" == "--no-tree-shake-icons" ]]; then
    NO_TREE_SHAKE=true
    echo "🌲 Building WITHOUT icon tree-shaking..."
fi

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build release APK
echo "🔨 Building release APK..."
if [ "$NO_TREE_SHAKE" = true ]; then
    flutter build apk --release --no-tree-shake-icons
else
    flutter build apk --release
fi

# Check if build was successful
if [ $? -eq 0 ]; then
    echo "✅ Release build completed successfully!"
    echo "📱 APK location: build/app/outputs/flutter-apk/app-release.apk"
    
    # Optional: Install on connected device
    read -p "🤔 Install on connected device? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "📲 Installing on device..."
        flutter install --use-application-binary=build/app/outputs/flutter-apk/app-release.apk
    fi
else
    echo "❌ Release build failed!"
    echo "💡 If you see tree-shake icon errors, try:"
    echo "   ./build_release.sh --no-tree-shake-icons"
    exit 1
fi