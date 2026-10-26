import Foundation

/// A single clock drives the actor, flock, lightning and cue feedback.
struct StagePerformance {
    enum Kind { case vanish, entrance }
    let kind: Kind
    let startedAt: Double
    let elapsed: Double

    static let departureDuration = 1.3
    static let flightDuration = 1.25
    var returnAt: Double { kind == .vanish ? 4.25 : 0.55 }
    var returnDuration: Double { 1.75 }
    var duration: Double { returnAt + returnDuration }
    var gathering: Bool { kind == .entrance || elapsed >= returnAt - Self.flightDuration }

    /// 0 is the whole actor; 1 is an empty stage.
    var dissolution: Double {
        if elapsed >= returnAt { return max(0, 1 - (elapsed - returnAt) / returnDuration) }
        return kind == .entrance ? 1 : min(1, elapsed / Self.departureDuration)
    }

    var label: String {
        if kind == .entrance { return elapsed < returnAt ? "Gathering bats…" : "Making an entrance…" }
        if elapsed < Self.departureDuration { return "Dissolving into bats…" }
        if elapsed < Self.departureDuration + Self.flightDuration { return "Bats dispersing…" }
        if !gathering { return "Vanished" }
        return elapsed < returnAt ? "Bats gathering…" : "Reforming…"
    }

    static func active(vanishAt: Double, entranceAt: Double, time: Double) -> Self? {
        // The newest cue owns the stage, including after it ends.
        let kind: Kind = entranceAt > vanishAt ? .entrance : .vanish
        let start = max(vanishAt, entranceAt)
        guard start >= 0 else { return nil }
        let cue = Self(kind: kind, startedAt: start, elapsed: time - start)
        return cue.elapsed >= 0 && cue.elapsed < cue.duration ? cue : nil
    }
}
