#!/bin/bash
set -e

APP_NAME="FinanzasAR"
VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //' | cut -d'+' -f1)
DMG_NAME="${APP_NAME}-${VERSION}-mac.dmg"
RELEASE_DIR="build/macos/Build/Products/Release"
DIST_DIR="dist"

echo "==> Limpiando build anterior..."
flutter clean

echo "==> Instalando dependencias..."
flutter pub get

echo "==> Buildeando ${APP_NAME} ${VERSION} para macOS (release)..."
flutter build macos --release

APP_PATH="${RELEASE_DIR}/${APP_NAME}.app"
if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: No se encontró ${APP_PATH}"
  exit 1
fi

# Firma ad-hoc (necesaria en Apple Silicon, evita algunos avisos de Gatekeeper)
echo "==> Firmando la app (ad-hoc)..."
codesign --force --deep --sign - "$APP_PATH"

mkdir -p "$DIST_DIR"

# Crear DMG con hdiutil (viene incluido en macOS, no requiere instalar nada)
echo "==> Creando DMG..."
TMP_DMG_DIR=$(mktemp -d)
cp -R "$APP_PATH" "$TMP_DMG_DIR/"
ln -s /Applications "$TMP_DMG_DIR/Aplicaciones"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$TMP_DMG_DIR" \
  -ov -format UDZO \
  "${DIST_DIR}/${DMG_NAME}"

rm -rf "$TMP_DMG_DIR"

echo ""
echo "✅ Listo: dist/${DMG_NAME}"
echo ""
echo "Para compartir: enviá el archivo dist/${DMG_NAME}"
echo "Para instalar: abrí el DMG → arrastrá FinanzasAR a Aplicaciones"
echo "Primera vez: click derecho → Abrir (si macOS avisa que no está verificado)"
