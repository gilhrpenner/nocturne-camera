import CoreImage
import CoreGraphics

/// Seamless, layered cloud noise advects upward beneath a fixed height envelope.
final class Fog {
    private let clouds: CIImage
    private let context = CIContext(options: [.cacheIntermediates: true])
    private var cached: (time: Double, amount: Double, bounds: CGRect, image: CIImage)?

    init() {
        let size = 256
        func value(_ x: Int, _ y: Int, period: Int, octave: Int) -> Double {
            let x = (x % period + period) % period, y = (y % period + period) % period
            var hash = UInt64(x + y * period + octave * 2048 + 57)
            hash = (hash ^ (hash >> 30)) &* 0xBF58476D1CE4E5B9
            hash = (hash ^ (hash >> 27)) &* 0x94D049BB133111EB
            return Double((hash ^ (hash >> 31)) % 65536) / 65535
        }
        var pixels = [UInt8](repeating: 0, count: size * size)
        for y in 0..<size { for x in 0..<size {
            var sum = 0.0
            for (octave, weight) in [0.55, 0.27, 0.13, 0.05].enumerated() {
                let period = 4 << octave
                let px = Double(x) / Double(size) * Double(period), py = Double(y) / Double(size) * Double(period)
                let ix = Int(floor(px)), iy = Int(floor(py))
                let tx = px - Double(ix), ty = py - Double(iy)
                let sx = tx * tx * (3 - 2 * tx), sy = ty * ty * (3 - 2 * ty)
                let a = value(ix, iy, period: period, octave: octave), b = value(ix + 1, iy, period: period, octave: octave)
                let c = value(ix, iy + 1, period: period, octave: octave), d = value(ix + 1, iy + 1, period: period, octave: octave)
                sum += ((a + (b - a) * sx) * (1 - sy) + (c + (d - c) * sx) * sy) * weight
            }
            pixels[y * size + x] = UInt8(min(255, max(0, sum * 255)))
        } }
        let data = Data(pixels)
        let provider = CGDataProvider(data: data as CFData)!
        let image = CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: size,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
        clouds = CIImage(cgImage: image)
    }

    func image(amount: Double, time: Double, animated: Bool, bounds: CGRect) -> CIImage {
        guard amount > 0 else { return CIImage(color: .clear).cropped(to: bounds) }
        let t = animated ? floor(time * 15) / 15 : 0
        if let cached, cached.time == t, cached.amount == amount, cached.bounds == bounds { return cached.image }
        // Fog is deliberately soft: render at quarter resolution to keep camera latency low.
        let resolution: CGFloat = 0.25
        let workBounds = bounds.applying(CGAffineTransform(scaleX: resolution, y: resolution))
        func layer(sx: CGFloat, sy: CGFloat, dx: Double, dy: Double, weight: CGFloat) -> CIImage {
            let tile = clouds.transformed(by: CGAffineTransform(scaleX: sx * resolution, y: sy * resolution))
            let x = (t * dx * resolution).truncatingRemainder(dividingBy: tile.extent.width)
            let y = (t * dy * resolution).truncatingRemainder(dividingBy: tile.extent.height)
            return tile.applyingFilter("CIAffineTile")
                .transformed(by: CGAffineTransform(translationX: x, y: y))
                .applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: weight, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: weight, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: weight, w: 0)])
        }
        let billows = layer(sx: 6, sy: 2.5, dx: 5, dy: 12, weight: 0.65)
            .applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: layer(sx: 3.5, sy: 1.6, dx: -9, dy: 19, weight: 0.35)])
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 7 * resolution])
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 3, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 3, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 3, w: 0),
                "inputBiasVector": CIVector(x: 0.04, y: 0.04, z: 0.04, w: 0)])
            .applyingFilter("CIColorClamp")
        let density = min(1, amount) * 3.2
        let envelope = CIFilter(name: "CILinearGradient", parameters: [
            "inputPoint0": CIVector(x: 0, y: workBounds.minY), "inputPoint1": CIVector(x: 0, y: workBounds.minY + workBounds.height * 2 / 3),
            "inputColor0": CIColor.white, "inputColor1": CIColor.black])!.outputImage!
            .applyingFilter("CIColorPolynomial", parameters: [
                "inputRedCoefficients": CIVector(x: 0, y: 0, z: density, w: 0),
                "inputGreenCoefficients": CIVector(x: 0, y: 0, z: density, w: 0),
                "inputBlueCoefficients": CIVector(x: 0, y: 0, z: density, w: 0)])
        let mask = billows.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: envelope])
            .cropped(to: workBounds)
        // Cache an opaque mask, avoiding color fringes from quantized translucent pixels.
        guard let bitmap = context.createCGImage(mask, from: workBounds) else { return CIImage(color: .clear).cropped(to: bounds) }
        let fullMask = CIImage(cgImage: bitmap).transformed(by: CGAffineTransform(scaleX: 1 / resolution, y: 1 / resolution)).cropped(to: bounds)
        let fogColor = CIImage(color: CIColor(red: 0.56, green: 0.63, blue: 0.7)).cropped(to: bounds)
        let result = fogColor.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: CIImage(color: .clear).cropped(to: bounds), kCIInputMaskImageKey: fullMask])
        cached = (t, amount, bounds, result)
        return result
    }
}
