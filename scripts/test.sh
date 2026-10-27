#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
xcrun swiftc -swift-version 5 -target arm64-apple-macos14.0 \
  App/HeroArtwork.swift App/HeroCostume.swift App/BatSprite.swift App/DissolveMesh.swift App/BatDissolve.swift App/BatPainter.swift App/HauntedWindows.swift App/StagePerformance.swift App/ActorCompositor.swift App/CostumeStabilizer.swift App/VampireEyes.swift App/PoseAnalyzer.swift App/ActorMasks.swift App/BodyTracker.swift App/CostumeFit.swift App/SceneCanvas.swift App/CinematicScene.swift App/SceneLighting.swift App/SceneWeather.swift App/SceneState.swift App/HeadTreatment.swift App/Fog.swift App/Storm.swift App/VampireMakeup.swift App/FangGeometry.swift App/FangPainter.swift App/SceneRenderer.swift Shared/VideoFormat.swift Tests/RendererTests.swift \
  -o build/RendererTests
./build/RendererTests
bash scripts/test-fangs.sh
xcrun swiftc -swift-version 5 App/Storm.swift App/VampireMakeup.swift Tests/StageEffectsTests.swift -o build/StageEffectsTests
./build/StageEffectsTests
xcrun swiftc -swift-version 5 App/HeadTreatment.swift Tests/HeadTreatmentTests.swift -o build/HeadTreatmentTests
./build/HeadTreatmentTests
xcrun swiftc -swift-version 5 App/Fog.swift Tests/FogTests.swift -o build/FogTests
./build/FogTests
xcrun swiftc -swift-version 5 App/BatPainter.swift App/HauntedWindows.swift App/StagePerformance.swift App/ActorMasks.swift App/BodyTracker.swift App/CostumeFit.swift App/SceneCanvas.swift App/CinematicScene.swift App/SceneLighting.swift App/SceneWeather.swift App/SceneState.swift App/HeadTreatment.swift App/Fog.swift App/Storm.swift Tests/CinematicTests.swift -o build/CinematicTests
./build/CinematicTests
xcrun swiftc -swift-version 5 App/BodyTracker.swift App/CostumeFit.swift App/CostumeStabilizer.swift Tests/TrackingStabilityTests.swift -o build/TrackingStabilityTests
./build/TrackingStabilityTests
xcrun swiftc -swift-version 5 App/ActorCompositor.swift App/VampireEyes.swift App/SceneCanvas.swift Tests/AppearanceTests.swift -o build/AppearanceTests
./build/AppearanceTests

xcrun swiftc -swift-version 5 App/StagePerformance.swift App/BatSprite.swift App/DissolveMesh.swift App/BatDissolve.swift App/BatPainter.swift App/HauntedWindows.swift App/SceneCanvas.swift App/SceneState.swift App/Storm.swift App/HeadTreatment.swift Tests/PerformanceTests.swift -o build/PerformanceTests
./build/PerformanceTests

xcrun swiftc -swift-version 5 App/HeroArtwork.swift App/HeroCostume.swift App/BodyTracker.swift App/SceneCanvas.swift App/SceneState.swift App/StagePerformance.swift App/Storm.swift App/HeadTreatment.swift Tests/CharacterTests.swift -o build/CharacterTests
./build/CharacterTests
