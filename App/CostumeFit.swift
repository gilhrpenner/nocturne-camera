import CoreGraphics
import CoreImage

struct CostumeFit {
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomLeft: CGPoint
    let bottomRight: CGPoint
    let neck: CGPoint
    let shoulderSpan: CGFloat
    let tracked: Bool

    static func make(body: TrackedBody, face: FaceAnchor, width: Double, lift: Double) -> CostumeFit {
        let a = body.shoulders[0], b = body.shoulders[1]
        let span = max(50, distance(a, b))
        let across = CGPoint(x: (b.x - a.x) / span, y: (b.y - a.y) / span)
        var up = CGPoint(x: -across.y, y: across.x)
        let shoulder = midpoint(a, b)
        let imageWidth = span / 0.70 * CGFloat(width)
        var imageHeight = imageWidth
        var bottomCenter = CGPoint(x: shoulder.x - up.x * imageHeight * 0.7, y: shoulder.y - up.y * imageHeight * 0.7)
        var bottomWidth = imageWidth
        if body.hips.count == 2 {
            let hip = midpoint(body.hips[0], body.hips[1]), length = distance(shoulder, hip)
            let hipSpan = distance(body.hips[0], body.hips[1])
            if length > span * 0.45 && length < span * 1.8 && hip.y < shoulder.y,
               hipSpan > span * 0.35 && hipSpan < span * 1.4 {
                up = CGPoint(x: (shoulder.x - hip.x) / length, y: (shoulder.y - hip.y) / length)
                imageHeight = min(imageWidth * 1.3, max(imageWidth * 0.8, length / 0.58))
                bottomCenter = CGPoint(x: shoulder.x - up.x * imageHeight * 0.7, y: shoulder.y - up.y * imageHeight * 0.7)
                bottomWidth = min(imageWidth * 1.1, max(imageWidth * 0.78, hipSpan / 0.62 * CGFloat(width)))
            }
        }
        let shift = CGFloat(lift) * face.bounds.height
        let topCenter = CGPoint(x: shoulder.x + up.x * (imageHeight * 0.3 + shift), y: shoulder.y + up.y * (imageHeight * 0.3 + shift))
        bottomCenter.x += up.x * shift; bottomCenter.y += up.y * shift
        func edge(_ center: CGPoint, _ half: CGFloat) -> CGPoint {
            CGPoint(x: center.x + across.x * half, y: center.y + across.y * half)
        }
        let neck = CGPoint(x: shoulder.x + up.x * (imageHeight * 0.095 + shift), y: shoulder.y + up.y * (imageHeight * 0.095 + shift))
        return CostumeFit(topLeft: edge(topCenter, -imageWidth / 2), topRight: edge(topCenter, imageWidth / 2),
            bottomLeft: edge(bottomCenter, -bottomWidth / 2), bottomRight: edge(bottomCenter, bottomWidth / 2),
            neck: neck, shoulderSpan: span, tracked: body.isTracked)
    }

    func image(texture: CIImage, placement: CGAffineTransform) -> CIImage {
        func vector(_ p: CGPoint) -> CIVector { let p = p.applying(placement); return CIVector(x: p.x, y: p.y) }
        return texture.applyingFilter("CIPerspectiveTransform", parameters: [
            "inputTopLeft": vector(topLeft), "inputTopRight": vector(topRight),
            "inputBottomLeft": vector(bottomLeft), "inputBottomRight": vector(bottomRight)])
    }
}
