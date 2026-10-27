import CoreGraphics
import CoreImage

/// Original, layered costume artwork. Generated once, then fitted on the GPU each frame.
enum HeroArtwork {
    static let headBounds = CGRect(x: 0, y: 0, width: 768, height: 1024)
    static let leftEye = CGPoint(x: 252, y: 512)
    static let rightEye = CGPoint(x: 516, y: 512)
    static let chin = CGPoint(x: 384, y: 195.2)

    static func cowl() -> CIImage {
        SceneCanvas.image(bounds: headBounds) { c in
            c.translateBy(x: 384, y: 512)
            c.scaleBy(x: 528, y: 440)
            let outer = silhouette()
            c.saveGState()
            c.addPath(outer)
            c.clip()
            c.draw(rubber, in: CGRect(x: -384.0 / 528, y: -512.0 / 440, width: 768.0 / 528, height: 1024.0 / 440))
            c.restoreGState()
            for side in [-1.0, 1.0] {
                c.saveGState()
                c.scaleBy(x: side, y: 1)
                shade(
                    polygon([(0.37, 0.53), (0.55, 1.02), (0.52, 0.34), (0.46, 0.16)]), in: c,
                    colors: [0x344452, 0x1B2530, 0x090F17], from: CGPoint(x: 0.39, y: 0.7), to: CGPoint(x: 0.55, y: 0.6)
                )
                let brow = CGMutablePath()
                brow.move(to: CGPoint(x: 0.09, y: 0.07))
                brow.addCurve(
                    to: CGPoint(x: 0.47, y: 0.13), control1: CGPoint(x: 0.19, y: 0.19),
                    control2: CGPoint(x: 0.36, y: 0.20))
                brow.addQuadCurve(to: CGPoint(x: 0.40, y: 0.03), control: CGPoint(x: 0.48, y: 0.06))
                brow.addQuadCurve(to: CGPoint(x: 0.09, y: 0.01), control: CGPoint(x: 0.22, y: 0.07))
                brow.closeSubpath()
                shade(
                    brow, in: c, colors: [0x394957, 0x111923, 0x05090E], from: CGPoint(x: 0.27, y: 0.18),
                    to: CGPoint(x: 0.27, y: 0.01))
                let cheek = CGMutablePath()
                cheek.move(to: CGPoint(x: 0.45, y: -0.05))
                cheek.addQuadCurve(to: CGPoint(x: 0.49, y: -0.35), control: CGPoint(x: 0.53, y: -0.15))
                cheek.addLine(to: CGPoint(x: 0.31, y: -0.62))
                cheek.addLine(to: CGPoint(x: 0.31, y: -0.29))
                cheek.addLine(to: CGPoint(x: 0.19, y: -0.15))
                cheek.closeSubpath()
                shade(
                    cheek, in: c, colors: [0x273542, 0x101923, 0x070D14], from: CGPoint(x: 0.29, y: -0.06),
                    to: CGPoint(x: 0.45, y: -0.5))
                stroke(
                    polygon([(0.47, -0.12), (0.41, -0.33), (0.34, -0.51)]), in: c, color: 0x81909C, alpha: 0.13,
                    width: 0.003)
                c.restoreGState()
            }
            // The raised center ridge and bridge give the mask a strong three-dimensional read.
            shade(
                polygon([
                    (-0.035, 0.19), (0.025, 0.19), (0.07, 0.03), (0.14, -0.24), (0, -0.31), (-0.14, -0.24),
                    (-0.07, 0.03),
                ]), in: c,
                colors: [0x435363, 0x253341, 0x0C141E], from: CGPoint(x: -0.08, y: 0), to: CGPoint(x: 0.10, y: 0))
            stroke(outer, in: c, color: 0x899BAA, alpha: 0.2, width: 0.002)
            // Neck ribs remain part of the cowl, hiding the real shirt and hair completely.
            for row in 0..<3 {
                let y = -0.77 - CGFloat(row) * 0.027
                let p = CGMutablePath()
                p.move(to: CGPoint(x: -0.28, y: y))
                p.addQuadCurve(to: CGPoint(x: 0.28, y: y), control: CGPoint(x: 0, y: y - 0.045))
                stroke(p, in: c, color: 0x70808E, alpha: 0.18, width: 0.006)
            }
            c.setBlendMode(.clear)
            c.addPath(apertures())
            c.fillPath()
        }
    }

    static func faceMask() -> CIImage {
        SceneCanvas.image(bounds: headBounds) { c in
            c.setFillColor(CGColor(gray: 0, alpha: 1))
            c.fill(headBounds)
            c.translateBy(x: 384, y: 512)
            c.scaleBy(x: 528, y: 440)
            c.setFillColor(CGColor(gray: 1, alpha: 1))
            c.addPath(apertures())
            c.fillPath()
        }
    }

    private static func silhouette() -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -0.30, y: -0.86))
        p.addLine(to: CGPoint(x: -0.39, y: -0.66))
        p.addCurve(
            to: CGPoint(x: -0.57, y: 0.18), control1: CGPoint(x: -0.58, y: -0.43), control2: CGPoint(x: -0.60, y: -0.06)
        )
        p.addLine(to: CGPoint(x: -0.55, y: 1.02))
        p.addLine(to: CGPoint(x: -0.35, y: 0.53))
        p.addCurve(
            to: CGPoint(x: 0.35, y: 0.53), control1: CGPoint(x: -0.21, y: 0.66), control2: CGPoint(x: 0.21, y: 0.66))
        p.addLine(to: CGPoint(x: 0.55, y: 1.02))
        p.addLine(to: CGPoint(x: 0.57, y: 0.18))
        p.addCurve(
            to: CGPoint(x: 0.39, y: -0.66), control1: CGPoint(x: 0.60, y: -0.06), control2: CGPoint(x: 0.58, y: -0.43))
        p.addLine(to: CGPoint(x: 0.30, y: -0.86))
        p.addQuadCurve(to: CGPoint(x: -0.30, y: -0.86), control: CGPoint(x: 0, y: -0.92))
        p.closeSubpath()
        return p
    }

    private static func apertures() -> CGPath {
        let p = CGMutablePath()
        for side in [-1.0, 1.0] {
            var t = CGAffineTransform(scaleX: side, y: 1)
            let eye = CGMutablePath()
            eye.move(to: CGPoint(x: 0.10, y: -0.025))
            eye.addCurve(
                to: CGPoint(x: 0.405, y: 0.025), control1: CGPoint(x: 0.17, y: 0.085),
                control2: CGPoint(x: 0.31, y: 0.09))
            eye.addCurve(
                to: CGPoint(x: 0.10, y: -0.025), control1: CGPoint(x: 0.33, y: -0.09),
                control2: CGPoint(x: 0.20, y: -0.095))
            eye.closeSubpath()
            p.addPath(eye.copy(using: &t)!)
        }
        p.move(to: CGPoint(x: -0.29, y: -0.27))
        p.addQuadCurve(to: CGPoint(x: 0, y: -0.33), control: CGPoint(x: -0.12, y: -0.28))
        p.addQuadCurve(to: CGPoint(x: 0.29, y: -0.27), control: CGPoint(x: 0.12, y: -0.28))
        p.addLine(to: CGPoint(x: 0.295, y: -0.50))
        p.addCurve(
            to: CGPoint(x: 0, y: -0.74), control1: CGPoint(x: 0.23, y: -0.66), control2: CGPoint(x: 0.11, y: -0.74))
        p.addCurve(
            to: CGPoint(x: -0.295, y: -0.50), control1: CGPoint(x: -0.11, y: -0.74),
            control2: CGPoint(x: -0.23, y: -0.66))
        p.closeSubpath()
        return p
    }

    static func suit() -> CIImage {
        let bounds = CGRect(x: 0, y: 0, width: 1024, height: 1024)
        return SceneCanvas.image(bounds: bounds) { c in
            let cape = CGMutablePath()
            cape.move(to: CGPoint(x: 400, y: 838))
            cape.addCurve(
                to: CGPoint(x: 25, y: 570), control1: CGPoint(x: 210, y: 818), control2: CGPoint(x: 76, y: 737))
            cape.addLine(to: CGPoint(x: 0, y: 0))
            cape.addLine(to: CGPoint(x: 1024, y: 0))
            cape.addLine(to: CGPoint(x: 999, y: 570))
            cape.addCurve(
                to: CGPoint(x: 624, y: 838), control1: CGPoint(x: 948, y: 737), control2: CGPoint(x: 814, y: 818))
            cape.closeSubpath()
            shade(
                cape, in: c, colors: [0x26303B, 0x0E141D, 0x070A10], from: CGPoint(x: 180, y: 850),
                to: CGPoint(x: 920, y: 0))
            c.saveGState()
            c.addPath(cape)
            c.clip()
            for i in 0..<18 {
                let left = i < 9
                let n = CGFloat(i % 9)
                let top = left ? 365 - n * 22 : 659 + n * 22
                let bottom = left ? n * 30 - 40 : 1064 - n * 30
                let fold = CGMutablePath()
                fold.move(to: CGPoint(x: top, y: 815 - n * 8))
                fold.addCurve(
                    to: CGPoint(x: bottom, y: -30), control1: CGPoint(x: top + (left ? -110 : 110), y: 550),
                    control2: CGPoint(x: bottom + 15, y: 180))
                fold.addLine(to: CGPoint(x: bottom + 28, y: -30))
                fold.addCurve(
                    to: CGPoint(x: top, y: 815 - n * 8), control1: CGPoint(x: bottom + 42, y: 240),
                    control2: CGPoint(x: top + (left ? -76 : 76), y: 580))
                shade(
                    fold, in: c, colors: [0x536171, 0x1A2533, 0x080C12], from: CGPoint(x: bottom, y: 300),
                    to: CGPoint(x: bottom + 32, y: 300))
            }
            c.restoreGState()
            let body = polygon([
                (408, 845), (302, 795), (185, 738), (164, 607), (255, 465), (283, 0), (741, 0), (769, 465), (860, 607),
                (839, 738), (722, 795), (616, 845), (590, 798), (434, 798),
            ])
            shade(
                body, in: c, colors: [0x3D4854, 0x202A35, 0x101721], from: CGPoint(x: 300, y: 850),
                to: CGPoint(x: 700, y: 80))
            c.saveGState()
            c.addPath(body)
            c.clip()
            grain(in: c, bounds: bounds, count: 18000, size: 0.7)
            c.restoreGState()
            for side in [-1.0, 1.0] {
                c.saveGState()
                c.translateBy(x: 512, y: 0)
                c.scaleBy(x: side, y: 1)
                armor(polygon([(14, 778), (104, 802), (208, 747), (231, 663), (169, 584), (20, 594), (7, 688)]), in: c)
                armor(polygon([(220, 756), (326, 723), (351, 647), (302, 590), (246, 632)]), in: c)
                armor(polygon([(242, 621), (299, 575), (284, 429), (246, 367), (213, 489)]), in: c)
                for row in 0..<4 {
                    let y = CGFloat(529 - row * 92)
                    armor(polygon([(16, y + 33), (126, y + 42), (158, y - 13), (117, y - 44), (13, y - 37)]), in: c)
                    shade(
                        polygon([(150, y + 20), (207, y + 44), (210, y - 12), (172, y - 48), (140, y - 32)]), in: c,
                        colors: [0x253342, 0x111923], from: CGPoint(x: 150, y: y), to: CGPoint(x: 210, y: y - 20))
                }
                c.restoreGState()
            }
            let emblem = polygon([
                (291, 663), (403, 633), (457, 640), (480, 679), (496, 650), (528, 650), (544, 679), (567, 640),
                (621, 633), (733, 663), (673, 586), (628, 609), (591, 570), (559, 595), (512, 549), (465, 595),
                (433, 570), (396, 609), (351, 586),
            ])
            c.saveGState()
            c.setShadow(offset: CGSize(width: 0, height: -4), blur: 7, color: CGColor(gray: 0, alpha: 0.75))
            shade(
                emblem, in: c, colors: [0x101720, 0x04070B], from: CGPoint(x: 512, y: 675), to: CGPoint(x: 512, y: 550))
            c.restoreGState()
            stroke(emblem, in: c, color: 0x76828D, alpha: 0.38, width: 1.5)
            let belt = CGPath(
                roundedRect: CGRect(x: 291, y: 71, width: 442, height: 73), cornerWidth: 16, cornerHeight: 16,
                transform: nil)
            shade(
                belt, in: c, colors: [0xA29668, 0x6F6241, 0x3F3728], from: CGPoint(x: 500, y: 145),
                to: CGPoint(x: 500, y: 70))
            for x in [312, 369, 601, 658] {
                let pouch = CGPath(
                    roundedRect: CGRect(x: x, y: 68, width: 48, height: 81), cornerWidth: 7, cornerHeight: 7,
                    transform: nil)
                shade(
                    pouch, in: c, colors: [0x8C805B, 0x514730], from: CGPoint(x: x, y: 145),
                    to: CGPoint(x: x + 35, y: 70))
                stroke(pouch, in: c, color: 0xB2A779, alpha: 0.5, width: 2)
            }
            let buckle = polygon([(463, 147), (561, 147), (579, 112), (559, 71), (465, 71), (445, 112)])
            shade(
                buckle, in: c, colors: [0xB3A77A, 0x685A3B], from: CGPoint(x: 490, y: 147), to: CGPoint(x: 535, y: 71))
            stroke(buckle, in: c, color: 0xD1C599, alpha: 0.55, width: 2)
        }
    }

    private static func armor(_ path: CGPath, in c: CGContext) {
        let r = path.boundingBoxOfPath
        c.saveGState()
        c.setShadow(offset: CGSize(width: 0, height: -5), blur: 8, color: CGColor(gray: 0, alpha: 0.7))
        shade(
            path, in: c, colors: [0x3B4957, 0x24313F, 0x111C29], from: CGPoint(x: r.minX, y: r.maxY),
            to: CGPoint(x: r.maxX, y: r.minY))
        c.restoreGState()
        stroke(path, in: c, color: 0x8A98A5, alpha: 0.22, width: 1.3)
        c.saveGState()
        c.addPath(path)
        c.clip()
        grain(in: c, bounds: r, count: 1800, size: 0.8)
        c.restoreGState()
    }

    /// A rounded height field supplies soft rubber lighting beneath the sculpted details.
    private static let rubber: CGImage = {
        let width = 768
        let height = 1024
        var data = [UInt8](repeating: 255, count: width * height * 4)
        func smooth(_ lo: Double, _ hi: Double, _ value: Double) -> Double {
            let p = max(0, min(1, (value - lo) / (hi - lo)))
            return p * p * (3 - 2 * p)
        }
        func surface(_ x: Double, _ y: Double) -> Double {
            let radius = 0.56 - 0.07 * smooth(0.2, 0.7, y)
            let round = sqrt(max(0.01, 1 - pow(x / radius, 2)))
            let crown = 1 - 0.30 * smooth(0.22, 0.68, y)
            let ridge = 0.035 * exp(-x * x / 0.003) * (1 - smooth(0.45, 0.65, y)) * smooth(-0.15, 0.15, y)
            let brow = 0.035 * exp(-pow(y - 0.1 - abs(x) * 0.08, 2) / 0.002)
            return 0.34 * round * crown + ridge + brow
        }
        for row in 0..<height {
            let y = (Double(height - 1 - row) - 512) / 440
            for col in 0..<width {
                let x = (Double(col) - 384) / 528
                let e = 0.003
                let dx = (surface(x + e, y) - surface(x - e, y)) / (2 * e)
                let dy = (surface(x, y + e) - surface(x, y - e)) / (2 * e)
                let length = sqrt(dx * dx + dy * dy + 1)
                let nx = -dx / length
                let ny = -dy / length
                let nz = 1 / length
                let diffuse = max(0, nx * -0.48 + ny * 0.60 + nz * 0.64)
                let specular = pow(max(0, nx * -0.267 + ny * 0.334 + nz * 0.904), 32)
                let noise = Double((col * 73 + row * 137 + col * row * 11) % 101) / 100 - 0.5
                let value = 0.025 + diffuse * 0.105 + specular * 0.08 + noise * 0.012
                let index = (row * width + col) * 4
                data[index] = UInt8(max(0, min(255, value * 0.88 * 255)))
                data[index + 1] = UInt8(max(0, min(255, value * 0.98 * 255)))
                data[index + 2] = UInt8(max(0, min(255, value * 1.12 * 255)))
            }
        }
        let provider = CGDataProvider(data: Data(data) as CFData)!
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider,
            decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    }()

    private static func grain(in c: CGContext, bounds: CGRect, count: Int, size: CGFloat) {
        var seed: UInt64 = 0x16b0f3
        func unit() -> CGFloat {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return CGFloat(seed >> 40) / CGFloat(1 << 24)
        }
        for i in 0..<count {
            let x = bounds.minX + unit() * bounds.width
            let y = bounds.minY + unit() * bounds.height
            c.setFillColor(CGColor(gray: i % 2 == 0 ? 1 : 0, alpha: i % 2 == 0 ? 0.06 : 0.1))
            c.fill(CGRect(x: x, y: y, width: size, height: size))
        }
    }
    private static func polygon(_ points: [(CGFloat, CGFloat)]) -> CGPath {
        let p = CGMutablePath()
        p.addLines(between: points.map { CGPoint(x: $0.0, y: $0.1) })
        p.closeSubpath()
        return p
    }
    private static func color(_ hex: Int, _ alpha: CGFloat = 1) -> CGColor {
        CGColor(
            red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
    }
    private static func shade(_ path: CGPath, in c: CGContext, colors: [Int], from: CGPoint, to: CGPoint) {
        c.saveGState()
        c.addPath(path)
        c.clip()
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map { color($0) } as CFArray, locations: nil)!
        c.drawLinearGradient(
            gradient, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        c.restoreGState()
    }
    private static func stroke(_ path: CGPath, in c: CGContext, color hex: Int, alpha: CGFloat, width: CGFloat) {
        c.setStrokeColor(color(hex, alpha))
        c.setLineWidth(width)
        c.addPath(path)
        c.strokePath()
    }
}
