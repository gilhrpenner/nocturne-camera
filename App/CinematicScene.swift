import CoreImage
import CoreGraphics
import Foundation

struct SceneViewpoint {
    var x: Double = 0
    var y: Double = 0

    func corner(_ point: CGPoint, depth: Double, bounds: CGRect, overscan: Double = 1.09) -> CGPoint {
        let focal = 1000.0
        let worldX = (point.x - bounds.midX) * depth / focal * overscan - x * 100
        let worldY = (point.y - bounds.midY) * depth / focal * overscan - y * 65
        // A small view rotation gives the planes perspective as well as translation.
        let yaw = x * 0.012, pitch = y * 0.008
        let rx = worldX * cos(yaw) - depth * sin(yaw)
        let rz = worldX * sin(yaw) + depth * cos(yaw)
        let ry = worldY * cos(pitch) - rz * sin(pitch)
        let z = max(200, worldY * sin(pitch) + rz * cos(pitch))
        return CGPoint(x: bounds.midX + rx * focal / z, y: bounds.midY + ry * focal / z)
    }
}

final class CinematicScene {
    private let valley: CIImage
    private let castle: CIImage
    private let terrace: CIImage
    private let classic: CIImage
    private let mist = Fog()
    private let clouds = Fog()
    private let weather = SceneWeather()
    private var view = SceneViewpoint()
    private var lastTime = -Double.infinity
    private let bounds: CGRect

    init(directory: URL, bounds: CGRect) throws {
        self.bounds = bounds
        func load(_ name: String) throws -> CIImage {
            guard let image = CIImage(contentsOf: directory.appendingPathComponent(name)) else {
                throw NSError(domain: "Nocturne", code: 8, userInfo: [NSLocalizedDescriptionKey: "Scene artwork is missing: \(name). Reinstall Nocturne."])
            }
            return SceneCanvas.fill(image, bounds: bounds)
        }
        valley = try load("scene-valley.png")
        castle = try load("scene-castle.png")
        terrace = try load("scene-terrace.png")
        classic = try load("castle.png")
    }

    func resetView() { view = SceneViewpoint(); lastTime = -.infinity }

    func render(time: Double, options: SceneOptions, head: CGPoint?) -> CIImage {
        if options.normal { return classic }
        let flash = options.flash(at: time)
        let lightning = SceneCanvas.image(bounds: bounds) { c in
            Storm.draw(Storm.strikes(at: time, automatic: options.autoLightning, manualAt: options.lightningAt), in: c, bounds: bounds)
        }
        if !options.cinematic {
            return weather.image(time: time, options: options, near: false, bounds: bounds)
                .composited(over: lightning.composited(over: classic.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: flash * 1.7])))
        }
        let t = options.animateScene ? time : 0
        let depth = options.animateScene ? options.sceneDepth : 0
        let targetX = ((head?.x ?? bounds.midX) - bounds.midX) / bounds.width * 1.6
        let targetY = ((head?.y ?? bounds.midY) - bounds.midY) / bounds.height * 0.8
        let dt = max(0.001, min(0.1, time - lastTime)), alpha = 1 - exp(-dt * 4)
        view.x += (min(0.45, max(-0.45, targetX)) * depth - view.x) * alpha
        view.y += (min(0.3, max(-0.3, targetY)) * depth - view.y) * alpha
        if !options.animateScene { view = SceneViewpoint() }
        lastTime = time
        var camera = view
        camera.x += sin(t * 0.11) * 0.035 * depth; camera.y += sin(t * 0.085) * 0.018 * depth
        func project(_ image: CIImage, distance: Double) -> CIImage {
            func vector(_ p: CGPoint) -> CIVector { let q = camera.corner(p, depth: distance, bounds: bounds); return CIVector(x: q.x, y: q.y) }
            return image.applyingFilter("CIPerspectiveTransform", parameters: [
                "inputTopLeft": vector(CGPoint(x: bounds.minX, y: bounds.maxY)), "inputTopRight": vector(CGPoint(x: bounds.maxX, y: bounds.maxY)),
                "inputBottomLeft": vector(CGPoint(x: bounds.minX, y: bounds.minY)), "inputBottomRight": vector(CGPoint(x: bounds.maxX, y: bounds.minY))])
        }
        var scene = project(valley, distance: 6500).applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: flash * 1.7])
        let skyMist = clouds.image(amount: 0.1, time: t * 0.25 + 83, animated: options.animateScene, bounds: bounds)
            .transformed(by: CGAffineTransform(translationX: 0, y: bounds.height).scaledBy(x: 1, y: -1))
        let cloudVeil = CIImage(color: CIColor(red: 0.025, green: 0.045, blue: 0.07)).cropped(to: bounds)
            .applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: skyMist])
        scene = cloudVeil.composited(over: scene)
        scene = lightning.composited(over: scene)
        let valleyMist = mist.image(amount: 0.055, time: t * 0.4 + 145, animated: options.animateScene, bounds: bounds)
            .transformed(by: CGAffineTransform(translationX: 0, y: bounds.height * 0.23).scaledBy(x: 1, y: 0.65))
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 16])
        scene = valleyMist.composited(over: scene)
        let castleLight = castle.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: flash * 1.15 - 0.12 + sin(t * 0.4) * 0.025])
        scene = project(castleLight, distance: 2800).composited(over: scene)
        scene = weather.image(time: time, options: options, near: false, bounds: bounds).composited(over: scene)
        let terraceLight = terrace.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: flash * 0.9 - 0.08])
        scene = project(terraceLight, distance: 1000).composited(over: scene)
        return scene.cropped(to: bounds)
    }
}
