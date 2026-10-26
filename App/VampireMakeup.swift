import CoreGraphics
import Foundation

enum VampireMakeup {
    static func draw(in c: CGContext, eyes: [[CGPoint]], outerLips: [CGPoint], innerLips: [CGPoint],
        face: CGRect, intensity: Double, blood: Bool, time: Double, animateBlood: Bool) {
        guard intensity > 0 else { return }
        c.saveGState(); c.setAlpha(intensity)
        let width = face.width
        func haze(center: CGPoint, radius: CGFloat, aspect: CGFloat, color: CGColor) {
            c.saveGState(); c.translateBy(x: center.x, y: center.y); c.scaleBy(x: 1, y: aspect)
            let fade = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [color, color.copy(alpha: 0)!] as CFArray, locations: [0, 1])!
            c.drawRadialGradient(fade, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: radius, options: [])
            c.restoreGState()
        }
        // Soft cheek hollows retain the camera's real skin texture.
        for side: CGFloat in [-1, 1] {
            haze(center: CGPoint(x: face.midX + side * width * 0.34, y: face.minY + face.height * 0.32),
                radius: width * 0.17, aspect: 1.4, color: CGColor(red: 0.1, green: 0.09, blue: 0.12, alpha: 0.3))
        }
        for eye in eyes where eye.count > 3 {
            let box = eye.reduce(CGRect.null) { $0.union(CGRect(origin: $1, size: CGSize(width: 0.1, height: 0.1))) }
            // Exclude the eyeball itself from the smudged charcoal/plum eye socket.
            c.saveGState(); c.addRect(face.insetBy(dx: -width, dy: -width)); c.addLines(between: eye); c.closePath(); c.clip(using: .evenOdd)
            haze(center: CGPoint(x: box.midX, y: box.midY), radius: box.width * 1.05, aspect: 0.64,
                color: CGColor(red: 0.035, green: 0.018, blue: 0.035, alpha: 0.87))
            haze(center: CGPoint(x: box.midX, y: box.minY - box.width * 0.24), radius: box.width * 0.8, aspect: 0.65,
                color: CGColor(red: 0.19, green: 0.05, blue: 0.09, alpha: 0.28))
            c.restoreGState()
            // Asymmetric, hairline branches rather than repeated straight strokes.
            let side: CGFloat = box.midX < face.midX ? -1 : 1
            for i in 0..<2 {
                let start = CGPoint(x: box.midX + side * box.width * (0.24 + CGFloat(i) * 0.18), y: box.minY)
                let end = CGPoint(x: start.x + side * width * 0.035, y: start.y - width * (i == 0 ? 0.09 : 0.14))
                c.setLineCap(.round); c.setLineWidth(max(0.45, width * 0.0022))
                c.setStrokeColor(CGColor(red: 0.19, green: 0.07, blue: 0.12, alpha: 0.3))
                c.move(to: start); c.addCurve(to: end,
                    control1: CGPoint(x: start.x - side * width * 0.025, y: start.y - width * 0.04),
                    control2: CGPoint(x: end.x + side * width * 0.018, y: end.y + width * 0.03)); c.strokePath()
                c.setLineWidth(max(0.35, width * 0.0013)); c.move(to: CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2))
                c.addQuadCurve(to: CGPoint(x: end.x + side * width * 0.035, y: end.y + width * 0.015),
                    control: CGPoint(x: end.x, y: end.y + width * 0.05)); c.strokePath()
            }
        }
        if outerLips.count > 5 {
            c.saveGState(); c.addLines(between: outerLips); c.closePath()
            if innerLips.count > 2 { c.addLines(between: innerLips); c.closePath() }
            c.clip(using: .evenOdd)
            c.setFillColor(CGColor(red: 0.14, green: 0.018, blue: 0.035, alpha: 0.42)); c.fill(face)
            c.restoreGState()
        }
        if blood, outerLips.count > 5 {
            let sorted = outerLips.sorted { $0.x < $1.x }
            for (i, start) in [sorted[0], sorted[sorted.count - 1]].enumerated() {
                let phase = animateBlood ? (sin(time * 0.7 + Double(i)) + 1) / 2 : 0.6
                let length = face.height * (i == 0 ? 0.085 : 0.19) * (0.92 + phase * 0.08)
                let side: CGFloat = i == 0 ? -1 : 1
                let end = CGPoint(x: start.x + width * side * 0.012, y: start.y - length)
                let thick = width * (i == 0 ? 0.009 : 0.014)
                haze(center: CGPoint(x: start.x, y: start.y - thick), radius: thick * 2.4, aspect: 1.7,
                    color: CGColor(red: 0.24, green: 0.01, blue: 0.025, alpha: 0.55))
                let shape = CGMutablePath(); shape.move(to: CGPoint(x: start.x - thick * 0.6, y: start.y))
                shape.addCurve(to: CGPoint(x: end.x - thick * 0.2, y: end.y),
                    control1: CGPoint(x: start.x - thick * 0.9, y: start.y - length * 0.35),
                    control2: CGPoint(x: end.x + thick * 0.1, y: end.y + length * 0.35))
                shape.addQuadCurve(to: CGPoint(x: end.x + thick * 0.45, y: end.y + thick * 0.2),
                    control: CGPoint(x: end.x, y: end.y - thick * 0.65))
                shape.addCurve(to: CGPoint(x: start.x + thick * 0.65, y: start.y),
                    control1: CGPoint(x: end.x + thick * 0.6, y: end.y + length * 0.4),
                    control2: CGPoint(x: start.x + thick * 0.2, y: start.y - length * 0.2))
                shape.closeSubpath()
                c.saveGState(); c.addPath(shape); c.clip()
                let colors = [CGColor(red: 0.16, green: 0.003, blue: 0.014, alpha: 0.93),
                    CGColor(red: 0.43, green: 0.015, blue: 0.025, alpha: 0.91)] as CFArray
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
                c.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                c.restoreGState()
                c.setLineWidth(max(0.4, width * 0.0017)); c.setStrokeColor(CGColor(red: 0.8, green: 0.31, blue: 0.3, alpha: 0.35))
                c.move(to: CGPoint(x: end.x + thick * 0.1, y: end.y + length * 0.18))
                c.addLine(to: CGPoint(x: end.x + thick * 0.1, y: end.y + length * 0.06)); c.strokePath()
            }
        }
        c.restoreGState()
    }
}
