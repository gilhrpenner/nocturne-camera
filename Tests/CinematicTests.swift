import CoreImage
import CoreGraphics

@main struct CinematicTests {
    static func main() throws {
        let tracker = BodyTracker()
        let face = FaceAnchor(bounds: CGRect(x: 270, y: 380, width: 100, height: 140), chin: CGPoint(x: 320, y: 380))
        let measurement = BodyMeasurement(shoulders: [CGPoint(x: 480, y: 345), CGPoint(x: 160, y: 335)],
            hips: [CGPoint(x: 200, y: 100), CGPoint(x: 440, y: 110)])
        tracker.update(measurement, face: face, at: 1)
        let body = tracker.resolve(face: face, at: 1)
        precondition(body.isTracked && body.shoulders[0].x < body.shoulders[1].x)
        let fit = CostumeFit.make(body: body, face: face, width: 1, lift: 0)
        let turnedFace = FaceAnchor(bounds: face.bounds.offsetBy(dx: 45, dy: 10), chin: CGPoint(x: 365, y: 390))
        let turnedFit = CostumeFit.make(body: tracker.resolve(face: turnedFace, at: 1), face: turnedFace, width: 1, lift: 0)
        precondition(fit.topLeft == turnedFit.topLeft && fit.bottomRight == turnedFit.bottomRight,
            "Head motion must not drag a tracked torso")
        precondition(fit.topRight.y > fit.topLeft.y && fit.bottomRight.y > fit.bottomLeft.y, "Shoulder roll must tilt the garment")
        precondition(fit.bottomLeft.x < fit.bottomRight.x && fit.topLeft.y > fit.bottomLeft.y, "Hip fitting must not invert the garment")
        let wide = CostumeFit.make(body: body, face: face, width: 1.2, lift: 0)
        precondition(distance(wide.topLeft, wide.topRight) > distance(fit.topLeft, fit.topRight) * 1.19)
        let raised = CostumeFit.make(body: body, face: face, width: 1, lift: 0.2)
        precondition(raised.neck.y > fit.neck.y + 20, "Collar adjustment must raise the neckline")
        var moving = measurement
        moving.shoulders = moving.shoulders.map { CGPoint(x: $0.x + 20, y: $0.y) }
        tracker.update(moving, face: face, at: 1.08)
        let moved = tracker.resolve(face: face, at: 1.16)
        let center = midpoint(moved.shoulders[0], moved.shoulders[1])
        precondition(center.x > 330 && center.x < 365, "Tracking must respond to sustained motion without a large jump")
        tracker.update(BodyMeasurement(shoulders: [.zero, .zero]), face: face, at: 1.17)
        precondition(tracker.resolve(face: face, at: 1.18).isTracked, "One bad observation must not snap to fallback")
        precondition(!tracker.resolve(face: face, at: 1.5).isTracked, "Stale body measurements must expire")
        tracker.reset()
        precondition(!tracker.resolve(face: face, at: 1.6).isTracked)

        let bounds = CGRect(x: 0, y: 0, width: 1280, height: 720)
        let midpoint = CGPoint(x: bounds.midX, y: bounds.midY)
        let view = SceneViewpoint(x: 0.4, y: 0.2)
        let near = distance(view.corner(midpoint, depth: 1000, bounds: bounds), midpoint)
        let far = distance(view.corner(midpoint, depth: 6500, bounds: bounds), midpoint)
        precondition(near > far * 2, "Nearby stonework must move more than the valley")
        for x in [-0.45, 0.45] { for y in [-0.3, 0.3] {
            let v = SceneViewpoint(x: x, y: y)
            let corners = [CGPoint(x: 0, y: 0), CGPoint(x: 1280, y: 0), CGPoint(x: 1280, y: 720), CGPoint(x: 0, y: 720)]
                .map { v.corner($0, depth: 1000, bounds: bounds) }
            precondition(corners.map(\.x).min()! < 0 && corners.map(\.x).max()! > 1280 && corners.map(\.y).min()! < 0 && corners.map(\.y).max()! > 720,
                "Overscan must cover the frame at the allowed view extremes")
        } }

        let context = CIContext()
        func pixel(_ image: CIImage, _ x: Int, _ y: Int) -> [UInt8] {
            var bytes = [UInt8](repeating: 0, count: 4)
            context.render(image, toBitmap: &bytes, rowBytes: 4, bounds: CGRect(x: x, y: y, width: 1, height: 1),
                format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
            return bytes
        }
        let small = CGRect(x: 0, y: 0, width: 200, height: 200)
        let handPoints = [CGPoint(x: 70, y: 60), CGPoint(x: 120, y: 65), CGPoint(x: 110, y: 110), CGPoint(x: 80, y: 105), CGPoint(x: 95, y: 85)]
        precondition(ActorMasks.hull(handPoints).count == 4, "Hand hull must exclude interior landmarks")
        let hands = ActorMasks.hands(hulls: [handPoints], arms: [], faceWidth: 100, bounds: small, placement: .identity)
        precondition(pixel(hands, 95, 85)[0] > 250 && pixel(hands, 10, 10)[0] == 0, "Hand mask must only reveal the hand")
        let actor = CIImage(color: CIColor(red: 0.4, green: 0.4, blue: 0.4)).cropped(to: CGRect(x: 50, y: 50, width: 100, height: 100))
            .composited(over: CIImage(color: .clear).cropped(to: small))
        let moon = SceneLighting.apply(to: actor, amount: 1, flash: 0, bounds: small)
        let flash = SceneLighting.apply(to: actor, amount: 1, flash: 1, bounds: small)
        precondition(pixel(moon, 10, 10)[3] == 0 && pixel(moon, 100, 100)[3] == 255, "Lighting must preserve actor alpha")
        precondition(pixel(flash, 100, 100)[0] > pixel(moon, 100, 100)[0] + 20, "Lightning must also illuminate the person")
        precondition(pixel(SceneLighting.apply(to: actor, amount: 0, flash: 1, bounds: small), 100, 100) == pixel(actor, 100, 100))
        let headMask = ActorMasks.head(jaw: [], face: CGRect(x: 70, y: 100, width: 60, height: 70), bounds: small, placement: .identity)
        precondition(pixel(headMask, 100, 130)[0] > 250 && pixel(headMask, 100, 50)[0] == 0, "Head restoration must not restore the original shirt")

        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let scene = try CinematicScene(directory: root.appendingPathComponent("Resources"), bounds: bounds)
        var options = SceneOptions()
        options.bats = false; options.autoLightning = false; options.rainAmount = 0; options.animateScene = false
        func bytes(_ image: CIImage) -> [UInt8] {
            var value = [UInt8](repeating: 0, count: 1280 * 720 * 4)
            context.render(image, toBitmap: &value, rowBytes: 1280 * 4, bounds: bounds, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
            return value
        }
        let still = bytes(scene.render(time: 1, options: options, head: .zero))
        precondition(still == bytes(scene.render(time: 5, options: options, head: CGPoint(x: 1000, y: 500))),
            "Scene motion off must ignore head movement and stop ambient drift")
        options.animateScene = true
        precondition(still != bytes(scene.render(time: 8, options: options, head: CGPoint(x: 950, y: 500))), "Living scene must respond to viewpoint and time")
        options.cinematic = false
        precondition(still != bytes(scene.render(time: 8, options: options, head: nil)), "Classic background must remain available")
        print("PASS: independent torso fit, roll/hips, tracking/dropout, fit trims, layered parallax, hand/head masks, matched light, reduced motion, classic fallback")
    }
}
