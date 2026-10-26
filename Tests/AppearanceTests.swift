import CoreImage
import CoreGraphics

@main struct AppearanceTests {
    static func main() {
        let context = CIContext(), bounds = CGRect(x: 0, y: 0, width: 200, height: 200)
        func pixel(_ image: CIImage, _ x: Int, _ y: Int) -> [UInt8] {
            var result = [UInt8](repeating: 0, count: 4)
            context.render(image, toBitmap: &result, rowBytes: 4, bounds: CGRect(x: x, y: y, width: 1, height: 1),
                format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
            return result
        }
        let black = CIImage(color: .black).cropped(to: bounds), white = CIImage(color: .white).cropped(to: bounds)
        let clear = CIImage(color: .clear).cropped(to: bounds)
        let camera = CIImage(color: CIColor(red: 0.8, green: 0.15, blue: 0.1)).cropped(to: bounds)
        let garment = CIImage(color: CIColor(red: 0.1, green: 0.15, blue: 0.8))
            .cropped(to: CGRect(x: 60, y: 0, width: 80, height: 70)).composited(over: clear)
        let head = CIImage(color: .white).cropped(to: CGRect(x: 70, y: 100, width: 60, height: 80)).composited(over: black)
        let neck = CIImage(color: .white).cropped(to: CGRect(x: 88, y: 40, width: 24, height: 70)).composited(over: black)
        let dressed = ActorCompositor.dressed(subject: camera, personMask: white, garment: garment, headMask: head, neckMask: neck, bounds: bounds)
        precondition(pixel(dressed, 30, 55)[3] == 0, "Real shoulders outside the garment must be completely removed")
        precondition(pixel(dressed, 100, 150) == pixel(camera, 100, 150), "The actual head must remain visible")
        precondition(pixel(dressed, 100, 85) == pixel(camera, 100, 85), "The neck must remain visible through the collar opening")
        precondition(pixel(dressed, 100, 50)[2] > pixel(dressed, 100, 50)[0] + 100, "The garment must cover the lower neck and torso")
        let hidden = ActorCompositor.dressed(subject: camera, personMask: black, garment: garment, headMask: head, neckMask: neck, bounds: bounds)
        precondition(pixel(hidden, 100, 150)[3] == 0, "Head isolation must still respect the person mask")

        let eye = [CGPoint(x: 60, y: 100), CGPoint(x: 75, y: 111), CGPoint(x: 100, y: 114),
            CGPoint(x: 125, y: 111), CGPoint(x: 140, y: 100), CGPoint(x: 125, y: 90), CGPoint(x: 100, y: 86), CGPoint(x: 75, y: 90)]
        let placement = VampireEye.make(outline: eye, pupil: CGPoint(x: 112, y: 101))!
        precondition(placement.center == CGPoint(x: 112, y: 101), "The iris must follow the detected pupil, not the eye bounding-box center")
        let invalid = VampireEye.make(outline: eye, pupil: CGPoint(x: 180, y: 150))!
        precondition(!invalid.pupilDetected && abs(invalid.center.x - 100) < 1, "Bad pupil observations must fall back inside the eye")
        let blink = eye.map { CGPoint(x: $0.x, y: 100 + ($0.y - 100) * 0.15) }
        precondition(VampireEye.make(outline: blink, pupil: .zero) == nil, "A closed eyelid must not receive a painted iris")
        let image = SceneCanvas.image(bounds: bounds) { VampireEyes.draw(placement, in: $0, intensity: 1) }
        precondition(pixel(image, 112, 101)[0] < 20, "The pupil must remain dark")
        let iris = pixel(image, 122, 101)
        precondition(iris[0] > iris[2] + 20, "The iris must have crimson color")
        precondition(pixel(image, 65, 100)[3] == 0 && pixel(image, 112, 125)[3] == 0, "The contacts must preserve sclera and stay inside the eyelids")
        let off = SceneCanvas.image(bounds: bounds) { VampireEyes.draw(placement, in: $0, intensity: 0) }
        precondition(pixel(off, 112, 101)[3] == 0, "Zero intensity must disable the contacts")
        print("PASS: real torso removed, head/neck retained, collar depth, person isolation, pupil alignment, blink protection, textured crimson eyes")
    }
}
