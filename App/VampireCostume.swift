import CoreGraphics

struct CostumePose {
    let chin: CGPoint
    let faceWidth: CGFloat
    let faceHeight: CGFloat
    var shoulders: [CGPoint] = []

    var transform: CGAffineTransform {
        let pair = shoulders.sorted { $0.x < $1.x }
        var span = faceWidth * 2.65
        var angle: CGFloat = 0
        if pair.count == 2 {
            let measured = hypot(pair[1].x - pair[0].x, pair[1].y - pair[0].y)
            if measured > faceWidth * 1.3 && measured < faceWidth * 4 {
                span = measured * 1.1
                angle = atan2(pair[1].y - pair[0].y, pair[1].x - pair[0].x)
            }
        }
        return CGAffineTransform(translationX: chin.x, y: chin.y - faceHeight * 0.06)
            .rotated(by: angle).scaledBy(x: span / 2, y: span / 2)
    }
}

enum VampireCostume {
    /// The texture's neck opening ends 20.5% from its top. Map that point just below the chin.
    static func draw(in c: CGContext, pose: CostumePose, texture: CGImage) {
        c.saveGState(); c.concatenate(pose.transform)
        c.interpolationQuality = .high
        let width: CGFloat = 2.7
        c.draw(texture, in: CGRect(x: -width / 2, y: -width * 0.795, width: width, height: width))
        c.restoreGState()
    }
}
