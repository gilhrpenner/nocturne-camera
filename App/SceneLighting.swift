import CoreImage
import CoreGraphics

enum SceneLighting {
    static func apply(to actor: CIImage, amount: Double, flash: Double, bounds: CGRect) -> CIImage {
        guard amount > 0 else { return actor }
        let strength = min(1, amount)
        var result = actor.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: (-0.24 + flash * 1.15) * strength])
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1 - strength * 0.16])
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1 - strength * 0.055, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 1 - strength * 0.015, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 1 + strength * 0.045, w: 0)])
        let alpha = actor.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 1), "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 1), "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 1)]).cropped(to: bounds)
        let inside = alpha.applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: 2.2])
            .applyingFilter("CIColorInvert")
        let edge = alpha.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: inside])
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.65])
        let direction = CIFilter(name: "CILinearGradient", parameters: [
            "inputPoint0": CIVector(x: bounds.width * 0.2, y: bounds.height * 0.9),
            "inputPoint1": CIVector(x: bounds.width * 0.85, y: bounds.height * 0.1),
            "inputColor0": CIColor(red: strength * 0.42, green: strength * 0.42, blue: strength * 0.42),
            "inputColor1": CIColor.black])!.outputImage!
        let rimMask = edge.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: direction])
        let rimColor = CIImage(color: CIColor(red: 0.42, green: 0.56, blue: 0.72)).cropped(to: bounds)
            .applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: result])
        result = rimColor.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: result, kCIInputMaskImageKey: rimMask])
        return result.cropped(to: bounds)
    }
}
