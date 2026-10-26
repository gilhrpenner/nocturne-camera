import CoreImage
import CoreGraphics

enum ActorMasks {
    static func head(jaw: [CGPoint], face: CGRect, bounds: CGRect, placement: CGAffineTransform) -> CIImage {
        SceneCanvas.image(bounds: bounds, transform: placement) { c in
            // Transparent outside, opaque over the head. Extend to the frame top to protect hair.
            c.setFillColor(CGColor(gray: 1, alpha: 1))
            if let first = jaw.first, let last = jaw.last, jaw.count > 4 {
                c.addLines(between: jaw)
                c.addLine(to: CGPoint(x: last.x, y: bounds.maxY + 1000))
                c.addLine(to: CGPoint(x: first.x, y: bounds.maxY + 1000))
                c.closePath(); c.fillPath()
            } else {
                c.fill(CGRect(x: face.minX - face.width * 0.05, y: face.minY, width: face.width * 1.1, height: bounds.height + 1000))
            }
            // This mask now supplies the actual cutout, so preserve ears and the wider crown too.
            c.fill(CGRect(x: face.minX - face.width * 0.16, y: face.minY + face.height * 0.45,
                width: face.width * 1.32, height: bounds.height + 1000))
            for side: CGFloat in [-1, 1] {
                c.fillEllipse(in: CGRect(x: face.midX + side * face.width * 0.51 - face.width * 0.12,
                    y: face.minY + face.height * 0.27, width: face.width * 0.24, height: face.height * 0.57))
            }
        }.composited(over: CIImage(color: .black).cropped(to: bounds))
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.75]).cropped(to: bounds)
    }

    static func neck(face: FaceAnchor, neckline: CGPoint, bounds: CGRect, placement: CGAffineTransform) -> CIImage {
        SceneCanvas.image(bounds: bounds, transform: placement) { c in
            let width = face.bounds.width, height = face.bounds.height
            let bottom = max(face.chin.y - height * 0.65, min(face.chin.y - height * 0.18, neckline.y - height * 0.08))
            let x = min(face.chin.x + width * 0.2, max(face.chin.x - width * 0.2, neckline.x))
            c.setFillColor(CGColor(gray: 1, alpha: 1))
            c.addLines(between: [CGPoint(x: face.chin.x - width * 0.28, y: face.chin.y + height * 0.22),
                CGPoint(x: face.chin.x + width * 0.28, y: face.chin.y + height * 0.22),
                CGPoint(x: x + width * 0.24, y: bottom), CGPoint(x: x - width * 0.24, y: bottom)])
            c.closePath(); c.fillPath()
        }.composited(over: CIImage(color: .black).cropped(to: bounds))
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 1.2]).cropped(to: bounds)
    }

    static func hands(hulls: [[CGPoint]], arms: [[CGPoint]], faceWidth: CGFloat, bounds: CGRect, placement: CGAffineTransform) -> CIImage {
        SceneCanvas.image(bounds: bounds, transform: placement) { c in
            c.setFillColor(CGColor(gray: 1, alpha: 1)); c.setStrokeColor(CGColor(gray: 1, alpha: 1)); c.setLineJoin(.round); c.setLineCap(.round)
            for points in hulls {
                let polygon = hull(points)
                guard polygon.count >= 3 else { continue }
                c.addLines(between: polygon); c.closePath()
                c.setLineWidth(max(4, faceWidth * 0.035)); c.drawPath(using: .fillStroke)
            }
            for arm in arms where arm.count == 2 {
                // Only restore a forearm when a detected hand is near that wrist.
                guard hulls.contains(where: { points in points.contains { distance($0, arm[1]) < faceWidth * 0.6 } }) else { continue }
                c.setLineWidth(faceWidth * 0.25); c.move(to: arm[0]); c.addLine(to: arm[1]); c.strokePath()
            }
        }.composited(over: CIImage(color: .black).cropped(to: bounds))
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 1.4]).cropped(to: bounds)
    }

    static func hull(_ points: [CGPoint]) -> [CGPoint] {
        let sorted = points.sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }
        guard sorted.count > 2 else { return sorted }
        func cross(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat { (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x) }
        var lower: [CGPoint] = [], upper: [CGPoint] = []
        for p in sorted { while lower.count > 1 && cross(lower[lower.count - 2], lower[lower.count - 1], p) <= 0 { lower.removeLast() }; lower.append(p) }
        for p in sorted.reversed() { while upper.count > 1 && cross(upper[upper.count - 2], upper[upper.count - 1], p) <= 0 { upper.removeLast() }; upper.append(p) }
        return Array(lower.dropLast()) + Array(upper.dropLast())
    }
}
