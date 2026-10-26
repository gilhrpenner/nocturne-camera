import CoreImage
import CoreGraphics

struct DissolveFragment {
    let polygon: [CGPoint]
    let rect: CGRect
    let origin: CGPoint
    let threshold: Double
    let seed: Int
    let texture: CGImage?
    var batTexture: CGImage?
}

enum DissolveMesh {
    /// Irregular Voronoi cells tile the image without a visible rectangular grid.
    static func capture(actor: CIImage, context: CIContext, bounds: CGRect) -> [DissolveFragment] {
        guard let snapshot = context.createCGImage(actor, from: bounds) else { return [] }
        let cols = 16, rows = 10, sampleWidth = 160, sampleHeight = 90
        var alpha = [UInt8](repeating: 0, count: sampleWidth * sampleHeight * 4)
        let small = actor.transformed(by: CGAffineTransform(translationX: -bounds.minX, y: -bounds.minY))
            .transformed(by: CGAffineTransform(scaleX: CGFloat(sampleWidth) / bounds.width, y: CGFloat(sampleHeight) / bounds.height))
        context.render(small, toBitmap: &alpha, rowBytes: sampleWidth * 4,
            bounds: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight), format: .RGBA8, colorSpace: nil)
        let cellW = bounds.width / CGFloat(cols), cellH = bounds.height / CGFloat(rows)
        var sites: [CGPoint] = []
        for y in 0..<rows { for x in 0..<cols {
            let seed = y * cols + x
            sites.append(CGPoint(x: bounds.minX + (CGFloat(x) + 0.5) * cellW + (Storm.random(seed, 151) - 0.5) * cellW * 0.78,
                y: bounds.minY + (CGFloat(y) + 0.5) * cellH + (Storm.random(seed, 152) - 0.5) * cellH * 0.78))
        } }
        var fragments: [DissolveFragment] = []
        for y in 0..<rows { for x in 0..<cols {
            let seed = y * cols + x
            var polygon = [CGPoint(x: bounds.minX, y: bounds.minY), CGPoint(x: bounds.maxX, y: bounds.minY),
                CGPoint(x: bounds.maxX, y: bounds.maxY), CGPoint(x: bounds.minX, y: bounds.maxY)]
            for ny in max(0, y - 2)...min(rows - 1, y + 2) { for nx in max(0, x - 2)...min(cols - 1, x + 2) {
                let neighbor = ny * cols + nx
                if neighbor != seed { polygon = clip(polygon, closerTo: sites[seed], than: sites[neighbor]) }
            } }
            let path = CGMutablePath(); path.addLines(between: polygon); path.closeSubpath()
            let rect = path.boundingBoxOfPath.integral.intersection(bounds)
            var total: CGFloat = 0, center = CGPoint.zero
            var opaquePoints: [CGPoint] = []
            let minX = max(0, Int((rect.minX - bounds.minX) / bounds.width * CGFloat(sampleWidth)))
            let maxX = min(sampleWidth - 1, Int((rect.maxX - bounds.minX) / bounds.width * CGFloat(sampleWidth)))
            let minY = max(0, Int((rect.minY - bounds.minY) / bounds.height * CGFloat(sampleHeight)))
            let maxY = min(sampleHeight - 1, Int((rect.maxY - bounds.minY) / bounds.height * CGFloat(sampleHeight)))
            for sy in minY...maxY { for sx in minX...maxX {
                let p = CGPoint(x: bounds.minX + (CGFloat(sx) + 0.5) / CGFloat(sampleWidth) * bounds.width,
                    y: bounds.minY + (CGFloat(sy) + 0.5) / CGFloat(sampleHeight) * bounds.height)
                // Bitmap rows run top-down; scene points run bottom-up.
                let a = CGFloat(alpha[((sampleHeight - 1 - sy) * sampleWidth + sx) * 4 + 3]) / 255
                if a > 0.15 && path.contains(p) {
                    total += a; center.x += p.x * a; center.y += p.y * a
                    if a > 0.8 { opaquePoints.append(p) }
                }
            } }
            let centroid = total > 0 ? CGPoint(x: center.x / total, y: center.y / total) : CGPoint(x: rect.midX, y: rect.midY)
            func squaredDistance(_ p: CGPoint) -> CGFloat { pow(p.x - centroid.x, 2) + pow(p.y - centroid.y, 2) }
            let origin = opaquePoints.min(by: { squaredDistance($0) < squaredDistance($1) }) ?? centroid
            let threshold = min(0.93, max(0.07, 0.10 + (1 - (origin.y - bounds.minY) / bounds.height) * 0.49 + Storm.random(seed, 153) * 0.28))
            var texture: CGImage?
            if !opaquePoints.isEmpty, let crop = snapshot.cropping(to: CGRect(x: rect.minX - bounds.minX,
                    y: bounds.maxY - rect.maxY, width: rect.width, height: rect.height)),
               let c = CGContext(data: nil, width: Int(rect.width), height: Int(rect.height), bitsPerComponent: 8,
                    bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                c.translateBy(x: -rect.minX, y: -rect.minY)
                c.addPath(path); c.clip(); c.draw(crop, in: rect)
                texture = c.makeImage()
            }
            fragments.append(DissolveFragment(polygon: polygon, rect: rect, origin: origin,
                threshold: threshold, seed: seed, texture: texture))
        } }
        return fragments
    }

    private static func clip(_ polygon: [CGPoint], closerTo home: CGPoint, than other: CGPoint) -> [CGPoint] {
        guard let last = polygon.last else { return [] }
        let nx = other.x - home.x, ny = other.y - home.y
        let limit = (other.x * other.x + other.y * other.y - home.x * home.x - home.y * home.y) / 2
        func value(_ p: CGPoint) -> CGFloat { p.x * nx + p.y * ny - limit }
        var output: [CGPoint] = [], previous = last, previousValue = value(last)
        for point in polygon {
            let currentValue = value(point)
            if (currentValue <= 0) != (previousValue <= 0) {
                let t = previousValue / (previousValue - currentValue)
                output.append(CGPoint(x: previous.x + (point.x - previous.x) * t, y: previous.y + (point.y - previous.y) * t))
            }
            if currentValue <= 0 { output.append(point) }
            previous = point; previousValue = currentValue
        }
        return output
    }
}
