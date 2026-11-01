#!/bin/bash
# Compila "Karaoke Maker.app" (richiede macOS 13+ e Xcode o i Command Line Tools).
set -euo pipefail
cd "$(dirname "$0")"

APP="dist/Karaoke Maker.app"
rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

if swift build -c release --arch arm64 --arch x86_64 2>/dev/null; then
  BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/KaraokeMaker"
  echo "Compilato binario universale (Apple Silicon + Intel)"
else
  swift build -c release
  BIN="$(swift build -c release --show-bin-path)/KaraokeMaker"
fi

cp "$BIN" "$APP/Contents/MacOS/KaraokeMaker"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# firma ad-hoc (sufficiente per l'uso locale)
codesign --force --deep --sign - "$APP"

(cd dist && ditto -c -k --sequesterRsrc --keepParent "Karaoke Maker.app" "KaraokeMaker-mac.zip")
echo "Fatto: $APP e dist/KaraokeMaker-mac.zip"
