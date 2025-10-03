#!/bin/bash

echo "🚀 Building optimized Flutter app in release mode..."

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

# Build release APK with size optimization
echo "🔨 Building optimized release APK..."
if [ "$NO_TREE_SHAKE" = true ]; then
    flutter build apk --release --no-tree-shake-icons --shrink --split-per-abi --obfuscate --split-debug-info=build/debug-info
else
    flutter build apk --release --shrink --split-per-abi --obfuscate --split-debug-info=build/debug-info
fi

# Check if build was successful
if [ $? -eq 0 ]; then
    echo "✅ Optimized release build completed successfully!"
    echo "📱 Main APK: build/app/outputs/flutter-apk/app-release.apk"
    echo "📱 Split APKs: build/app/outputs/flutter-apk/app-*-release.apk"
    echo "📊 Debug info: build/debug-info/"
    
    # Show APK sizes
    echo ""
    echo "📏 APK sizes:"
    ls -lh build/app/outputs/flutter-apk/app-*-release.apk 2>/dev/null || ls -lh build/app/outputs/flutter-apk/app-release.apk
    echo ""
    echo "🎉 You can now distribute your optimized APKs!"
else
    echo "❌ Release build failed!"
    echo "💡 If you see tree-shake icon errors, try:"
    echo "   ./build_release.sh --no-tree-shake-icons"
    echo "💡 For debugging obfuscation issues, check build/debug-info/"
    exit 1
fi