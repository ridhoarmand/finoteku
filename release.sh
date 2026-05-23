#!/bin/bash

echo "🚀 Building optimized Flutter app in release mode..."

# Parse command line arguments
NO_TREE_SHAKE=false
if [[ "$1" == "--no-tree-shake-icons" ]]; then
    NO_TREE_SHAKE=true
    echo "🌲 Building WITHOUT icon tree-shaking..."
fi

# Check if .env file exists (required for compile-time environment variables)
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found!"
    echo "💡 Copy .env.example to .env and fill in your credentials first."
    exit 1
fi

# --- VERSION BUMP & ROLLBACK LOGIC ---
BUILD_SUCCESS=false

# Cleanup function to restore original pubspec.yaml if build fails or is canceled
cleanup() {
    if [ "$BUILD_SUCCESS" = false ]; then
        if [ -f pubspec.yaml.bak ]; then
            echo ""
            echo "🔄 Reverting version in pubspec.yaml to original..."
            mv pubspec.yaml.bak pubspec.yaml
        fi
    else
        # Build was successful, clean up backup
        rm -f pubspec.yaml.bak
    fi
}

# Trap script exit (both normal and abnormal) and signals
trap cleanup EXIT INT TERM

# Extract current version
VERSION_LINE=$(grep "^version:" pubspec.yaml)
if [ -z "$VERSION_LINE" ]; then
    echo "❌ Error: Could not find version line in pubspec.yaml"
    exit 1
fi

CURRENT_VERSION=$(echo "$VERSION_LINE" | sed -e 's/version:[[:space:]]*//' -e 's/[[:space:]]*$//')
echo "ℹ️ Current version: $CURRENT_VERSION"

# Split version name and build number
if [[ "$CURRENT_VERSION" == *"+"* ]]; then
    VERSION_NAME="${CURRENT_VERSION%+*}"
    BUILD_NUMBER="${CURRENT_VERSION#*+}"
else
    VERSION_NAME="$CURRENT_VERSION"
    BUILD_NUMBER="0"
fi

# Validate build number is an integer
if ! [[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "⚠️ Warning: Build number '$BUILD_NUMBER' is not an integer. Resetting build number to 1."
    NEW_BUILD_NUMBER=1
else
    NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))
fi

NEW_VERSION="$VERSION_NAME+$NEW_BUILD_NUMBER"
echo "⬆️ Bumping version to: $NEW_VERSION..."

# Backup pubspec.yaml before modifying
cp pubspec.yaml pubspec.yaml.bak

# Update version in pubspec.yaml
sed -i "s/^version:[[:space:]]*.*/version: $NEW_VERSION/" pubspec.yaml
# -------------------------------------

# Clean previous builds
echo "🧹 Cleaning previous builds..."
#flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build release APK with size optimization
echo "🔨 Building optimized release APK..."
if [ "$NO_TREE_SHAKE" = true ]; then
    flutter build apk --release --no-tree-shake-icons --shrink --split-per-abi --obfuscate --split-debug-info=build/debug-info --dart-define-from-file=.env
else
    flutter build apk --release --tree-shake-icons --shrink --split-per-abi --obfuscate --split-debug-info=build/debug-info --dart-define-from-file=.env
fi

# Check if build was successful
if [ $? -eq 0 ]; then
    # Mark build as successful so backup is deleted instead of restored
    BUILD_SUCCESS=true
    
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