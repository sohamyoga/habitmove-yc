#!/usr/bin/env bash
# =============================================================================
# HabitMove — Android Build Script
# Builds a debug APK for testing and a release AAB for Play Store distribution
# =============================================================================

set -e  # Exit on any error

APP_NAME="habitmove"
OUTPUT_DIR="build/outputs"
KEYSTORE_PATH="android/app/habitmove-release.keystore"

# ── Colours ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${GREEN}▶ $1${NC}"; }
warn()    { echo -e "${YELLOW}⚠ $1${NC}"; }
error()   { echo -e "${RED}✗ $1${NC}"; exit 1; }
success() { echo -e "${GREEN}✓ $1${NC}"; }

# ── Preflight checks ─────────────────────────────────────────────────────────
info "Checking prerequisites…"
command -v flutter >/dev/null 2>&1 || error "Flutter not found. Install from https://flutter.dev"
command -v java    >/dev/null 2>&1 || error "Java not found. Install JDK 17+"

FLUTTER_VERSION=$(flutter --version | head -1)
info "Using: $FLUTTER_VERSION"

# ── Clean + dependencies ─────────────────────────────────────────────────────
info "Cleaning previous build artifacts…"
flutter clean

info "Getting dependencies…"
flutter pub get

# ── Font asset check ─────────────────────────────────────────────────────────
if [ ! -f "assets/fonts/DMSans-Regular.ttf" ]; then
  warn "Font files missing in assets/fonts/ — build may fail."
  warn "Download from https://fonts.google.com/specimen/DM+Sans"
  warn "Required: DMSans-Regular.ttf, DMSans-Medium.ttf, DMSans-SemiBold.ttf"
  warn "          DMSerifDisplay-Regular.ttf, DMSerifDisplay-Italic.ttf"
  echo ""
  read -p "Continue anyway? (y/N): " CONTINUE
  [[ "$CONTINUE" =~ ^[Yy]$ ]] || exit 0
fi

# ── Create output dir ─────────────────────────────────────────────────────────
mkdir -p "$OUTPUT_DIR"

# ═════════════════════════════════════════════════════════════════════════════
# 1. DEBUG APK  — for device testing (no signing required)
# ═════════════════════════════════════════════════════════════════════════════
info "Building debug APK…"
flutter build apk --debug --target-platform android-arm64

DEBUG_APK="build/app/outputs/flutter-apk/app-debug.apk"
if [ -f "$DEBUG_APK" ]; then
  cp "$DEBUG_APK" "$OUTPUT_DIR/${APP_NAME}-debug.apk"
  APK_SIZE=$(du -sh "$OUTPUT_DIR/${APP_NAME}-debug.apk" | cut -f1)
  success "Debug APK → $OUTPUT_DIR/${APP_NAME}-debug.apk ($APK_SIZE)"
else
  error "Debug APK not found at expected path."
fi

# ═════════════════════════════════════════════════════════════════════════════
# 2. RELEASE AAB  — for Play Store distribution (requires keystore)
# ═════════════════════════════════════════════════════════════════════════════
info "Checking release keystore…"

if [ ! -f "$KEYSTORE_PATH" ]; then
  warn "No keystore found at $KEYSTORE_PATH"
  warn "Generating a new keystore for you…"
  echo ""

  read -p "  Key alias (e.g. habitmove):          " KEY_ALIAS
  read -p "  Your name or organisation:           " KEY_NAME
  read -p "  City:                                " KEY_CITY
  read -p "  Country code (e.g. GB):              " KEY_COUNTRY
  read -s -p "  Keystore password (min 6 chars):     " KS_PASS; echo ""
  read -s -p "  Key password (press Enter = same):   " KEY_PASS; echo ""
  KEY_PASS="${KEY_PASS:-$KS_PASS}"

  keytool -genkey -v \
    -keystore "$KEYSTORE_PATH" \
    -alias "$KEY_ALIAS" \
    -keyalg RSA -keysize 2048 \
    -validity 10000 \
    -storepass "$KS_PASS" \
    -keypass  "$KEY_PASS" \
    -dname "CN=$KEY_NAME, L=$KEY_CITY, C=$KEY_COUNTRY"

  success "Keystore created at $KEYSTORE_PATH"

  # Write key.properties so Gradle can find it
  cat > android/key.properties <<EOF
storeFile=habitmove-release.keystore
storePassword=$KS_PASS
keyAlias=$KEY_ALIAS
keyPassword=$KEY_PASS
EOF
  success "android/key.properties written"
else
  info "Keystore found at $KEYSTORE_PATH"
  if [ ! -f "android/key.properties" ]; then
    warn "android/key.properties missing — Gradle can't sign the release build."
    warn "Create it manually (see README) or re-run this script without a keystore."
    exit 1
  fi
fi

info "Building release AAB (this takes a few minutes)…"
flutter build appbundle --release

AAB="build/app/outputs/bundle/release/app-release.aab"
if [ -f "$AAB" ]; then
  cp "$AAB" "$OUTPUT_DIR/${APP_NAME}-release.aab"
  AAB_SIZE=$(du -sh "$OUTPUT_DIR/${APP_NAME}-release.aab" | cut -f1)
  success "Release AAB → $OUTPUT_DIR/${APP_NAME}-release.aab ($AAB_SIZE)"
else
  error "AAB not found at expected path."
fi

# ═════════════════════════════════════════════════════════════════════════════
# 3. RELEASE APK  — universal release APK (optional, for sideloading)
# ═════════════════════════════════════════════════════════════════════════════
read -p "Also build a release APK for sideloading? (y/N): " BUILD_RELEASE_APK
if [[ "$BUILD_RELEASE_APK" =~ ^[Yy]$ ]]; then
  info "Building release APK…"
  flutter build apk --release --split-per-abi
  for ABI in arm64-v8a armeabi-v7a x86_64; do
    SRC="build/app/outputs/flutter-apk/app-${ABI}-release.apk"
    if [ -f "$SRC" ]; then
      DEST="$OUTPUT_DIR/${APP_NAME}-${ABI}-release.apk"
      cp "$SRC" "$DEST"
      SIZE=$(du -sh "$DEST" | cut -f1)
      success "Release APK ($ABI) → $DEST ($SIZE)"
    fi
  done
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Build complete! Output files:"
echo "═══════════════════════════════════════════════════════"
ls -lh "$OUTPUT_DIR"/
echo ""
echo "  ▶ Install debug APK on device:"
echo "    adb install $OUTPUT_DIR/${APP_NAME}-debug.apk"
echo ""
echo "  ▶ Upload release AAB to Play Store:"
echo "    https://play.google.com/console"
echo "═══════════════════════════════════════════════════════"
