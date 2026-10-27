import CoreGraphics
import CoreImage

struct CowlPose {
    let leftEye: CGPoint
    let rightEye: CGPoint
    let chin: CGPoint

    var transform: CGAffineTransform {
        let referenceCenter = midpoint(HeroArtwork.leftEye, HeroArtwork.rightEye)
        let referenceWidth = HeroArtwork.rightEye.x - HeroArtwork.leftEye.x
        let referenceHeight = referenceCenter.y - HeroArtwork.chin.y
        let across = CGPoint(x: (rightEye.x - leftEye.x) / referenceWidth, y: (rightEye.y - leftEye.y) / referenceWidth)
        let center = midpoint(leftEye, rightEye)
        let up = CGPoint(x: (center.x - chin.x) / referenceHeight, y: (center.y - chin.y) / referenceHeight)
        return CGAffineTransform(
            a: across.x, b: across.y, c: up.x, d: up.y,
            tx: center.x - across.x * referenceCenter.x - up.x * referenceCenter.y,
            ty: center.y - across.y * referenceCenter.x - up.y * referenceCenter.y)
    }

    static func make(eyes: [CGPoint], face: FaceAnchor) -> Self {
        let sorted = eyes.sorted { $0.x < $1.x }
        if sorted.count == 2, distance(sorted[0], sorted[1]) > face.bounds.width * 0.18 {
            return Self(leftEye: sorted[0], rightEye: sorted[1], chin: face.chin)
        }
        return Self(
            leftEye: CGPoint(
                x: face.bounds.midX - face.bounds.width * 0.22, y: face.bounds.minY + face.bounds.height * 0.68),
            rightEye: CGPoint(
                x: face.bounds.midX + face.bounds.width * 0.22, y: face.bounds.minY + face.bounds.height * 0.68),
            chin: face.chin)
    }
}

final class HeroCostume {
    let suit = HeroArtwork.suit()
    private let cowl = HeroArtwork.cowl()
    private let faceMask = HeroArtwork.faceMask()
    private var previous: CowlPose?
    private var previousTime = -Double.infinity

    func reset() {
        previous = nil
        previousTime = -.infinity
    }

    func stabilized(_ pose: CowlPose, at time: Double) -> CowlPose {
        defer { previousTime = time }
        guard let old = previous, time > previousTime, time - previousTime < 0.35,
            distance(old.chin, pose.chin) < distance(pose.leftEye, pose.rightEye) * 0.9
        else {
            previous = pose
            return pose
        }
        let motion = max(distance(old.leftEye, pose.leftEye), distance(old.chin, pose.chin))
        let tau = motion > 3 ? 0.035 : 0.065
        let amount = 1 - exp(-(time - previousTime) / tau)
        let next = CowlPose(
            leftEye: blend(old.leftEye, pose.leftEye, amount), rightEye: blend(old.rightEye, pose.rightEye, amount),
            chin: blend(old.chin, pose.chin, amount))
        previous = next
        return next
    }

    /// Only the real eyes and lower face remain; hair, ears, neck and torso cannot leak around the cowl.
    func dressed(
        subject: CIImage, personMask: CIImage, garment: CIImage, pose: CowlPose,
        placement: CGAffineTransform, bounds: CGRect
    ) -> CIImage {
        let transform = pose.transform.concatenating(placement)
        let mask = faceMask.transformed(by: transform).cropped(to: bounds)
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: personMask])
        let face = subject.applyingFilter(
            "CIBlendWithMask",
            parameters: [
                kCIInputBackgroundImageKey: CIImage(color: .clear).cropped(to: bounds), kCIInputMaskImageKey: mask,
            ])
        return cowl.transformed(by: transform).composited(over: face.composited(over: garment)).cropped(to: bounds)
    }
}
