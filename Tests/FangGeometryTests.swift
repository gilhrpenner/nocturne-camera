import Foundation
import CoreGraphics

@main
struct FangGeometryTests {
    static func main() {
        // Vision's inner lip contour describes the central opening, excluding the corners.
        // Full mouth width is 100, central inner contour width is only 42.
        let outer: [CGPoint] = [CGPoint(x: -50, y: 0), CGPoint(x: -35, y: 10), CGPoint(x: -15, y: 15),
            CGPoint(x: 0, y: 12), CGPoint(x: 15, y: 15), CGPoint(x: 35, y: 10), CGPoint(x: 50, y: 0),
            CGPoint(x: 35, y: -16), CGPoint(x: 15, y: -25), CGPoint(x: 0, y: -27),
            CGPoint(x: -15, y: -25), CGPoint(x: -35, y: -16)]
        let open: [CGPoint] = [CGPoint(x: -21, y: 6), CGPoint(x: 0, y: 7), CGPoint(x: 21, y: 6),
            CGPoint(x: 21, y: -12), CGPoint(x: 0, y: -15), CGPoint(x: -21, y: -12)]
        let closed = open.map { CGPoint(x: $0.x, y: $0.y * 0.015) }
        var failures: [String] = []
        func check(_ condition: Bool, _ message: String) { if !condition { failures.append(message) } }
        let fangs = FangGeometry.make(inner: open, outer: outer, faceAxis: CGVector(dx: 1, dy: 0))
        check(fangs.count == 2, "An open mouth must have two fangs")
        if fangs.count == 2 {
            check(fangs[1].rootCenter.x - fangs[0].rootCenter.x >= 50,
                "Fangs attach at upper canines, not the narrow central inner-lip region")
            check(fangs.allSatisfy { $0.rootCenter.y - $0.tip.y >= 28 },
                "Theatrical fangs remain large relative to full mouth width")
            check(fangs.allSatisfy { $0.rootCenter.y < 6 },
                "Fang roots must start below the upper lip, not paint on it")
        }
        let closedFangs = FangGeometry.make(inner: closed, outer: outer, faceAxis: CGVector(dx: 1, dy: 0))
        check(closedFangs.count == 2,
            "Fangs must stay visible with the mouth closed")
        check(FangGeometry.make(inner: [], outer: outer, faceAxis: CGVector(dx: 1, dy: 0)).count == 2,
            "Missing inner-lip landmarks must fall back to the closed-mouth seam")
        check(FangGeometry.make(inner: open, outer: [], faceAxis: CGVector(dx: 1, dy: 0)).isEmpty,
            "No outer mouth landmarks must not draw floating fangs")
        let canvas = CGContext(data: nil, width: 200, height: 200, bitsPerComponent: 8, bytesPerRow: 800,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        canvas.translateBy(x: 100, y: 100)
        FangPainter.draw(closedFangs, in: canvas, opacity: 1)
        // The central body must actually be painted well BELOW the closed mouth seam.
        let painted = canvas.data!.assumingMemoryBound(to: UInt8.self)
        // Bitmap rows are top-down; the CGContext geometry is bottom-up.
        let fangPixel = ((200 - 1 - 80) * 200 + 72) * 4
        check(painted[fangPixel + 3] > 0, "Closed-mouth fang tips must render beyond the lips")
        let rotation = CGAffineTransform(rotationAngle: .pi / 6).translatedBy(x: 90, y: 50)
        let axis = CGVector(dx: cos(CGFloat.pi / 6), dy: sin(CGFloat.pi / 6))
        let tilted = FangGeometry.make(inner: open.map { $0.applying(rotation) },
            outer: outer.map { $0.applying(rotation) }, faceAxis: axis)
        check(tilted.count == fangs.count, "Head tilt must not drop a fang")
        for (normal, tilted) in zip(fangs, tilted) {
            for (a, b) in [(normal.rootLeft, tilted.rootLeft), (normal.rootRight, tilted.rootRight), (normal.tip, tilted.tip)] {
                let expected = a.applying(rotation)
                check(hypot(expected.x - b.x, expected.y - b.y) < 0.001, "Fangs must rotate with the mouth")
            }
        }
        if failures.isEmpty { print("PASS: canine placement, dramatic length, lip occlusion, closed mouth, head tilt") }
        else { failures.forEach { print("FAIL: \($0)") }; exit(1) }
    }
}
