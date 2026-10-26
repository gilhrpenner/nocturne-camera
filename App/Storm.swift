import Foundation
import CoreGraphics

struct LightningStrike {
    let points: [CGPoint]
    let branches: [[CGPoint]]
    let brightness: Double
    let width: CGFloat
}

enum Storm {
    /// Stable per-event randomness: bolts keep their shape while they fade.
    static func random(_ seed: Int, _ salt: Int) -> Double {
        var value = UInt64(bitPattern: Int64(seed)) &+ UInt64(salt) &* 0x9E3779B97F4A7C15
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return Double((value ^ (value >> 31)) % 10_000) / 10_000
    }

    static func strikes(at time: Double, automatic: Bool, manualAt: Double) -> [LightningStrike] {
        var events: [(start: Double, seed: Int, manual: Bool)] = []
        if automatic {
            let slot = Int(floor(time / 3.2))
            for index in (slot - 1)...slot {
                events.append((Double(index) * 3.2 + random(index, 1) * 0.65, index, false))
            }
        }
        if manualAt >= 0 { events.append((manualAt, Int(manualAt * 100), true)) }
        var result: [LightningStrike] = []
        for event in events {
            let count = event.manual ? 3 : 1 + Int(random(event.seed, 2) * 3)
            for i in 0..<count {
                let age = time - event.start - Double(i) * 0.19
                guard age >= 0, age < 0.46 else { continue }
                let seed = event.seed &* 7 &+ i
                let peak = event.manual && i == 0 ? 1.0 : 0.4 + random(seed, 3) * 0.6
                let brightness = peak * pow(1 - age / 0.46, 1.8)
                var x = 0.08 + random(seed, 4) * 0.84
                let endY = 0.36 + random(seed, 5) * 0.23
                var points: [CGPoint] = [CGPoint(x: x, y: 1.02)]
                for step in 1...8 {
                    x = max(0.03, min(0.97, x + (random(seed, 10 + step) - 0.5) * 0.09))
                    points.append(CGPoint(x: x, y: 1.02 - (1.02 - endY) * Double(step) / 8))
                }
                let branches: [[CGPoint]] = [3, 5].map { step in
                    let p = points[step], side: CGFloat = step == 3 ? -1 : 1
                    return [p, CGPoint(x: p.x + side * 0.045, y: p.y - 0.035),
                        CGPoint(x: p.x + side * 0.03, y: p.y - 0.075),
                        CGPoint(x: p.x + side * 0.075, y: p.y - 0.13)]
                }
                result.append(LightningStrike(points: points, branches: branches, brightness: brightness,
                    width: CGFloat(1.2 + random(seed, 6) * 2.6)))
            }
        }
        return result
    }

    static func draw(_ strikes: [LightningStrike], in c: CGContext, bounds: CGRect) {
        func scaled(_ points: [CGPoint]) -> [CGPoint] {
            points.map { CGPoint(x: $0.x * bounds.width, y: $0.y * bounds.height) }
        }
        c.saveGState(); c.setLineJoin(.round); c.setLineCap(.round)
        for strike in strikes {
            let glow = CGFloat(strike.brightness)
            c.setShadow(offset: .zero, blur: 22, color: CGColor(red: 0.4, green: 0.6, blue: 1, alpha: glow))
            c.setStrokeColor(CGColor(red: 0.7, green: 0.81, blue: 1, alpha: glow * 0.7))
            c.setLineWidth(strike.width * 3); c.addLines(between: scaled(strike.points)); c.strokePath()
            c.setShadow(offset: .zero, blur: 0)
            c.setStrokeColor(CGColor(red: 0.93, green: 0.96, blue: 1, alpha: glow))
            c.setLineWidth(strike.width); c.addLines(between: scaled(strike.points)); c.strokePath()
            c.setLineWidth(strike.width * 0.55)
            for branch in strike.branches { c.addLines(between: scaled(branch)); c.strokePath() }
        }
        c.restoreGState()
    }
}
