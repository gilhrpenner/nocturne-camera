import CoreImage
import CoreGraphics

struct DissolveBat {
    let origin: CGPoint
    let seed: Int

    func position(progress: Double, bounds: CGRect) -> CGPoint {
        let p = max(0, min(1, progress))
        let side = origin.x < bounds.midX ? -1.0 : 1.0
        let end = CGPoint(x: bounds.midX + side * bounds.width * (0.70 + Storm.random(seed, 94) * 0.30),
            y: bounds.height * (0.2 + Storm.random(seed, 95) * 1.0))
        let bend = sin(p * .pi)
        return CGPoint(x: origin.x + (end.x - origin.x) * pow(p, 1.8) + side * bend * 55,
            y: origin.y + (end.y - origin.y) * pow(p, 1.35) + bend * (65 + Storm.random(seed, 96) * 105))
    }
}

/// Temporary actor fragments fold into photographic bats, and unfold again on return.
/// Fragment textures exist only in memory for the current cue.
final class BatDissolve {
    private let sprite: BatSprite
    private var cueStart = -Double.infinity
    private var returning = false
    private var capturedAnchor: CGPoint?
    private(set) var fragments: [DissolveFragment] = []

    init(sprite: BatSprite) { self.sprite = sprite }
    func reset() { cueStart = -.infinity; fragments = []; returning = false; capturedAnchor = nil }
    func needsCapture(for cue: StagePerformance) -> Bool { cue.startedAt != cueStart || cue.gathering != returning }

    func image(actor: CIImage, performance: StagePerformance?, context: CIContext, bounds: CGRect, anchor: CGPoint? = nil, flash: Double = 0) -> CIImage {
        guard let cue = performance else { reset(); return actor }
        if needsCapture(for: cue) {
            fragments = DissolveMesh.capture(actor: actor, context: context, bounds: bounds)
                .sorted { Storm.random($0.seed, 97) < Storm.random($1.seed, 97) }
            for i in fragments.indices {
                if let texture = fragments[i].texture { fragments[i].batTexture = sprite.material(from: texture) }
            }
            cueStart = cue.startedAt; returning = cue.gathering; capturedAnchor = anchor
        }
        let movement: CGAffineTransform
        if let anchor, let capturedAnchor {
            movement = CGAffineTransform(translationX: anchor.x - capturedAnchor.x, y: anchor.y - capturedAnchor.y)
        } else { movement = .identity }
        let remainder = attached(actor: actor, amount: cue.dissolution, bounds: bounds, movement: movement)
        let flock = SceneCanvas.image(bounds: bounds) { c in
            // Large, nearer creatures pass in front of the smaller members of the flock.
            for fragment in fragments {
                guard let texture = fragment.texture else { continue }
                let arrival = cue.returnAt + (1 - fragment.threshold) * cue.returnDuration
                let departure = cue.gathering ? max(0, arrival - StagePerformance.flightDuration) : fragment.threshold * StagePerformance.departureDuration
                let travel = cue.gathering ? arrival - departure : StagePerformance.flightDuration
                let age = cue.elapsed - departure
                guard age >= 0, age < travel else { continue }
                let phase = age / travel
                let outward = cue.gathering ? 1 - phase : phase
                let origin = fragment.origin.applying(movement)
                let point = DissolveBat(origin: origin, seed: fragment.seed).position(progress: outward, bounds: bounds)
                let morph = Self.smooth(0.06, 0.28, outward)
                let piece = 1 - Self.smooth(0, 0.065, outward)
                let skin = Self.smooth(0, 0.055, outward) * (1 - Self.smooth(0.09, 0.30, outward))
                let depth = Storm.random(fragment.seed, 97)
                let bank = sin(cue.elapsed * 2.8 + Double(fragment.seed)) * 0.52 * morph
                let grow = 0.65 + sin(outward * .pi) * (0.65 + depth * 0.9)
                let span = bounds.width / 1280 * (52 + depth * 48) * grow
                let edgeFade = min(1, (1 - outward) * 14)
                if piece > 0 {
                    // The actual pixels that occupied this part of the person lift off before wings open.
                    c.saveGState(); c.setAlpha(piece * edgeFade)
                    c.translateBy(x: point.x, y: point.y); c.rotate(by: bank + sin(Double(fragment.seed)) * morph * 0.5)
                    c.scaleBy(x: 1 - morph * 0.35, y: 1 - morph * 0.62)
                    c.draw(texture, in: CGRect(x: fragment.rect.minX - fragment.origin.x,
                        y: fragment.rect.minY - fragment.origin.y, width: fragment.rect.width, height: fragment.rect.height))
                    c.restoreGState()
                }
                if skin > 0, let material = fragment.batTexture {
                    sprite.drawMaterial(material, in: c, point: point, span: span,
                        fold: min(1, outward * 9), bank: bank, opacity: skin * edgeFade)
                }
                if morph > 0 {
                    sprite.draw(in: c, point: point, span: span, flap: sin(cue.elapsed * (15 + depth * 7) + Double(fragment.seed) * 1.7),
                        bank: bank, opacity: morph * edgeFade)
                }
            }
        }
        let litFlock = flash > 0 ? flock.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: flash * 0.65]) : flock
        return litFlock.composited(over: remainder).cropped(to: bounds)
    }

    func attached(actor: CIImage, amount: Double, bounds: CGRect, movement: CGAffineTransform = .identity) -> CIImage {
        if amount <= 0 { return actor }
        if amount >= 1 { return CIImage(color: .clear).cropped(to: bounds) }
        let mask = SceneCanvas.image(bounds: bounds) { c in
            c.setFillColor(CGColor(gray: 1, alpha: 1)); c.fill(bounds)
            c.setShouldAntialias(false)
            c.concatenate(movement)
            for fragment in fragments {
                let visible = 1 - Self.smooth(fragment.threshold, fragment.threshold + 0.035, amount)
                guard visible < 1 else { continue }
                c.setFillColor(CGColor(gray: visible, alpha: 1))
                c.addLines(between: fragment.polygon); c.closePath(); c.fillPath()
            }
        }
        return actor.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: CIImage(color: .clear).cropped(to: bounds),
            kCIInputMaskImageKey: mask])
    }

    private static func smooth(_ low: Double, _ high: Double, _ value: Double) -> Double {
        let p = min(1, max(0, (value - low) / (high - low)))
        return p * p * (3 - 2 * p)
    }
}
