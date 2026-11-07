#!/bin/bash

echo "🚀 Building optimized Flutter app in release mode..."

# Parse command line arguments
NO_TREE_SHAKE=false
PLATFORM="android"
PLATFORM_EXPLICIT=false
INSTALL=false
for arg in "$@"; do
    case "$arg" in
        --no-tree-shake-icons)
            NO_TREE_SHAKE=true
            echo "🌲 Building WITHOUT icon tree-shaking..."
            ;;
        --android)
            PLATFORM="android"
            PLATFORM_EXPLICIT=true
            ;;
        --linux)
            PLATFORM="linux"
            PLATFORM_EXPLICIT=true
            ;;
        --all)
            PLATFORM="all"
            PLATFORM_EXPLICIT=true
            ;;
        --install)
            INSTALL=true
            echo "📦 Will install the Linux bundle after building..."
            ;;
        *)
            echo "❌ Unknown argument: $arg"
            echo "💡 Usage: $0 [--android|--linux|--all] [--install] [--no-tree-shake-icons]"
            exit 1
            ;;
    esac
done

# --install only applies to the Linux bundle
if [ "$INSTALL" = true ] && [ "$PLATFORM_EXPLICIT" = false ]; then
    PLATFORM="linux"
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

# Build release with size optimization
BUILD_RESULTS=()

build_android() {
    echo "🔨 Building optimized release APK..."
    if [ "$NO_TREE_SHAKE" = true ]; then
        flutter build apk --release --no-tree-shake-icons --shrink --split-per-abi --obfuscate --split-debug-info=build/debug-info --dart-define-from-file=.env
    else
        flutter build apk --release --tree-shake-icons --shrink --split-per-abi --obfuscate --split-debug-info=build/debug-info --dart-define-from-file=.env
    fi
    if [ $? -ne 0 ]; then
        return 1
    fi

    BUILD_RESULTS+=("📱 Main APK: build/app/outputs/flutter-apk/app-release.apk")
    BUILD_RESULTS+=("📱 Split APKs: build/app/outputs/flutter-apk/app-*-release.apk")
    BUILD_RESULTS+=("📊 Debug info: build/debug-info/")

    echo ""
    echo "📏 APK sizes:"
    ls -lh build/app/outputs/flutter-apk/app-*-release.apk 2>/dev/null || ls -lh build/app/outputs/flutter-apk/app-release.apk
    return 0
}

build_linux() {
    echo "🔨 Building optimized Linux bundle..."
    flutter build linux --release --dart-define-from-file=.env
    if [ $? -ne 0 ]; then
        return 1
    fi

    BUILD_RESULTS+=("🐧 Linux bundle: build/linux/x64/release/bundle/")

    echo ""
    echo "📏 Linux bundle size:"
    du -sh build/linux/x64/release/bundle/
    return 0
}

FAILED=false

if [ "$PLATFORM" = "android" ] || [ "$PLATFORM" = "all" ]; then
    build_android || FAILED=true
fi

if [ "$PLATFORM" = "linux" ] || [ "$PLATFORM" = "all" ]; then
    build_linux || FAILED=true
fi

# Check if build was successful
if [ "$FAILED" = false ]; then
    # Mark build as successful so backup is deleted instead of restored
    BUILD_SUCCESS=true

    echo ""
    echo "✅ Optimized release build completed successfully!"
    for line in "${BUILD_RESULTS[@]}"; do
        echo "   $line"
    done
    echo ""

    if [ "$INSTALL" = true ]; then
        ./install_linux.sh || exit 1
    fi

    echo "🎉 You can now distribute your optimized builds!"
else
    echo "❌ Release build failed!"
    echo "💡 If you see tree-shake icon errors, try:"
    echo "   $0 --no-tree-shake-icons"
    echo "💡 If you see CMake errors about missing glib/gtk paths, run:"
    echo "   flutter clean && rm -rf linux/flutter/ephemeral && $0 --linux"
    echo "💡 For debugging obfuscation issues, check build/debug-info/"
    exit 1
fi