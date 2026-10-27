import Foundation

struct OutfitAdjustments: Codable, Equatable {
    static let sizeRange = 0.6...1.4
    static let liftRange = -0.3...0.3
    var width = 1.0
    var height = 1.0
    var lift = 0.0

    var bounded: Self {
        func clamp(_ value: Double, to range: ClosedRange<Double>, fallback: Double) -> Double {
            value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback
        }
        return Self(width: clamp(width, to: Self.sizeRange, fallback: 1),
            height: clamp(height, to: Self.sizeRange, fallback: 1),
            lift: clamp(lift, to: Self.liftRange, fallback: 0))
    }
}

/// Each character owns its calibration. Saving a fit does not change scene or camera settings.
struct CharacterFits: Codable, Equatable {
    private var vampire = OutfitAdjustments()
    private var batman = OutfitAdjustments()
    static let preferencesKey = "characterFits.v1"

    subscript(character: SceneCharacter) -> OutfitAdjustments {
        get { character == .vampire ? vampire : batman }
        set {
            if character == .vampire { vampire = newValue.bounded }
            else { batman = newValue.bounded }
        }
    }

    mutating func reset(_ character: SceneCharacter) { self[character] = OutfitAdjustments() }

    func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.preferencesKey)
    }

    static func load(from defaults: UserDefaults = .standard) -> Self {
        guard let data = defaults.data(forKey: preferencesKey),
              var result = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        result.vampire = result.vampire.bounded
        result.batman = result.batman.bounded
        return result
    }
}
