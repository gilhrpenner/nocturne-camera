import AppKit
import CoreImage

@main struct HeadTreatmentTests {
    static func main() {
        let context = CIContext()
        let bounds = CGRect(x: 0, y: 0, width: 256, height: 256)
        let pose = HeadPose(face: CGRect(x: 80, y: 70, width: 100, height: 100), browY: 155, angle: 0)
        let treatment = HeadTreatment()
        let skin = CIImage(color: CIColor(red: 0.72, green: 0.47, blue: 0.32)).cropped(to: bounds)
        let white = CIImage(color: .white).cropped(to: bounds)
        let black = CIImage(color: .black).cropped(to: bounds)
        func render(_ image: CIImage, mask: CIImage = white, intensity: Double = 0,
            style: HairStyle = .natural, amount: Double = 1) -> CIImage {
            treatment.apply(to: image, personMask: mask, pose: pose, intensity: intensity,
                hairStyle: style, hairAmount: amount, bounds: bounds)
        }
        func pixel(_ image: CIImage, _ x: Int, _ y: Int) -> [UInt8] {
            var result = [UInt8](repeating: 0, count: 4)
            context.render(image, toBitmap: &result, rowBytes: 4, bounds: CGRect(x: x, y: y, width: 1, height: 1),
                format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
            return result
        }
        let pale = render(skin, intensity: 1)
        for (name, x, y) in [("forehead", 130, 183), ("cheek", 165, 110), ("ear", 188, 125), ("neck", 130, 30)] {
            let before = pixel(skin, x, y), after = pixel(pale, x, y)
            precondition(Int(after[0]) - Int(after[2]) < Int(before[0]) - Int(before[2]) - 10, "Pale treatment must cover \(name)")
        }
        precondition(pixel(pale, 8, 8) == pixel(skin, 8, 8), "Coverage must not affect distant background")
        precondition(pixel(render(skin, mask: black, intensity: 1, style: .silver), 130, 183) == pixel(skin, 130, 183), "Person mask must protect the room")
        precondition(pixel(render(skin), 130, 120) == pixel(skin, 130, 120), "Natural hair and zero makeup must preserve input")
        let brown = CIImage(color: CIColor(red: 0.24, green: 0.16, blue: 0.09))
        let hair = brown.cropped(to: CGRect(x: 80, y: 200, width: 100, height: 30))
            .composited(over: brown.cropped(to: CGRect(x: 80, y: 165, width: 14, height: 40)).composited(over: skin))
        let dark = render(hair, style: .black), silver = render(hair, style: .silver), temples = render(hair, style: .silverTemples)
        precondition(pixel(dark, 130, 210)[0] < pixel(hair, 130, 210)[0], "Deep black must darken hair")
        precondition(pixel(silver, 130, 210)[0] > pixel(dark, 130, 210)[0] + 20, "Silver must differ visibly from black")
        let warmCrown = CIImage(color: CIColor(red: 0.65, green: 0.45, blue: 0.25))
            .cropped(to: CGRect(x: 80, y: 200, width: 100, height: 30)).composited(over: skin)
        let tintedCrown = pixel(render(warmCrown, style: .black), 130, 210)
        precondition(abs(Int(tintedCrown[0]) - Int(tintedCrown[2])) < 10, "Warm crown highlights must become neutral, not stay brown")
        precondition(pixel(temples, 86, 183)[0] > pixel(dark, 86, 183)[0] + 10, "Temples must carry silver highlights")
        let foreheadBefore = pixel(hair, 130, 180), foreheadAfter = pixel(dark, 130, 180)
        precondition(zip(foreheadBefore, foreheadAfter).allSatisfy { abs(Int($0) - Int($1)) <= 2 }, "Hair tint must protect the bright warm forehead")
        precondition(pixel(render(hair, style: .silver, amount: 0), 130, 210) == pixel(hair, 130, 210), "Zero hair strength must preserve hair")
        print("PASS: forehead/cheek/ear/neck coverage, room isolation, hair tones, silver temples, forehead protection, zero-strength bypass")
    }
}
