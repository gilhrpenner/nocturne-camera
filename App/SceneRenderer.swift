import AppKit
import CoreImage
import Vision

final class SceneRenderer {
    let context = CIContext(options: [.cacheIntermediates: false])
    let bounds = CGRect(x: 0, y: 0, width: VideoFormat.width, height: VideoFormat.height)
    private let background: CinematicScene
    private let costumeTexture: CIImage
    private let heroCostume = HeroCostume()
    private let headTreatment = HeadTreatment()
    private let fog = Fog()
    private let weather = SceneWeather()
    private let batDissolve: BatDissolve
    private let bodyTracker = BodyTracker()
    private let costumeStabilizer = CostumeStabilizer()
    private var pool: CVPixelBufferPool?
    private let segmentation = VNGeneratePersonSegmentationRequest()
    private let faceRequest = VNDetectFaceLandmarksRequest()
    private let poseAnalyzer = PoseAnalyzer()
    private var face: VNFaceObservation?
    private var handHulls: [[CGPoint]] = []
    private var handTime = -Double.infinity
    private var frameNumber = 0
    private(set) var segmentationFailed = false
    private(set) var trackingStatus = "Camera off"

    init(assetURL: URL) throws {
        let directory = assetURL.deletingLastPathComponent()
        background = try CinematicScene(directory: directory, bounds: bounds)
        batDissolve = try BatDissolve(sprite: BatSprite(url: directory.appendingPathComponent("transformation-bat.png")))
        guard let texture = CIImage(contentsOf: directory.appendingPathComponent("vampire-attire.png")) else {
            throw NSError(domain: "Nocturne", code: 7, userInfo: [NSLocalizedDescriptionKey: "The vampire attire artwork is missing. Reinstall the app."])
        }
        costumeTexture = texture
        segmentation.qualityLevel = .balanced
        segmentation.outputPixelFormat = kCVPixelFormatType_OneComponent8
        CVPixelBufferPoolCreate(nil, nil, [kCVPixelBufferWidthKey: VideoFormat.width,
            kCVPixelBufferHeightKey: VideoFormat.height, kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &pool)
    }

    static func fill(_ image: CIImage, in rect: CGRect) -> CIImage { SceneCanvas.fill(image, bounds: rect) }

    static func subjectTransform(options: SceneOptions, bounds: CGRect) -> CGAffineTransform {
        let scale = CGFloat(options.subjectScale)
        // Attire reveals a generated torso; a real cropped torso stays at the bottom edge.
        let anchor = CGPoint(x: bounds.midX, y: options.costume ? bounds.height * 0.85 : bounds.minY)
        return CGAffineTransform(translationX: anchor.x * (1 - scale), y: anchor.y * (1 - scale))
            .scaledBy(x: scale, y: scale)
    }

    private func resetTracking() {
        face = nil; bodyTracker.reset(); poseAnalyzer.reset(); handHulls = []; handTime = -.infinity
        costumeStabilizer.reset()
        heroCostume.reset()
        batDissolve.reset()
        trackingStatus = "Camera off"; background.resetView()
    }

    func render(input: CVPixelBuffer?, options requestedOptions: SceneOptions, time: Double) throws -> CVPixelBuffer {
        let options = requestedOptions.renderingOptions(at: time)
        let character = options.selectedCharacter
        if character != .batman { heroCostume.reset() }
        var camera: CIImage?
        var subject: CIImage?
        var mask: CIImage?
        segmentationFailed = false
        if let input {
            let source = Self.fill(CIImage(cvPixelBuffer: input), in: bounds)
            camera = source
            if options.normal { resetTracking(); trackingStatus = "Normal camera"; return try output(source) }
            let needsHead = options.vampire || options.hairStyle != .natural
            let needsFace = needsHead || options.costume || (options.castle && options.cinematic)
            let needsMask = options.castle || options.costume || needsHead
            let updatePose = options.costume && frameNumber % 2 == 0
            frameNumber += 1
            var requests: [VNRequest] = []
            if needsMask { requests.append(segmentation) }
            if needsFace { requests.append(faceRequest) } else { face = nil }
            if !requests.isEmpty {
                do {
                    try VNImageRequestHandler(ciImage: source, options: [:]).perform(requests)
                    face = needsFace ? faceRequest.results?.max(by: { $0.boundingBox.width < $1.boundingBox.width }) : nil
                    if needsMask, let result = segmentation.results?.first {
                        let raw = CIImage(cvPixelBuffer: result.pixelBuffer)
                        mask = raw.transformed(by: CGAffineTransform(scaleX: bounds.width / raw.extent.width,
                            y: bounds.height / raw.extent.height))
                            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.7]).cropped(to: bounds)
                    }
                } catch {
                    face = nil; bodyTracker.reset(); poseAnalyzer.reset(); handHulls = []
                    segmentationFailed = options.castle
                }
            }
            if options.costume, let snapshot = poseAnalyzer.takeLatest() {
                if let anchor = faceAnchor(), abs(anchor.bounds.midX - snapshot.face.bounds.midX) < max(anchor.bounds.width, snapshot.face.bounds.width) * 0.8 {
                    bodyTracker.update(snapshot.body, face: snapshot.face, at: snapshot.time)
                    handHulls = snapshot.hands; handTime = snapshot.time
                } else { bodyTracker.reset(); handHulls = [] }
            }
            if updatePose, let anchor = faceAnchor() {
                poseAnalyzer.submit(image: source, face: anchor, time: time, hands: options.preserveHands, bounds: bounds)
            }

            subject = source
            if needsHead, let face, let mask {
                let box = face.boundingBox
                let eyes = [center(points(face.landmarks?.leftEye, on: face)), center(points(face.landmarks?.rightEye, on: face))]
                    .compactMap { $0 }.sorted { $0.x < $1.x }
                let brows = points(face.landmarks?.leftEyebrow, on: face) + points(face.landmarks?.rightEyebrow, on: face)
                let browY = center(brows)?.y ?? (box.minY + box.height * 0.82) * bounds.height
                let angle = eyes.count == 2 ? atan2(eyes[1].y - eyes[0].y, eyes[1].x - eyes[0].x) : 0
                let pose = HeadPose(face: faceRect(face), browY: browY, angle: angle)
                subject = headTreatment.apply(to: source, personMask: mask, pose: pose,
                    intensity: options.vampire ? options.intensity : 0, hairStyle: options.hairStyle,
                    hairAmount: options.hairAmount, bounds: bounds)
            }
            if options.castle && mask == nil { segmentationFailed = true }
        } else { resetTracking() }

        let placement = Self.subjectTransform(options: options, bounds: bounds)
        let placedSubject = subject?.transformed(by: placement)
        let placedMask = mask?.transformed(by: placement).cropped(to: bounds)
        let performance = input == nil ? nil : options.performance(at: time)
        if performance == nil { batDissolve.reset() }
        let useCastle = options.castle || input == nil
        let anchor = faceAnchor()
        var scene = useCastle ? background.render(time: time, options: options, head: anchor.map { CGPoint(x: $0.bounds.midX, y: $0.bounds.midY) }) : subject!

        trackingStatus = input == nil ? "Camera off" : (anchor == nil ? "Face not visible" : "Face tracked")
        if !options.costume { bodyTracker.reset(); costumeStabilizer.reset(); poseAnalyzer.reset(); handHulls = [] }
        if !options.preserveHands || time - handTime > 0.22 { handHulls = [] }

        // Assemble one transparent actor so moonlight and lightning affect every layer coherently.
        let performanceAnchor = anchor.map { CGPoint(x: $0.bounds.midX, y: $0.bounds.midY).applying(placement) }
        if let performance, performance.dissolution == 1, !batDissolve.needsCapture(for: performance) {
            // Once airborne, the flock only needs its captured fragments. Keep tracking live for the return.
            let flock = batDissolve.image(actor: CIImage(color: .clear).cropped(to: bounds), performance: performance,
                context: context, bounds: bounds, anchor: performanceAnchor, flash: options.flash(at: time))
            scene = flock.composited(over: scene)
        } else if let placedSubject, (!options.castle || placedMask != nil) {
            var actor = placedMask.map { clipped(placedSubject, by: $0) } ?? placedSubject
            if options.costume { actor = CIImage(color: .clear).cropped(to: bounds) }
            var foregroundHands: CIImage?
            if options.costume, let anchor, let placedMask {
                let body = bodyTracker.resolve(face: anchor, at: time)
                trackingStatus = body.isTracked ? (body.hips.count == 2 ? "Torso tracked" : "Shoulders tracked") : "Show both shoulders for a closer fit"
                let fit = costumeStabilizer.update(CostumeFit.make(body: body, face: anchor,
                    width: options.costumeWidth, lift: options.costumeLift), at: time)
                let costume = fit.image(texture: character == .batman ? heroCostume.suit : costumeTexture, placement: placement).cropped(to: bounds)
                if character == .batman {
                    let eyes = face.map { observation in
                        [center(points(observation.landmarks?.leftEye, on: observation)),
                         center(points(observation.landmarks?.rightEye, on: observation))].compactMap { $0 }
                    } ?? []
                    let pose = heroCostume.stabilized(CowlPose.make(eyes: eyes, face: anchor), at: time)
                    actor = heroCostume.dressed(subject: placedSubject, personMask: placedMask, garment: costume,
                        pose: pose, placement: placement, bounds: bounds)
                } else {
                    let head = ActorMasks.head(jaw: face.map { points($0.landmarks?.faceContour, on: $0) } ?? [],
                        face: anchor.bounds, bounds: bounds, placement: placement)
                    let neck = ActorMasks.neck(face: anchor, neckline: fit.neck, bounds: bounds, placement: placement)
                    actor = ActorCompositor.dressed(subject: placedSubject, personMask: placedMask, garment: costume,
                        headMask: head, neckMask: neck, bounds: bounds)
                }
                if !handHulls.isEmpty, let camera {
                    let hand = ActorMasks.hands(hulls: handHulls, arms: [], faceWidth: anchor.bounds.width, bounds: bounds, placement: placement)
                    // Hand landmarks preserve the whole hand. Skin selection prevents sleeves from leaking through the coat.
                    let armRegion = ActorMasks.hands(hulls: handHulls, arms: body.arms, faceWidth: anchor.bounds.width, bounds: bounds, placement: placement)
                    let skin = headTreatment.skinSelection(camera).transformed(by: placement)
                    let handMask = hand.applyingFilter("CIMaximumCompositing", parameters: [kCIInputBackgroundImageKey: multiply(armRegion, skin)])
                    let pale = options.vampire ? headTreatment.paleSkin(camera, intensity: options.intensity) : camera
                    foregroundHands = clipped(pale.transformed(by: placement), by: multiply(handMask, placedMask))
                }
            }
            if options.vampire, let face {
                actor = faceOverlay(face, options: options, time: time, transform: placement).composited(over: actor)
            }
            if let foregroundHands { actor = foregroundHands.composited(over: actor) }
            if options.cinematic && options.castle && options.relighting > 0 {
                // Bound the filter graph before using the actor in both color and edge-light branches.
                actor = CIImage(cvPixelBuffer: try output(actor))
                actor = SceneLighting.apply(to: actor, amount: options.relighting, flash: options.flash(at: time), bounds: bounds)
            }
            actor = batDissolve.image(actor: actor, performance: performance, context: context, bounds: bounds,
                anchor: performanceAnchor, flash: options.flash(at: time))
            scene = actor.composited(over: scene)
        }
        if !options.normal && options.fogAmount > 0 {
            scene = fog.image(amount: options.fogAmount, time: time, animated: options.animateFog, bounds: bounds).composited(over: scene)
        }
        scene = weather.image(time: time, options: options, near: true, bounds: bounds).composited(over: scene)
        return try output(scene)
    }

    private func clipped(_ image: CIImage, by mask: CIImage) -> CIImage {
        image.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: CIImage(color: .clear).cropped(to: bounds), kCIInputMaskImageKey: mask])
    }
    private func multiply(_ a: CIImage, _ b: CIImage) -> CIImage {
        a.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: b])
    }
    private func canvas(transform: CGAffineTransform = .identity, _ draw: (CGContext) -> Void) -> CIImage {
        SceneCanvas.image(bounds: bounds, transform: transform, draw: draw)
    }
    private func center(_ values: [CGPoint]) -> CGPoint? {
        guard !values.isEmpty else { return nil }
        return CGPoint(x: values.map(\.x).reduce(0, +) / CGFloat(values.count), y: values.map(\.y).reduce(0, +) / CGFloat(values.count))
    }
    private func faceRect(_ face: VNFaceObservation) -> CGRect {
        let b = face.boundingBox
        return CGRect(x: b.minX * bounds.width, y: b.minY * bounds.height, width: b.width * bounds.width, height: b.height * bounds.height)
    }
    private func faceAnchor() -> FaceAnchor? {
        guard let face else { return nil }
        let rect = faceRect(face)
        let chin = points(face.landmarks?.faceContour, on: face).min(by: { $0.y < $1.y }) ?? CGPoint(x: rect.midX, y: rect.minY)
        return FaceAnchor(bounds: rect, chin: chin)
    }
    private func points(_ region: VNFaceLandmarkRegion2D?, on face: VNFaceObservation) -> [CGPoint] {
        guard let region else { return [] }
        return (0..<region.pointCount).map { i in
            let p = region.normalizedPoints[i]
            return CGPoint(x: (face.boundingBox.minX + p.x * face.boundingBox.width) * bounds.width,
                y: (face.boundingBox.minY + p.y * face.boundingBox.height) * bounds.height)
        }
    }
    private func faceOverlay(_ face: VNFaceObservation, options: SceneOptions, time: Double, transform: CGAffineTransform) -> CIImage {
        canvas(transform: transform) { c in
            let intensity = options.intensity
            guard intensity > 0 else { return }
            func points(_ region: VNFaceLandmarkRegion2D?) -> [CGPoint] {
                self.points(region, on: face)
            }
            let box = face.boundingBox
            VampireMakeup.draw(in: c, eyes: [points(face.landmarks?.leftEye), points(face.landmarks?.rightEye)],
                outerLips: points(face.landmarks?.outerLips), innerLips: points(face.landmarks?.innerLips),
                face: CGRect(x: box.minX * bounds.width, y: box.minY * bounds.height, width: box.width * bounds.width, height: box.height * bounds.height),
                intensity: intensity, blood: options.blood, time: time, animateBlood: options.animateBlood)
            let eyePairs = [(face.landmarks?.leftEye, face.landmarks?.leftPupil),
                (face.landmarks?.rightEye, face.landmarks?.rightPupil)]
            for (outline, pupil) in eyePairs {
                if let eye = VampireEye.make(outline: points(outline), pupil: self.center(points(pupil))) {
                    VampireEyes.draw(eye, in: c, intensity: intensity)
                }
            }
            let lips = points(face.landmarks?.innerLips)
            func center(_ p: [CGPoint]) -> CGPoint? {
                guard !p.isEmpty else { return nil }
                return CGPoint(x: p.map(\.x).reduce(0, +) / CGFloat(p.count), y: p.map(\.y).reduce(0, +) / CGFloat(p.count))
            }
            let eyes = [center(points(face.landmarks?.leftEye)), center(points(face.landmarks?.rightEye))]
                .compactMap { $0 }.sorted { $0.x < $1.x }
            let axis = eyes.count == 2 ? CGVector(dx: eyes[1].x - eyes[0].x, dy: eyes[1].y - eyes[0].y) : CGVector(dx: 1, dy: 0)
            let fangs = FangGeometry.make(inner: lips, outer: points(face.landmarks?.outerLips), faceAxis: axis)
            FangPainter.draw(fangs, in: c, opacity: min(1, intensity * 1.5))
        }
    }

    private func output(_ image: CIImage) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        guard let pool, CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess, let buffer else {
            throw NSError(domain: "Nocturne", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not allocate a video frame."])
        }
        context.render(image, to: buffer, bounds: bounds, colorSpace: CGColorSpaceCreateDeviceRGB())
        return buffer
    }
}
