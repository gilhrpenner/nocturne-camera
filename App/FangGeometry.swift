import CoreGraphics

struct Fang {
    let rootLeft: CGPoint
    let rootRight: CGPoint
    let tip: CGPoint

    var rootCenter: CGPoint {
        CGPoint(x: (rootLeft.x + rootRight.x) / 2, y: (rootLeft.y + rootRight.y) / 2)
    }
}

enum FangGeometry {
    static func make(inner: [CGPoint], outer: [CGPoint], faceAxis: CGVector) -> [Fang] {
        guard outer.count >= 6, (inner + outer).allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return [] }
        let axisLength = hypot(faceAxis.dx, faceAxis.dy)
        guard axisLength > 0 else { return [] }
        let faceX = CGVector(dx: faceAxis.dx / axisLength, dy: faceAxis.dy / axisLength)
        func projection(_ p: CGPoint) -> CGFloat { p.x * faceX.dx + p.y * faceX.dy }
        // The inner contour excludes the corners. Use the OUTER contour to find full
        // mouth width and the actual mouth angle, with the eye line disambiguating tilt.
        let left = outer.min { projection($0) < projection($1) }!
        let right = outer.max { projection($0) < projection($1) }!
        let width = hypot(right.x - left.x, right.y - left.y)
        guard width > 2 else { return [] }
        let xAxis = CGVector(dx: (right.x - left.x) / width, dy: (right.y - left.y) / width)
        let yAxis = CGVector(dx: -xAxis.dy, dy: xAxis.dx)
        func local(_ p: CGPoint) -> CGPoint {
            let dx = p.x - left.x, dy = p.y - left.y
            return CGPoint(x: dx * xAxis.dx + dy * xAxis.dy, y: dx * yAxis.dx + dy * yAxis.dy)
        }
        func image(_ p: CGPoint) -> CGPoint {
            CGPoint(x: left.x + p.x * xAxis.dx + p.y * yAxis.dx,
                y: left.y + p.x * xAxis.dy + p.y * yAxis.dy)
        }
        // Reconstruct the upper mouth seam through its corners. An upper hull ignores
        // the lower-lip samples; interpolation follows the seam instead of painting on it.
        let corners: [CGPoint] = [.zero, CGPoint(x: width, y: 0)]
        let localInner: [CGPoint] = inner.map { local($0) }
        let inRange = (corners + localInner).filter { $0.x >= 0 && $0.x <= width }
        let samples = inRange.sorted { a, b in
            if a.x == b.x { return a.y > b.y }
            return a.x < b.x
        }
        var upper: [CGPoint] = []
        for point in samples {
            if let previous = upper.last, abs(point.x - previous.x) < 0.0001 { continue }
            while upper.count >= 2 {
                let a = upper[upper.count - 2], b = upper[upper.count - 1]
                let turn = (b.x - a.x) * (point.y - a.y) - (b.y - a.y) * (point.x - a.x)
                if turn < 0 { break }
                upper.removeLast()
            }
            upper.append(point)
        }
        func seam(_ x: CGFloat) -> CGFloat {
            for i in 1..<upper.count where x <= upper[i].x {
                let a = upper[i - 1], b = upper[i]
                return a.y + (b.y - a.y) * (x - a.x) / max(0.0001, b.x - a.x)
            }
            return 0
        }
        // Deliberately visible with closed lips. Length depends on full mouth width,
        // never on opening height, and the lower lip does not clip the protruding tips.
        return [CGFloat(0.22), CGFloat(0.78)].map { fraction in
            let center = width * fraction
            let halfRoot = width * 0.06
            let inset = width * 0.012
            let rootLeft = CGPoint(x: center - halfRoot, y: seam(center - halfRoot) - inset)
            let rootRight = CGPoint(x: center + halfRoot, y: seam(center + halfRoot) - inset)
            let rootY = (rootLeft.y + rootRight.y) / 2
            let inward = width * (fraction < 0.5 ? 0.012 : -0.012)
            return Fang(rootLeft: image(rootLeft), rootRight: image(rootRight),
                tip: image(CGPoint(x: center + inward, y: rootY - width * 0.34)))
        }
    }
}
