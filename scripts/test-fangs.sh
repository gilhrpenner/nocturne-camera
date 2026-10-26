#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
xcrun swiftc -swift-version 5 App/FangGeometry.swift App/FangPainter.swift Tests/FangGeometryTests.swift -o build/FangGeometryTests
./build/FangGeometryTests
