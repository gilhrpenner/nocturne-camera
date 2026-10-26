#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
xcrun swiftc -swift-version 5 -target arm64-apple-macos14.0 \
  App/SceneState.swift App/HeadTreatment.swift App/Fog.swift App/Storm.swift App/VampireCostume.swift App/VampireMakeup.swift App/FangGeometry.swift App/FangPainter.swift App/SceneRenderer.swift Shared/VideoFormat.swift Tests/RendererTests.swift \
  -o build/RendererTests
./build/RendererTests
bash scripts/test-fangs.sh
xcrun swiftc -swift-version 5 App/Storm.swift App/VampireCostume.swift App/VampireMakeup.swift Tests/StageEffectsTests.swift -o build/StageEffectsTests
./build/StageEffectsTests
xcrun swiftc -swift-version 5 App/HeadTreatment.swift Tests/HeadTreatmentTests.swift -o build/HeadTreatmentTests
./build/HeadTreatmentTests
xcrun swiftc -swift-version 5 App/Fog.swift Tests/FogTests.swift -o build/FogTests
./build/FogTests
