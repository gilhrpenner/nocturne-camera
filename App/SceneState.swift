import Foundation

struct SceneOptions {
    var vampire = true
    var costume = true
    var blood = true
    var animateBlood = true
    var hairStyle: HairStyle = .white
    var hairAmount: Double = 1
    var castle = true
    var cinematic = true
    var sceneDepth: Double = 0.65
    var animateScene = true
    var hauntedWindows = true
    var rainAmount: Double = 0.18
    var relighting: Double = 0.45
    var costumeWidth: Double = 1
    var costumeLift: Double = 0
    var preserveHands = true
    var bats = true
    var autoLightning = true
    var fogAmount: Double = 0.55
    var animateFog = true
    var normal = false
    var intensity: Double = 0.85
    var distance: Double = 0

    var subjectScale: Double { castle && !normal ? 1 - min(1, max(0, distance)) * 0.45 : 1 }
    var lightningAt: TimeInterval = -100
    var swarmAt: TimeInterval = -100
    var vanishAt: TimeInterval = -100
    var entranceAt: TimeInterval = -100

    func performance(at time: TimeInterval) -> StagePerformance? {
        guard !normal, castle else { return nil }
        return StagePerformance.active(vanishAt: vanishAt, entranceAt: entranceAt, time: time)
    }

    mutating func cancelPerformance() { vanishAt = -100; entranceAt = -100 }

    @discardableResult
    mutating func beginPerformance(_ kind: StagePerformance.Kind, at time: TimeInterval) -> Bool {
        guard !normal, castle, performance(at: time) == nil else { return false }
        cancelPerformance()
        if kind == .vanish { vanishAt = time } else { entranceAt = time }
        return true
    }

    func strikes(at time: TimeInterval) -> [LightningStrike] {
        guard !normal else { return [] }
        var strikes = Storm.strikes(at: time, automatic: autoLightning, manualAt: lightningAt)
        if let cue = performance(at: time), cue.kind == .entrance {
            // A smaller opening flash hides the cut to an empty stage; the main strike lands on the reveal.
            strikes += Storm.strikes(at: time, automatic: false, manualAt: cue.startedAt).map {
                LightningStrike(points: $0.points, branches: $0.branches, brightness: $0.brightness * 0.45, width: $0.width)
            }
            strikes += Storm.strikes(at: time, automatic: false, manualAt: cue.startedAt + 1.45)
        }
        return strikes
    }

    func flash(at time: TimeInterval) -> Double {
        strikes(at: time).map(\.brightness).max() ?? 0
    }

    func isVanished(at time: TimeInterval) -> Bool {
        performance(at: time)?.dissolution == 1
    }
}

/// UI writes and the capture queue reads a single coherent snapshot per frame.
final class SceneState: @unchecked Sendable {
    private let lock = NSLock()
    private var value = SceneOptions()
    func read() -> SceneOptions { lock.lock(); defer { lock.unlock() }; return value }
    func update(_ body: (inout SceneOptions) -> Void) {
        lock.lock(); defer { lock.unlock() }; body(&value)
    }
}
