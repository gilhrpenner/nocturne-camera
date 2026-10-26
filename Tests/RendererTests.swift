import AppKit
import CoreImage
import CoreMedia

@main
struct RendererTests {
    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let renderer = try SceneRenderer(assetURL: root.appendingPathComponent("Resources/castle.png"))
        var options = SceneOptions()
        options.bats = false; options.autoLightning = false
        let scene = try renderer.render(input: nil, options: options, time: 100)
        precondition(CVPixelBufferGetWidth(scene) == 1280 && CVPixelBufferGetHeight(scene) == 720)
        let dark = bytes(scene)
        options.distance = 1
        let distantBackground = bytes(try renderer.render(input: nil, options: options, time: 100))
        precondition(distantBackground == dark, "Distance must not zoom the castle")
        let far = SceneRenderer.subjectTransform(options: options, bounds: renderer.bounds)
        let nearPoint = CGPoint(x: 640, y: 500).applying(far)
        precondition(abs(far.a - 0.55) < 0.0001 && nearPoint.y > 500, "Distance must shrink the person and reveal more attire below")
        precondition(nearPoint.x == 640, "Distance must preserve horizontal center")
        options.costume = false
        let withoutAttire = SceneRenderer.subjectTransform(options: options, bounds: renderer.bounds)
        precondition(CGPoint(x: 640, y: 0).applying(withoutAttire).y == 0, "A real cropped torso must stay at the bottom edge")
        options.castle = false
        precondition(SceneRenderer.subjectTransform(options: options, bounds: renderer.bounds).isIdentity, "Distance needs the castle cutout")
        options.castle = true; options.costume = true; options.distance = 0
        options.lightningAt = 100
        let lit = bytes(try renderer.render(input: nil, options: options, time: 100))
        precondition(brightness(lit) > brightness(dark) * 1.4, "Lightning must illuminate the background")
        let faded = bytes(try renderer.render(input: nil, options: options, time: 101))
        precondition(faded == dark, "Lightning must return to the original scene")
        options.swarmAt = 102
        let bats = bytes(try renderer.render(input: nil, options: options, time: 103))
        precondition(bats != dark, "Bat cue must change the scene")
        options.vanishAt = 105
        precondition(options.isVanished(at: 106) && !options.isVanished(at: 108), "Vanish must expire after 3 seconds")
        options.normal = true
        options.distance = 1
        precondition(options.flash(at: 100) == 0 && !options.isVanished(at: 106), "Normal mode must suppress effects")
        var input: CVPixelBuffer?
        CVPixelBufferCreate(nil, 1280, 720, kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &input)
        renderer.context.render(CIImage(color: CIColor(red: 0.7, green: 0.3, blue: 0.1)), to: input!)
        let bypass = bytes(try renderer.render(input: input, options: options, time: 106))
        precondition(bypass == bytes(input!), "Normal camera must preserve input pixels")
        options.normal = false; options.vampire = false; options.swarmAt = -100
        let noPerson = bytes(try renderer.render(input: input, options: options, time: 110))
        precondition(noPerson != bytes(input!), "Empty-room input must not bypass the cutout")

        let cg = renderer.context.createCGImage(CIImage(cvPixelBuffer: scene), from: renderer.bounds)!
        let rep = NSBitmapImageRep(cgImage: cg)
        try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("build/scene-preview.png"))
        let sample = VideoFormat.sample(scene)!
        precondition(CMSampleBufferIsValid(sample))
        precondition(CMSampleBufferGetPresentationTimeStamp(sample).seconds > 0)
        print("PASS: 720p output, lightning/fade, bat cue, vanish expiry, distance placement/background preservation, normal bypass, cutout isolation, sample timing")
    }

    static func bytes(_ buffer: CVPixelBuffer) -> Data {
        CVPixelBufferLockBaseAddress(buffer, .readOnly); defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        return Data(bytes: CVPixelBufferGetBaseAddress(buffer)!, count: CVPixelBufferGetBytesPerRow(buffer) * CVPixelBufferGetHeight(buffer))
    }
    static func brightness(_ data: Data) -> Double {
        var sum: Double = 0
        data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            for i in stride(from: 0, to: bytes.count, by: 4) { sum += Double(bytes[i]) + Double(bytes[i + 1]) + Double(bytes[i + 2]) }
        }
        return sum
    }
}
