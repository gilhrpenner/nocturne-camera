import CoreImage
import CoreGraphics

@main struct PerformanceTests {
    static func main() throws {
        var options = SceneOptions()
        options.autoLightning = false
        precondition(options.beginPerformance(.vanish, at: 100))
        precondition(!options.beginPerformance(.entrance, at: 100.2), "Cues must not overlap or restart halfway through")
        precondition(options.performance(at: 99) == nil)
        precondition(options.performance(at: 100)!.dissolution == 0)
        precondition(options.isVanished(at: 102.5))
        precondition(options.performance(at: 104.6)!.dissolution > 0 && options.performance(at: 104.6)!.dissolution < 1)
        precondition(options.performance(at: 106.01) == nil, "Vanish must always return automatically")
        options.cancelPerformance()
        precondition(options.performance(at: 101) == nil)
        precondition(options.beginPerformance(.entrance, at: 200))
        precondition(options.performance(at: 200)!.dissolution == 1)
        precondition(options.flash(at: 200) > 0.4 && options.flash(at: 201.45) > 0.99,
            "Grand entrance must coordinate its own lightning even with automatic storms off")
        precondition(options.performance(at: 202.31) == nil && options.flash(at: 203) == 0)
        precondition(StagePerformance.active(vanishAt: 100, entranceAt: 102, time: 104.31) == nil,
            "An earlier cue must never resume after the newer one finishes")
        options.normal = true
        precondition(options.performance(at: 200) == nil && options.flash(at: 201.1) == 0)
        precondition(!options.beginPerformance(.vanish, at: 205))
        options.normal = false; options.castle = false
        precondition(options.performance(at: 200) == nil && !options.beginPerformance(.vanish, at: 205))

        let bounds = CGRect(x: 0, y: 0, width: 320, height: 180), context = CIContext()
        let actor = SceneCanvas.image(bounds: bounds) { c in
            c.setFillColor(CGColor(red: 0.8, green: 0.4, blue: 0.3, alpha: 1))
            c.fillEllipse(in: CGRect(x: 45, y: 100, width: 45, height: 65))
            c.fill(CGRect(x: 30, y: 0, width: 90, height: 105))
        }
        let empty = CIImage(color: .clear).cropped(to: bounds)
        func bytes(_ image: CIImage) -> [UInt8] {
            var pixels = [UInt8](repeating: 0, count: 320 * 180 * 4)
            context.render(image, toBitmap: &pixels, rowBytes: 320 * 4, bounds: bounds, format: .RGBA8,
                colorSpace: CGColorSpaceCreateDeviceRGB())
            return pixels
        }
        func alphaSum(_ image: CIImage) -> Int { let data = bytes(image); return stride(from: 3, to: data.count, by: 4).reduce(0) { $0 + Int(data[$1]) } }
        func alpha(_ image: CIImage, at p: CGPoint) -> Int {
            var pixel = [UInt8](repeating: 0, count: 4)
            context.render(image, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: p.x - 0.5, y: p.y - 0.5, width: 1, height: 1),
                format: .RGBA8, colorSpace: nil)
            return Int(pixel[3])
        }
        let sprite = try BatSprite(url: URL(fileURLWithPath: "Resources/transformation-bat.png"))
        let wingsUp = SceneCanvas.image(bounds: bounds) { c in
            sprite.draw(in: c, point: CGPoint(x: 160, y: 90), span: 160, flap: 1, bank: 0, opacity: 1)
        }
        let wingsDown = SceneCanvas.image(bounds: bounds) { c in
            sprite.draw(in: c, point: CGPoint(x: 160, y: 90), span: 160, flap: -1, bank: 0, opacity: 1)
        }
        precondition(bytes(wingsUp) != bytes(wingsDown), "Transformation bats must articulate their wings")
        precondition(alpha(wingsUp, at: CGPoint(x: 10, y: 10)) == 0, "Bat artwork must retain a transparent background")
        let dissolve = BatDissolve(sprite: sprite)
        _ = dissolve.image(actor: actor, performance: StagePerformance(kind: .vanish, startedAt: 90, elapsed: 0), context: context, bounds: bounds)
        let original = bytes(actor)
        precondition(bytes(dissolve.attached(actor: actor, amount: 0, bounds: bounds)) == original)
        precondition(alphaSum(dissolve.attached(actor: actor, amount: 1, bounds: bounds)) == 0)
        var last = alphaSum(actor)
        for amount in [0.2, 0.35, 0.5, 0.65, 0.8] {
            let result = dissolve.attached(actor: actor, amount: amount, bounds: bounds)
            let sum = alphaSum(result)
            precondition(sum <= last, "The silhouette must dissolve monotonically")
            last = sum
            precondition(alpha(result, at: CGPoint(x: 250, y: 90)) == 0, "Dissolve cannot reveal room pixels")
        }
        let middle = Double(alphaSum(dissolve.attached(actor: actor, amount: 0.5, bounds: bounds))) / Double(alphaSum(actor))
        precondition(middle > 0.15 && middle < 0.85, "The midpoint must contain both visible and dissolved regions")
        let lean = CGAffineTransform(translationX: 70, y: 0)
        let movedActor = actor.transformed(by: lean).cropped(to: bounds)
        let followed = dissolve.attached(actor: movedActor, amount: 0.5, bounds: bounds, movement: lean)
        let expected = dissolve.attached(actor: actor, amount: 0.5, bounds: bounds).transformed(by: lean).cropped(to: bounds)
        precondition(bytes(followed) == bytes(expected), "Dissolving fragments must stay attached during a lean")
        let occupied = dissolve.fragments.filter { $0.texture != nil }
        precondition(occupied.count > 30 && occupied.count < 120)
        for fragment in occupied {
            let bat = DissolveBat(origin: fragment.origin, seed: fragment.seed)
            precondition(alpha(actor, at: bat.origin) > 120, "Bat \(fragment.seed) at \(bat.origin) has alpha \(alpha(actor, at: bat.origin)); it must start on the actor")
            precondition(bat.position(progress: 0, bounds: bounds) == bat.origin)
            precondition(!bounds.contains(bat.position(progress: 1, bounds: bounds)))
        }
        let pieces = SceneCanvas.image(bounds: bounds) { c in
            for fragment in occupied { c.draw(fragment.texture!, in: fragment.rect) }
        }
        precondition(alpha(pieces, at: CGPoint(x: 60, y: 40)) > 240, "Pieces must carry real actor pixels")
        precondition(alpha(pieces, at: CGPoint(x: 250, y: 90)) == 0, "Fragments must not carry the room")
        let sourcePixel = bytes(actor), piecePixel = bytes(pieces)
        let centerIndex = ((180 - 1 - 40) * 320 + 60) * 4
        precondition(abs(Int(sourcePixel[centerIndex]) - Int(piecePixel[centerIndex])) < 5,
            "Flying fragments must preserve the person's appearance before they become bats")
        precondition(DissolveMesh.capture(actor: empty, context: context, bounds: bounds).allSatisfy { $0.texture == nil })
        func render(_ elapsed: Double, _ kind: StagePerformance.Kind = .vanish) -> CIImage {
            dissolve.image(actor: actor, performance: StagePerformance(kind: kind, startedAt: kind == .vanish ? 100 : 200, elapsed: elapsed),
                context: context, bounds: bounds)
        }
        precondition(bytes(render(0)) == original, "The departure must start without a jump")
        precondition(alphaSum(render(0.7)) > 0 && bytes(render(0.7)) != original)
        precondition(alphaSum(render(2.8)) == 0, "The terrace must be completely empty between flocks")
        precondition(alphaSum(render(4.7)) > 0, "The return must gather bats and rebuild the actor")
        precondition(bytes(render(6.0)) == original, "The return must finish with an intact actor")
        precondition(alphaSum(render(0, .entrance)) == 0)
        precondition(alphaSum(render(0.8, .entrance)) > 0)
        precondition(bytes(dissolve.image(actor: actor, performance: nil, context: context, bounds: bounds)) == original)
        precondition(dissolve.fragments.isEmpty, "Cancel/bypass must release the previous silhouette")

        // A return must capture the new appearance instead of recycling the outgoing face and costume.
        let blueActor = actor.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 1)])
        _ = dissolve.image(actor: actor, performance: StagePerformance(kind: .vanish, startedAt: 300, elapsed: 0), context: context, bounds: bounds)
        _ = dissolve.image(actor: blueActor, performance: StagePerformance(kind: .vanish, startedAt: 300, elapsed: 3), context: context, bounds: bounds)
        let newPieces = SceneCanvas.image(bounds: bounds) { c in
            for fragment in dissolve.fragments { if let texture = fragment.texture { c.draw(texture, in: fragment.rect) } }
        }
        let newPixels = bytes(newPieces)
        precondition(newPixels[centerIndex + 2] > 240 && newPixels[centerIndex] < 5,
            "The gathering bats must carry the incoming character's pixels")
        dissolve.reset()

        options = SceneOptions()
        let visitTime = (0..<2900).map { Double($0) / 10 }.first { HauntedWindows.visit(at: $0) != nil }!
        precondition(HauntedWindows.image(time: visitTime + 2, options: options, bounds: bounds) != nil)
        let presence = (0..<2900).filter { HauntedWindows.visit(at: Double($0) / 10) != nil }.count
        precondition(presence > 300 && presence < 650, "Window visits must be occasional, not constant")
        let haunting = HauntedWindows.image(visit: .init(window: 0, progress: 0.5), bounds: bounds)
        precondition(alphaSum(haunting) > 0)
        precondition(alpha(haunting, at: CGPoint(x: 50, y: 80)) == 0, "The window figure cannot escape the castle glass")
        options.animateScene = false
        precondition(HauntedWindows.image(time: visitTime + 2, options: options, bounds: bounds) == nil)
        options.animateScene = true; options.hauntedWindows = false
        precondition(HauntedWindows.image(time: visitTime + 2, options: options, bounds: bounds) == nil)
        options.hauntedWindows = true; options.cinematic = false
        precondition(HauntedWindows.image(time: visitTime + 2, options: options, bounds: bounds) == nil)
        print("PASS: cue timing/retrigger/cancel, synchronized entrance lightning, textured silhouette fragments, monotonic dissolve, moving fragments and winged flight, empty stage, full return, window rarity and reduced motion")
    }
}
