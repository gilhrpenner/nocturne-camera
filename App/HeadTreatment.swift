import AppKit
import CoreImage

enum HairStyle: String, CaseIterable, Identifiable {
    case natural = "Natural"
    case silverTemples = "Black + silver temples"
    case silver = "Silver-gray"
    case white = "Icy white"
    case black = "Deep black"
    var id: String { rawValue }
}

struct HeadPose {
    let face: CGRect
    let browY: CGFloat
    let angle: CGFloat

    var transform: CGAffineTransform {
        CGAffineTransform(translationX: face.midX, y: face.midY).rotated(by: angle)
            .scaledBy(x: face.width, y: face.height)
    }
}

/// Color-selective, feathered regions preserve skin/hair texture without a replacement face or wig.
final class HeadTreatment {
    private let skinCube: Data
    private let hairCube: Data
    private let whiteHairCube: Data
    private let cubeSize = 32

    init() {
        var skin = [Float](), hair = [Float](), whiteHair = [Float]()
        for b in 0..<cubeSize { for g in 0..<cubeSize { for r in 0..<cubeSize {
            // Core Image evaluates the cube in linear light; classify perceptual colors.
            let red = pow(Double(r) / Double(cubeSize - 1), 1 / 2.2)
            let green = pow(Double(g) / Double(cubeSize - 1), 1 / 2.2)
            let blue = pow(Double(b) / Double(cubeSize - 1), 1 / 2.2)
            let light = red * 0.2126 + green * 0.7152 + blue * 0.0722
            let warm = Self.smooth(-0.025, 0.07, red - blue) * Self.smooth(-0.045, 0.035, red - green)
            let skinWeight = warm * Self.smooth(0.08, 0.32, light)
            let hairWeight = 1 - warm * Self.smooth(0.18, 0.45, light)
            // For a strong white tint, bright neutral forehead pixels need protection too.
            let whiteWeight = (1 - Self.smooth(0.4, 0.62, light)) * (1 - warm * Self.smooth(0.18, 0.36, light))
            skin.append(contentsOf: [Float(skinWeight), Float(skinWeight), Float(skinWeight), 1])
            hair.append(contentsOf: [Float(hairWeight), Float(hairWeight), Float(hairWeight), 1])
            whiteHair.append(contentsOf: [Float(whiteWeight), Float(whiteWeight), Float(whiteWeight), 1])
        } } }
        skinCube = skin.withUnsafeBytes { Data($0) }
        hairCube = hair.withUnsafeBytes { Data($0) }
        whiteHairCube = whiteHair.withUnsafeBytes { Data($0) }
    }

    private static func smooth(_ low: Double, _ high: Double, _ value: Double) -> Double {
        let t = min(1, max(0, (value - low) / (high - low)))
        return t * t * (3 - 2 * t)
    }

    private func region(bounds: CGRect, pose: HeadPose, draw: (CGContext) -> Void) -> CIImage {
        let c = CGContext(data: nil, width: Int(bounds.width), height: Int(bounds.height), bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.setFillColor(CGColor(gray: 0, alpha: 1)); c.fill(bounds)
        c.concatenate(pose.transform); c.setFillColor(CGColor(gray: 1, alpha: 1)); draw(c)
        return CIImage(cgImage: c.makeImage()!)
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: max(2, pose.face.width * 0.025)]).cropped(to: bounds)
    }

    private func multiply(_ a: CIImage, _ b: CIImage) -> CIImage {
        a.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: b])
    }

    func skinSelection(_ image: CIImage) -> CIImage {
        image.applyingFilter("CIColorCube", parameters: ["inputCubeDimension": cubeSize, "inputCubeData": skinCube])
    }

    func paleSkin(_ image: CIImage, intensity: Double) -> CIImage {
        image.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1 - intensity * 0.86,
            kCIInputBrightnessKey: intensity * 0.07, kCIInputContrastKey: 1 + intensity * 0.09])
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1 - intensity * 0.025, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 1 + intensity * 0.025, w: 0)])
    }

    func apply(to image: CIImage, personMask: CIImage, pose: HeadPose, intensity: Double,
        hairStyle: HairStyle, hairAmount: Double, bounds: CGRect) -> CIImage {
        var result = image
        if intensity > 0 {
            let skinRegion = region(bounds: bounds, pose: pose) { c in
                // Full forehead and jaw, both ears, and a tapered neck down to the shirt.
                c.fillEllipse(in: CGRect(x: -0.57, y: -0.56, width: 1.14, height: 1.31))
                for side: CGFloat in [-1, 1] {
                    c.fillEllipse(in: CGRect(x: side * 0.52 - 0.12, y: -0.23, width: 0.24, height: 0.6))
                }
                c.addLines(between: [CGPoint(x: -0.3, y: -0.32), CGPoint(x: 0.3, y: -0.32),
                    CGPoint(x: 0.4, y: -1.07), CGPoint(x: -0.4, y: -1.07)])
                c.closePath(); c.fillPath()
            }
            let skinColor = skinSelection(image)
            let mask = multiply(multiply(skinRegion, skinColor), personMask)
            let pale = paleSkin(image, intensity: intensity)
            result = pale.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: result, kCIInputMaskImageKey: mask])
        }
        if hairStyle != .natural && hairAmount > 0 {
            let brow = (pose.browY - pose.face.midY) / pose.face.height
            let hairRegion = region(bounds: bounds, pose: pose) { c in
                // Head geometry limits the color selection; bright warm forehead pixels are protected by hairCube.
                c.clip(to: CGRect(x: -0.7, y: brow + (hairStyle == .white ? 0.10 : 0.06), width: 1.4, height: 1.3))
                c.fillEllipse(in: CGRect(x: -0.6, y: -0.05, width: 1.2, height: 1.2))
            }
            let hairColor = image.applyingFilter("CIColorCube", parameters: ["inputCubeDimension": cubeSize,
                "inputCubeData": hairStyle == .white ? whiteHairCube : hairCube])
            let crown = region(bounds: bounds, pose: pose) { c in
                // Above the estimated hairline, retain blond/brown highlights in the treatment too.
                c.clip(to: CGRect(x: -0.7, y: brow + 0.34, width: 1.4, height: 1.3))
                c.fillEllipse(in: CGRect(x: -0.6, y: -0.05, width: 1.2, height: 1.2))
            }
            let selected = multiply(hairRegion, hairColor).applyingFilter("CIMaximumCompositing", parameters: [kCIInputBackgroundImageKey: crown])
            let mask = multiply(selected, personMask)
                .applyingFilter("CIColorMatrix", parameters: ["inputRVector": CIVector(x: hairAmount, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: hairAmount, z: 0, w: 0), "inputBVector": CIVector(x: 0, y: 0, z: hairAmount, w: 0)])
            let gray = image.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
            func tone(scale: CGFloat, bias: CGFloat, source: CIImage? = nil) -> CIImage {
                (source ?? gray).applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: scale * 0.95, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: scale, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: scale * 1.06, w: 0),
                    "inputBiasVector": CIVector(x: bias * 0.93, y: bias, z: bias * 1.08, w: 0)])
            }
            let dark = tone(scale: 0.4, bias: 0.015)
            let silver = tone(scale: 0.75, bias: 0.2)
            // Lift dark strands with a curve, keeping their contrast instead of adding a flat white veil.
            let lifted = gray.applyingFilter("CIGammaAdjust", parameters: ["inputPower": 0.38])
                .applyingFilter("CIUnsharpMask", parameters: [kCIInputRadiusKey: 1.8, kCIInputIntensityKey: 0.65])
            let white = tone(scale: 1.55, bias: 0.2, source: lifted)
            var colored = hairStyle == .white ? white : hairStyle == .silver ? silver : dark
            if hairStyle == .silverTemples {
                let temples = region(bounds: bounds, pose: pose) { c in
                    for side: CGFloat in [-1, 1] {
                        c.fillEllipse(in: CGRect(x: side * 0.46 - 0.085, y: brow - 0.04, width: 0.17, height: 0.51))
                    }
                }.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: pose.face.width * 0.035])
                colored = silver.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: dark, kCIInputMaskImageKey: temples])
            }
            result = colored.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: result, kCIInputMaskImageKey: mask])
        }
        return result.cropped(to: bounds)
    }
}
