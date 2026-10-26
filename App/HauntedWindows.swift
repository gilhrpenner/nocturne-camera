import CoreImage
import CoreGraphics

enum HauntedWindows {
    struct Visit {
        let window: Int
        let progress: Double
        var opacity: Double { min(1, progress * 8, (1 - progress) * 8) }
    }

    static func visit(at time: Double) -> Visit? {
        let slot = Int(floor(time / 29))
        let age = time - (Double(slot) * 29 + 6 + Storm.random(slot, 121) * 9)
        guard age >= 0, age < 5.6 else { return nil }
        return Visit(window: slot.isMultiple(of: 2) ? 0 : 1, progress: age / 5.6)
    }

    /// Glass panes in the castle plate's 1672 × 941 coordinate system, measured from the top.
    static let windows = [CGRect(x: 1274, y: 405, width: 18, height: 36),
                          CGRect(x: 1266, y: 237, width: 17, height: 22)]

    static func image(time: Double, options: SceneOptions, bounds: CGRect) -> CIImage? {
        guard !options.normal, options.cinematic, options.hauntedWindows, options.animateScene,
              let visit = visit(at: time) else { return nil }
        return image(visit: visit, bounds: bounds)
    }

    static func image(visit: Visit, bounds: CGRect) -> CIImage {
        SceneCanvas.image(bounds: bounds) { c in
            // Use the same aspect-fill mapping as the castle, before its perspective projection.
            let scale = max(bounds.width / 1672, bounds.height / 941)
            c.translateBy(x: bounds.midX - 836 * scale, y: bounds.midY - 470.5 * scale)
            c.scaleBy(x: scale, y: scale)
            let window = windows[visit.window]
            let rect = CGRect(x: window.minX, y: 941 - window.maxY, width: window.width, height: window.height)
            c.saveGState()
            // Separate panes leave the original stone mullion visible in front of the figure.
            c.addRect(CGRect(x: rect.minX, y: rect.minY, width: rect.width * 0.40, height: rect.height))
            c.addRect(CGRect(x: rect.minX + rect.width * 0.60, y: rect.minY, width: rect.width * 0.40, height: rect.height))
            c.clip()
            let sway = sin(visit.progress * .pi * 3) * rect.height * 0.018
            let x = rect.minX - rect.width * 0.38 + rect.width * 1.76 * visit.progress
            let bodyWidth = rect.width * 0.42, bodyHeight = rect.height * 0.68
            let y = rect.minY + rect.height * 0.08 + sway
            c.setFillColor(CGColor(red: 0.012, green: 0.016, blue: 0.025, alpha: visit.opacity * 0.91))
            c.fillEllipse(in: CGRect(x: x - bodyWidth * 0.24, y: y + bodyHeight * 0.72,
                width: bodyWidth * 0.48, height: bodyHeight * 0.25))
            c.move(to: CGPoint(x: x - bodyWidth * 0.48, y: y))
            c.addQuadCurve(to: CGPoint(x: x - bodyWidth * 0.25, y: y + bodyHeight * 0.72),
                control: CGPoint(x: x - bodyWidth * 0.45, y: y + bodyHeight * 0.7))
            c.addQuadCurve(to: CGPoint(x: x + bodyWidth * 0.25, y: y + bodyHeight * 0.72),
                control: CGPoint(x: x, y: y + bodyHeight * 0.85))
            c.addLine(to: CGPoint(x: x + bodyWidth * 0.55, y: y)); c.closePath(); c.fillPath()
            c.restoreGState()
        }
    }
}
