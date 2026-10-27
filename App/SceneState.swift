import Foundation

enum SceneCharacter: String, CaseIterable, Identifiable {
    case vampire = "Vampire"
    case batman = "Batman"
    var id: String { rawValue }
    var other: Self { self == .vampire ? .batman : .vampire }
}

private struct CharacterTransition {
    let from: SceneCharacter
    let to: SceneCharacter
    let switchAt: TimeInterval
    func character(at time: TimeInterval) -> SceneCharacter { time < switchAt ? from : to }
}

struct SceneOptions {
    private(set) var selectedCharacter: SceneCharacter = .vampire
    private var characterTransition: CharacterTransition?
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
    var characterFits = CharacterFits()
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

    func character(at time: TimeInterval) -> SceneCharacter {
        characterTransition?.character(at: time) ?? selectedCharacter
    }

    /// Resolve only for this frame; the user's vampire settings survive a round trip.
    func renderingOptions(at time: TimeInterval) -> Self {
        var result = self
        result.selectedCharacter = character(at: time)
        result.characterTransition = nil
        if result.selectedCharacter == .batman {
            result.vampire = false; result.blood = false; result.hairStyle = .natural; result.costume = true
        }
        return result
    }

    func performanceLabel(at time: TimeInterval) -> String {
        guard let cue = performance(at: time) else { return "" }
        if cue.kind == .vanish, let transition = characterTransition {
            return cue.gathering ? "Returning as \(transition.to.rawValue)…" : "\(cue.label) Next: \(transition.to.rawValue)."
        }
        return cue.label
    }

    mutating func selectCharacter(_ character: SceneCharacter, at time: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        cancelPerformance(at: time)
        selectedCharacter = character
    }

    mutating func cancelPerformance(at time: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        selectedCharacter = character(at: time)
        characterTransition = nil
        vanishAt = -100; entranceAt = -100
    }

    @discardableResult
    mutating func beginPerformance(_ kind: StagePerformance.Kind, at time: TimeInterval) -> Bool {
        guard !normal, castle, performance(at: time) == nil else { return false }
        cancelPerformance(at: time)
        if kind == .vanish {
            vanishAt = time
            let cue = StagePerformance(kind: kind, startedAt: time, elapsed: 0)
            characterTransition = CharacterTransition(from: selectedCharacter, to: selectedCharacter.other,
                switchAt: time + cue.gatheringAt)
        } else { entranceAt = time }
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
