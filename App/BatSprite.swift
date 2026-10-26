import CoreGraphics
import ImageIO
import Foundation

/// A photographic bat with independently hinged wings, bank and foreshortening.
final class BatSprite {
    private let left: CGImage
    private let right: CGImage
    private let body: CGImage
    private let silhouette: CGImage
    private let aspect: CGFloat

    init(url: URL) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 384,
                kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else {
            throw NSError(domain: "Nocturne", code: 9, userInfo: [NSLocalizedDescriptionKey: "The transformation bat artwork is missing. Reinstall Nocturne."])
        }
        let w = CGFloat(image.width), h = CGFloat(image.height)
        silhouette = image
        left = image.cropping(to: CGRect(x: 0, y: 0, width: ceil(w * 0.46), height: h))!
        right = image.cropping(to: CGRect(x: floor(w * 0.54), y: 0, width: ceil(w * 0.46), height: h))!
        body = image.cropping(to: CGRect(x: floor(w * 0.38), y: 0, width: ceil(w * 0.24), height: h))!
        aspect = h / w
    }

    func material(from fragment: CGImage) -> CGImage {
        let width = 192, height = Int(192 * aspect)
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        let c = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.draw(fragment, in: rect)
        c.setBlendMode(.destinationIn); c.draw(silhouette, in: rect)
        return c.makeImage()!
    }

    func drawMaterial(_ image: CGImage, in c: CGContext, point: CGPoint, span: CGFloat, fold: CGFloat, bank: CGFloat, opacity: CGFloat) {
        let h = span * aspect
        c.saveGState(); c.setAlpha(opacity)
        c.translateBy(x: point.x, y: point.y); c.rotate(by: bank)
        c.scaleBy(x: 1, y: 0.45 + fold * 0.55)
        c.draw(image, in: CGRect(x: -span * 0.5, y: -h * 0.60, width: span, height: h))
        c.restoreGState()
    }

    func draw(in c: CGContext, point: CGPoint, span: CGFloat, flap: CGFloat, bank: CGFloat, opacity: CGFloat) {
        let h = span * aspect
        c.saveGState(); c.setAlpha(opacity)
        c.translateBy(x: point.x, y: point.y); c.rotate(by: bank)
        c.scaleBy(x: 1 - abs(sin(bank)) * 0.22, y: 1)
        c.interpolationQuality = .medium
        for side: CGFloat in [-1, 1] {
            c.saveGState()
            let hinge = side * span * 0.09
            c.translateBy(x: hinge, y: 0)
            c.concatenate(CGAffineTransform(a: 1, b: side * flap * 0.35, c: 0,
                d: 0.38 + abs(flap) * 0.62, tx: 0, ty: 0))
            let x = side < 0 ? -span * 0.5 : span * 0.04
            c.draw(side < 0 ? left : right, in: CGRect(x: x - hinge, y: -h * 0.60, width: span * 0.46, height: h))
            c.restoreGState()
        }
        c.draw(body, in: CGRect(x: -span * 0.12, y: -h * 0.60, width: span * 0.24, height: h))
        c.restoreGState()
    }
}
