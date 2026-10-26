import CoreGraphics

enum BatPainter {
    static func draw(in c: CGContext, point: CGPoint, size: CGFloat, flap: CGFloat,
                     angle: CGFloat = 0, distant: Bool = false, opacity: CGFloat = 1) {
        c.saveGState()
        c.translateBy(x: point.x, y: point.y); c.rotate(by: angle); c.scaleBy(x: size, y: size)
        c.setAlpha(opacity)
        c.setFillColor(CGColor(red: distant ? 0.035 : 0.018, green: distant ? 0.045 : 0.022, blue: distant ? 0.06 : 0.03, alpha: 0.98))
        c.setStrokeColor(CGColor(red: 0.22, green: 0.27, blue: 0.36, alpha: distant ? 0 : 0.52))
        c.setLineWidth(0.035)
        for side: CGFloat in [-1, 1] {
            c.move(to: CGPoint(x: 0, y: 0.15))
            c.addCurve(to: CGPoint(x: side * 1.55, y: 0.15 + flap * 0.7),
                control1: CGPoint(x: side * 0.4, y: 0.8), control2: CGPoint(x: side * 0.9, y: 0.9 + flap * 0.4))
            c.addQuadCurve(to: CGPoint(x: side * 0.85, y: -0.35), control: CGPoint(x: side * 1.1, y: 0))
            c.addQuadCurve(to: CGPoint(x: side * 0.35, y: -0.25), control: CGPoint(x: side * 0.55, y: -0.05))
            c.addLine(to: CGPoint(x: 0, y: -0.5)); c.closePath(); c.drawPath(using: .fillStroke)
        }
        c.fillEllipse(in: CGRect(x: -0.13, y: -0.34, width: 0.26, height: 0.7))
        c.move(to: CGPoint(x: -0.13, y: 0.15)); c.addLine(to: CGPoint(x: -0.16, y: 0.53))
        c.addLine(to: CGPoint(x: 0, y: 0.33)); c.addLine(to: CGPoint(x: 0.16, y: 0.53))
        c.addLine(to: CGPoint(x: 0.13, y: 0.15)); c.closePath(); c.fillPath()
        c.restoreGState()
    }
}
