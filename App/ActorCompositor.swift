import CoreImage
import CoreGraphics

enum ActorCompositor {
    /// The garment replaces the real torso completely. Only the head and neck use camera pixels.
    static func dressed(subject: CIImage, personMask: CIImage, garment: CIImage,
        headMask: CIImage, neckMask: CIImage, bounds: CGRect) -> CIImage {
        let clear = CIImage(color: .clear).cropped(to: bounds)
        func cutout(_ region: CIImage) -> CIImage {
            let mask = region.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: personMask])
            return subject.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: clear, kCIInputMaskImageKey: mask])
        }
        // The collar covers the neck naturally, while the face and hair remain in front of it.
        return cutout(headMask).composited(over: garment.composited(over: cutout(neckMask))).cropped(to: bounds)
    }
}
