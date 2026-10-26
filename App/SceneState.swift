import Foundation

struct SceneOptions {
    var vampire = true
    var castle = true
    var bats = true
    var autoLightning = true
    var normal = false
    var intensity: Double = 0.85
    var lightningAt: TimeInterval = -100
    var swarmAt: TimeInterval = -100
    var vanishAt: TimeInterval = -100

    func flash(at time: TimeInterval) -> Double {
        guard !normal else { return 0 }
        let manual = time - lightningAt
        let automatic = autoLightning ? time.truncatingRemainder(dividingBy: 8.5) : 100
        let age = min(manual >= 0 ? manual : 100, automatic)
        return age < 0.55 ? pow(max(0, 1 - age / 0.55), 3) : 0
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
