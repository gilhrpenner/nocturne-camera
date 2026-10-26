import CoreImage
import CoreGraphics

enum SceneCanvas {
    static func image(bounds: CGRect, transform: CGAffineTransform = .identity, draw: (CGContext) -> Void) -> CIImage {
        let c = CGContext(data: nil, width: Int(bounds.width), height: Int(bounds.height), bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.concatenate(transform); draw(c)
        return CIImage(cgImage: c.makeImage()!)
    }

    static func fill(_ image: CIImage, bounds: CGRect) -> CIImage {
        let scale = max(bounds.width / image.extent.width, bounds.height / image.extent.height)
        let result = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return result.transformed(by: CGAffineTransform(translationX: bounds.midX - result.extent.midX,
            y: bounds.midY - result.extent.midY)).cropped(to: bounds)
    }
}
