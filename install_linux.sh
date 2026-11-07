#!/bin/bash
#
# Installs the built Linux bundle into ~/.local (no sudo required).
#
#   ./install_linux.sh
#
# Creates:
#   ~/.local/share/finoteku/                  app bundle (binary + lib + data)
#   ~/.local/bin/finoteku                     symlink launcher
#   ~/.local/share/applications/finoteku.desktop
#   ~/.local/share/icons/hicolor/<size>/apps/finoteku.png

set -euo pipefail

BUNDLE="build/linux/x64/release/bundle"
APP_ID="id.ridhoarmand.finoteku"
APP_NAME="finoteku"
DISPLAY_NAME="Finoteku"
ICON_SOURCE="assets/icon_apps.png"

PREFIX="${HOME}/.local"
APP_DIR="${PREFIX}/share/finoteku"
BIN_DIR="${PREFIX}/bin"
BIN_LINK="${BIN_DIR}/${APP_NAME}"
DESKTOP_DIR="${PREFIX}/share/applications"
DESKTOP_FILE="${DESKTOP_DIR}/${APP_NAME}.desktop"
ICON_DIR="${PREFIX}/share/icons/hicolor"
ICON_SIZES=(16 24 32 48 64 128 256 512)

fail() {
    echo "❌ $1" >&2
    exit 1
}

# --- Preflight ---------------------------------------------------------------

[ -f .env ] || fail ".env file not found! Copy .env.example to .env first."

[ -x "${BUNDLE}/${APP_NAME}" ] || fail "Linux bundle not found at ${BUNDLE}/${APP_NAME}
💡 Build it first:  ./release.sh --linux"

command -v desktop-file-validate >/dev/null 2>&1 || fail "desktop-file-validate not found (package: desktop-file-utils)"

# --- Install bundle ----------------------------------------------------------

echo "📦 Installing bundle to ${APP_DIR} ..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}"
cp -a "${BUNDLE}/." "${APP_DIR}/"

# --- Launcher symlink --------------------------------------------------------

echo "🔗 Creating launcher at ${BIN_LINK} ..."
mkdir -p "${BIN_DIR}"
ln -sfn "${APP_DIR}/${APP_NAME}" "${BIN_LINK}"

# --- Desktop entry -----------------------------------------------------------

echo "🖥  Writing ${DESKTOP_FILE} ..."
mkdir -p "${DESKTOP_DIR}"
cat > "${DESKTOP_FILE}" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=${DISPLAY_NAME}
GenericName=Personal Finance
Comment=Aplikasi pencatatan keuangan pribadi
Exec=${APP_DIR}/${APP_NAME}
Icon=${APP_NAME}
Terminal=false
Categories=Office;Finance;GTK;
Keywords=finance;money;budget;expense;income;keuangan;uang;
StartupNotify=true
StartupWMClass=${APP_ID}
EOF

desktop-file-validate "${DESKTOP_FILE}" \
    || fail "Generated .desktop file failed validation"

# --- Icons -------------------------------------------------------------------

if command -v magick >/dev/null 2>&1 || command -v convert >/dev/null 2>&1; then
    CONVERT="$(command -v magick || command -v convert)"
    echo "🖼  Generating icons from ${ICON_SOURCE} ..."
    for size in "${ICON_SIZES[@]}"; do
        dest="${ICON_DIR}/${size}x${size}/apps"
        mkdir -p "${dest}"
        "${CONVERT}" "${ICON_SOURCE}" -resize "${size}x${size}" "${dest}/${APP_NAME}.png"
    done
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -f -t "${ICON_DIR}" 2>/dev/null || true
    fi
else
    echo "⚠️  ImageMagick not found - skipping icon generation (desktop entry will use a generic icon)."
fi

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${DESKTOP_DIR}" 2>/dev/null || true
fi

# --- Report ------------------------------------------------------------------

echo ""
echo "✅ ${DISPLAY_NAME} installed successfully!"
echo ""
echo "   App:      ${APP_DIR}/${APP_NAME}"
echo "   Launcher: ${BIN_LINK}"
echo "   Menu:     ${DESKTOP_FILE}"
echo ""
case ":${PATH}:" in
    *":${BIN_DIR}:"*)
        echo "▶ Run from terminal:  ${APP_NAME}"
        ;;
    *)
        echo "▶ Run from terminal:  ${BIN_LINK}"
        echo "   (${BIN_DIR} is not in your PATH - add it to run '${APP_NAME}' directly)"
        ;;
esac
echo "▶ Or launch it from your application menu / launcher (e.g. rofi, wofi, fuzzel)."
