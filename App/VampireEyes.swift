import CoreGraphics
import Foundation

struct VampireEye {
    let outline: [CGPoint]
    let center: CGPoint
    let radius: CGFloat
    let angle: CGFloat
    let pupilDetected: Bool

    static func make(outline: [CGPoint], pupil: CGPoint?) -> VampireEye? {
        guard outline.count >= 4, let left = outline.min(by: { $0.x < $1.x }),
              let right = outline.max(by: { $0.x < $1.x }) else { return nil }
        let width = hypot(right.x - left.x, right.y - left.y)
        guard width > 4 else { return nil }
        let axis = CGPoint(x: (right.x - left.x) / width, y: (right.y - left.y) / width)
        let up = CGPoint(x: -axis.y, y: axis.x)
        func local(_ point: CGPoint) -> CGPoint {
            let dx = point.x - left.x, dy = point.y - left.y
            return CGPoint(x: dx * axis.x + dy * axis.y, y: dx * up.x + dy * up.y)
        }
        let projected = outline.map(local)
        let low = projected.map(\.y).min()!, high = projected.map(\.y).max()!
        guard high - low > width * 0.11 else { return nil }
        var position = pupil.map(local) ?? CGPoint(x: width / 2, y: (high + low) / 2)
        // A bad pupil observation must not place a contact on the eyelid or outside the eye.
        let detected = pupil != nil && position.x >= width * 0.12 && position.x <= width * 0.88 && position.y >= low && position.y <= high
        if !detected { position = CGPoint(x: width / 2, y: (high + low) / 2) }
        let center = CGPoint(x: left.x + axis.x * position.x + up.x * position.y,
            y: left.y + axis.y * position.x + up.y * position.y)
        return VampireEye(outline: outline, center: center, radius: width * 0.205,
            angle: atan2(axis.y, axis.x), pupilDetected: detected)
    }
}

enum VampireEyes {
    static func draw(_ eye: VampireEye, in c: CGContext, intensity: Double) {
        guard intensity > 0 else { return }
        let r = eye.radius
        c.saveGState()
        c.addLines(between: eye.outline); c.closePath(); c.clip()
        c.setAlpha(min(1, intensity * (eye.pupilDetected ? 1.08 : 0.82)))
        c.translateBy(x: eye.center.x, y: eye.center.y); c.rotate(by: eye.angle)
        c.addEllipse(in: CGRect(x: -r, y: -r, width: r * 2, height: r * 2)); c.clip()
        let colors = [CGColor(red: 0.08, green: 0.009, blue: 0.014, alpha: 1),
            CGColor(red: 0.48, green: 0.11, blue: 0.045, alpha: 1),
            CGColor(red: 0.36, green: 0.025, blue: 0.045, alpha: 1),
            CGColor(red: 0.055, green: 0.006, blue: 0.014, alpha: 1)] as CFArray
        let iris = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.38, 0.68, 1])!
        c.drawRadialGradient(iris, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: r,
            options: [.drawsAfterEndLocation])
        // Stable radial fibers add iris texture without frame-to-frame sparkle.
        c.setLineCap(.round)
        for i in 0..<44 {
            let angle = Double(i) * .pi * 2 / 44
            let variation = CGFloat((i * 37) % 19) / 19
            let inner = r * (0.36 + variation * 0.1), outer = r * (0.77 + variation * 0.16)
            c.setLineWidth(max(0.25, r * 0.035))
            c.setStrokeColor(CGColor(red: 0.72, green: 0.19 + variation * 0.11, blue: 0.12, alpha: 0.12 + variation * 0.17))
            c.move(to: CGPoint(x: cos(angle) * inner, y: sin(angle) * inner))
            c.addLine(to: CGPoint(x: cos(angle + 0.025) * outer, y: sin(angle + 0.025) * outer)); c.strokePath()
        }
        c.setStrokeColor(CGColor(red: 0.025, green: 0.006, blue: 0.012, alpha: 0.85))
        c.setLineWidth(r * 0.13); c.strokeEllipse(in: CGRect(x: -r * 0.94, y: -r * 0.94, width: r * 1.88, height: r * 1.88))
        c.setFillColor(CGColor(red: 0.008, green: 0.006, blue: 0.012, alpha: 1))
        c.fillEllipse(in: CGRect(x: -r * 0.34, y: -r * 0.34, width: r * 0.68, height: r * 0.68))
        let shade = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [CGColor(gray: 0, alpha: 0.5), CGColor(gray: 0, alpha: 0)] as CFArray, locations: [0, 1])!
        c.drawLinearGradient(shade, start: CGPoint(x: 0, y: r), end: CGPoint(x: 0, y: -r * 0.4), options: [])
        c.setFillColor(CGColor(red: 0.92, green: 0.96, blue: 1, alpha: 0.66))
        c.fillEllipse(in: CGRect(x: -r * 0.38, y: r * 0.3, width: r * 0.19, height: r * 0.16))
        c.setStrokeColor(CGColor(red: 0.75, green: 0.85, blue: 0.95, alpha: 0.12)); c.setLineWidth(max(0.3, r * 0.06))
        c.addArc(center: .zero, radius: r * 0.77, startAngle: -.pi * 0.75, endAngle: -.pi * 0.28, clockwise: false); c.strokePath()
        c.restoreGState()
    }
}
