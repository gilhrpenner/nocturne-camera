import Foundation

struct SceneOptions {
    var vampire = true
    var costume = true
    var blood = true
    var animateBlood = true
    var castle = true
    var bats = true
    var autoLightning = true
    var normal = false
    var intensity: Double = 0.85
    var distance: Double = 0

    var subjectScale: Double { castle && !normal ? 1 - min(1, max(0, distance)) * 0.45 : 1 }
    var lightningAt: TimeInterval = -100
    var swarmAt: TimeInterval = -100
    var vanishAt: TimeInterval = -100

    func flash(at time: TimeInterval) -> Double {
        guard !normal else { return 0 }
        return Storm.strikes(at: time, automatic: autoLightning, manualAt: lightningAt).map(\.brightness).max() ?? 0
    }

    func isVanished(at time: TimeInterval) -> Bool {
        !normal && (0..<3).contains(time - vanishAt)
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
