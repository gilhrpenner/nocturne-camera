import CoreGraphics

enum FangPainter {
    static func draw(_ fangs: [Fang], in context: CGContext, opacity: CGFloat) {
        guard opacity > 0 else { return }
        for fang in fangs {
            let root = fang.rootCenter
            let down = CGVector(dx: fang.tip.x - root.x, dy: fang.tip.y - root.y)
            let across = CGVector(dx: fang.rootRight.x - fang.rootLeft.x, dy: fang.rootRight.y - fang.rootLeft.y)
            func offset(_ p: CGPoint, _ d: CGFloat, _ a: CGFloat) -> CGPoint {
                CGPoint(x: p.x + down.dx * d + across.dx * a, y: p.y + down.dy * d + across.dy * a)
            }
            let shape = CGMutablePath()
            shape.move(to: fang.rootLeft)
            shape.addLine(to: fang.rootRight)
            shape.addCurve(to: fang.tip, control1: offset(fang.rootRight, 0.38, -0.08),
                control2: offset(fang.tip, -0.14, 0.14))
            shape.addCurve(to: fang.rootLeft, control1: offset(fang.tip, -0.14, -0.14),
                control2: offset(fang.rootLeft, 0.38, 0.08))
            shape.closeSubpath()

            context.saveGState()
            context.setAlpha(opacity)
            context.addPath(shape); context.clip()
            let colors = [CGColor(red: 0.98, green: 0.96, blue: 0.9, alpha: 1),
                CGColor(red: 0.76, green: 0.77, blue: 0.75, alpha: 1)] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            context.drawLinearGradient(gradient, start: root, end: fang.tip,
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            context.restoreGState()
        }
    }
}
