#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/generate_project.py
xcodebuild -project Nocturne.xcodeproj -scheme Nocturne -configuration Release \
  -derivedDataPath build/Xcode -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
mkdir -p dist
ditto build/Xcode/Build/Products/Release/Nocturne.app dist/Nocturne.app
codesign --verify --deep --strict dist/Nocturne.app
python3 scripts/check_camera_bundle.py dist/Nocturne.app
ditto -c -k --sequesterRsrc --keepParent dist/Nocturne.app dist/Nocturne-macOS.zip
