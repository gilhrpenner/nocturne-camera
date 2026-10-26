import AppKit
import CoreImage
import Vision

final class SceneRenderer {
    let context = CIContext(options: [.cacheIntermediates: false])
    let bounds = CGRect(x: 0, y: 0, width: VideoFormat.width, height: VideoFormat.height)
    private let background: CIImage
    private let costumeTexture: CGImage
    private let headTreatment = HeadTreatment()
    private let fog = Fog()
    private var previousPose: CostumePose?
    private var pool: CVPixelBufferPool?
    private let segmentation = VNGeneratePersonSegmentationRequest()
    private let faceRequest = VNDetectFaceLandmarksRequest()
    private let bodyRequest = VNDetectHumanBodyPoseRequest()
    private var face: VNFaceObservation?
    private var shoulders: [CGPoint] = []
    private var frameNumber = 0
    var segmentationFailed = false

    init(assetURL: URL) throws {
        guard let image = CIImage(contentsOf: assetURL) else {
            throw NSError(domain: "Nocturne", code: 1, userInfo: [NSLocalizedDescriptionKey: "The castle artwork is missing. Reinstall the app."])
        }
        guard let costume = NSImage(contentsOf: assetURL.deletingLastPathComponent().appendingPathComponent("vampire-attire.png")),
              let texture = costume.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "Nocturne", code: 7, userInfo: [NSLocalizedDescriptionKey: "The vampire attire artwork is missing. Reinstall the app."])
        }
        costumeTexture = texture
        background = Self.fill(image, in: CGRect(x: 0, y: 0, width: VideoFormat.width, height: VideoFormat.height))
        segmentation.qualityLevel = .balanced
        segmentation.outputPixelFormat = kCVPixelFormatType_OneComponent8
        CVPixelBufferPoolCreate(nil, nil, [kCVPixelBufferWidthKey: VideoFormat.width,
            kCVPixelBufferHeightKey: VideoFormat.height, kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &pool)
    }

    static func fill(_ image: CIImage, in rect: CGRect) -> CIImage {
        let scale = max(rect.width / image.extent.width, rect.height / image.extent.height)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return scaled.transformed(by: CGAffineTransform(translationX: rect.midX - scaled.extent.midX,
            y: rect.midY - scaled.extent.midY)).cropped(to: rect)
    }

    static func subjectTransform(options: SceneOptions, bounds: CGRect) -> CGAffineTransform {
        let scale = CGFloat(options.subjectScale)
        // With attire, keep the head high and reveal the garment below the camera crop.
        // Without attire, keep the real cutout at the bottom so its cropped edge cannot float.
        let anchor = CGPoint(x: bounds.midX, y: options.costume ? bounds.height * 0.85 : bounds.minY)
        return CGAffineTransform(translationX: anchor.x * (1 - scale), y: anchor.y * (1 - scale))
            .scaledBy(x: scale, y: scale)
    }

    func render(input: CVPixelBuffer?, options: SceneOptions, time: Double) throws -> CVPixelBuffer {
        var subject: CIImage?
        var mask: CIImage?
        segmentationFailed = false
        if let input {
            let camera = Self.fill(CIImage(cvPixelBuffer: input), in: bounds)
            if options.normal { previousPose = nil; return try output(camera) }
            var requests: [VNRequest] = []
            let needsHead = options.vampire || options.hairStyle != .natural
            let needsFace = needsHead || options.costume
            if options.castle || options.costume || needsHead { requests.append(segmentation) }
            if needsFace { requests.append(faceRequest) } else { face = nil }
            let updateBody = options.costume && frameNumber % 4 == 0
            frameNumber += 1
            if updateBody { requests.append(bodyRequest) }
            if !requests.isEmpty {
                do {
                    // All requests see the exact same cropped, unmirrored image as the compositor.
                    try VNImageRequestHandler(ciImage: camera, options: [:]).perform(requests)
                    face = needsFace ? faceRequest.results?.max(by: { $0.boundingBox.width < $1.boundingBox.width }) : nil
                    if updateBody {
                        shoulders = [VNHumanBodyPoseObservation.JointName.leftShoulder, .rightShoulder].compactMap { joint in
                            guard let p = try? bodyRequest.results?.first?.recognizedPoint(joint), p.confidence > 0.3 else { return nil }
                            return CGPoint(x: p.location.x * bounds.width, y: p.location.y * bounds.height)
                        }
                    }
                    if options.castle || options.costume || needsHead, let result = segmentation.results?.first {
                        let raw = CIImage(cvPixelBuffer: result.pixelBuffer)
                        mask = raw.transformed(by: CGAffineTransform(scaleX: bounds.width / raw.extent.width,
                            y: bounds.height / raw.extent.height))
                            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.7]).cropped(to: bounds)
                    }
                } catch {
                    face = nil
                    shoulders = []
                    segmentationFailed = options.castle
                }
            }
            subject = camera
            if needsHead, let face, let mask {
                let box = face.boundingBox
                let left = points(face.landmarks?.leftEye, on: face), right = points(face.landmarks?.rightEye, on: face)
                func center(_ values: [CGPoint]) -> CGPoint? {
                    guard !values.isEmpty else { return nil }
                    return CGPoint(x: values.map(\.x).reduce(0, +) / CGFloat(values.count), y: values.map(\.y).reduce(0, +) / CGFloat(values.count))
                }
                let eyes = [center(left), center(right)].compactMap { $0 }.sorted { $0.x < $1.x }
                let brows = points(face.landmarks?.leftEyebrow, on: face) + points(face.landmarks?.rightEyebrow, on: face)
                let browY = center(brows)?.y ?? (box.minY + box.height * 0.82) * bounds.height
                let angle = eyes.count == 2 ? atan2(eyes[1].y - eyes[0].y, eyes[1].x - eyes[0].x) : 0
                let pose = HeadPose(face: CGRect(x: box.minX * bounds.width, y: box.minY * bounds.height,
                    width: box.width * bounds.width, height: box.height * bounds.height), browY: browY, angle: angle)
                subject = headTreatment.apply(to: camera, personMask: mask, pose: pose,
                    intensity: options.vampire ? options.intensity : 0, hairStyle: options.hairStyle,
                    hairAmount: options.hairAmount, bounds: bounds)
            }
            if options.castle && mask == nil { segmentationFailed = true }
        } else { face = nil; shoulders = []; previousPose = nil }

        let placement = Self.subjectTransform(options: options, bounds: bounds)
        subject = subject?.transformed(by: placement)
        mask = mask?.transformed(by: placement)
        let flash = options.flash(at: time)
        let useCastle = options.castle || input == nil || options.isVanished(at: time)
        var scene = useCastle ? background : subject!
        if useCastle {
            scene = scene.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: flash * 1.7])
            scene = overlay(time: time, options: options, foreground: false).composited(over: scene)
        }
        if !options.costume { previousPose = nil }
        let pose = options.costume && !options.isVanished(at: time) ? costumePose() : nil
        if let pose, let mask {
            let collar = canvas(transform: placement) { VampireCostume.draw(in: $0, pose: pose, texture: costumeTexture) }
            if options.castle { scene = collar.composited(over: scene) }
            else {
                // Keep the real head and shoulders in front of the raised collar.
                scene = scene.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: collar.composited(over: scene), kCIInputMaskImageKey: mask])
            }
        }
        if let subject, options.castle, let mask, !options.isVanished(at: time) {
            scene = subject.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: scene,
                kCIInputMaskImageKey: mask])
        }
        // Fail closed: a failed cutout shows the castle, never exposes the room unexpectedly.
        if let pose, let mask {
            let costume = canvas(transform: placement) { c in
                // Follow the actual jaw instead of cutting the garment with a horizontal seam.
                if let face {
                    let jaw = points(face.landmarks?.faceContour, on: face)
                    if let first = jaw.first, let last = jaw.last {
                        c.addRect(bounds); c.addLines(between: jaw)
                        c.addLine(to: CGPoint(x: last.x, y: bounds.maxY))
                        c.addLine(to: CGPoint(x: first.x, y: bounds.maxY)); c.closePath(); c.clip(using: .evenOdd)
                    } else {
                        c.clip(to: CGRect(x: 0, y: 0, width: bounds.width, height: pose.chin.y))
                    }
                }
                VampireCostume.draw(in: c, pose: pose, texture: costumeTexture)
            }
            let clipped = costume.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: CIImage(color: .clear).cropped(to: bounds), kCIInputMaskImageKey: mask])
            scene = clipped.composited(over: scene)
        }
        if !options.isVanished(at: time), options.vampire, let face,
           (!options.castle || mask != nil) {
            scene = faceOverlay(face, options: options, time: time, transform: placement).composited(over: scene)
        }
        if !options.normal, options.fogAmount > 0 {
            scene = fog.image(amount: options.fogAmount, time: time, animated: options.animateFog, bounds: bounds).composited(over: scene)
        }
        scene = overlay(time: time, options: options, foreground: true).composited(over: scene)
        return try output(scene)
    }

    private func canvas(transform: CGAffineTransform = .identity, _ draw: (CGContext) -> Void) -> CIImage {
        let c = CGContext(data: nil, width: VideoFormat.width, height: VideoFormat.height, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.concatenate(transform)
        draw(c)
        return CIImage(cgImage: c.makeImage()!)
    }

    private func points(_ region: VNFaceLandmarkRegion2D?, on face: VNFaceObservation) -> [CGPoint] {
        guard let region else { return [] }
        return (0..<region.pointCount).map { i in
            let p = region.normalizedPoints[i]
            return CGPoint(x: (face.boundingBox.minX + p.x * face.boundingBox.width) * bounds.width,
                y: (face.boundingBox.minY + p.y * face.boundingBox.height) * bounds.height)
        }
    }

    private func costumePose() -> CostumePose? {
        guard let face else { previousPose = nil; return nil }
        let box = face.boundingBox
        let contour = points(face.landmarks?.faceContour, on: face)
        let chin = contour.min(by: { $0.y < $1.y }) ?? CGPoint(x: box.midX * bounds.width, y: box.minY * bounds.height)
        var pose = CostumePose(chin: chin, faceWidth: box.width * bounds.width, faceHeight: box.height * bounds.height, shoulders: shoulders)
        if let previous = previousPose, hypot(previous.chin.x - chin.x, previous.chin.y - chin.y) < pose.faceWidth * 0.6 {
            func blend(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * 0.38 }
            let smoothedShoulders = previous.shoulders.count == 2 && shoulders.count == 2 ? zip(previous.shoulders, shoulders).map {
                CGPoint(x: blend($0.x, $1.x), y: blend($0.y, $1.y))
            } : shoulders
            pose = CostumePose(chin: CGPoint(x: blend(previous.chin.x, chin.x), y: blend(previous.chin.y, chin.y)),
                faceWidth: blend(previous.faceWidth, pose.faceWidth), faceHeight: blend(previous.faceHeight, pose.faceHeight), shoulders: smoothedShoulders)
        }
        previousPose = pose
        return pose
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
            for eye in [face.landmarks?.leftEye, face.landmarks?.rightEye] {
                let p = points(eye)
                guard p.count > 3 else { continue }
                let r = p.reduce(CGRect.null) { $0.union(CGRect(origin: $1, size: CGSize(width: 0.1, height: 0.1))) }
                guard r.height > r.width * 0.12 else { continue } // Do not paint closed eyelids.
                c.saveGState()
                c.addLines(between: p); c.closePath(); c.clip()
                c.setFillColor(CGColor(red: 0.65, green: 0.02, blue: 0.07, alpha: intensity * 0.95))
                c.fillEllipse(in: CGRect(x: r.midX - r.height * 0.5, y: r.minY, width: r.height, height: r.height))
                c.setFillColor(CGColor(gray: 0.02, alpha: intensity))
                c.fillEllipse(in: CGRect(x: r.midX - r.height * 0.13, y: r.minY + r.height * 0.15,
                    width: r.height * 0.26, height: r.height * 0.7))
                c.restoreGState()
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

    private func overlay(time: Double, options: SceneOptions, foreground: Bool) -> CIImage {
        canvas { c in
            guard !options.normal else { return }
            if !foreground {
                Storm.draw(Storm.strikes(at: time, automatic: options.autoLightning, manualAt: options.lightningAt), in: c, bounds: bounds)
            }
            let swarmAge = time - options.swarmAt
            let swarm = (0..<4).contains(swarmAge)
            guard options.bats || swarm else { return }
            let count = swarm ? 22 : (foreground ? 1 : 4)
            for i in 0..<count {
                let seed = Double(i) * 1.618
                let duration = swarm ? 3.0 : 13.0
                let phase = ((swarm ? swarmAge : time) / duration + seed).truncatingRemainder(dividingBy: 1)
                let x = CGFloat(phase * 1600 - 160)
                let y = CGFloat((foreground ? 170 : 430) + sin(time * 1.1 + seed * 3) * 75 + Double(i % 4) * 55)
                let size: CGFloat = swarm ? CGFloat(13 + i % 5 * 6) : (foreground ? 32 : 12)
                drawBat(c, at: CGPoint(x: x, y: y), size: size, flap: CGFloat(sin(time * 14 + seed)))
            }
        }
    }

    private func drawBat(_ c: CGContext, at p: CGPoint, size: CGFloat, flap: CGFloat) {
        c.saveGState(); c.translateBy(x: p.x, y: p.y); c.scaleBy(x: size, y: size)
        c.setFillColor(CGColor(red: 0.025, green: 0.03, blue: 0.045, alpha: 1))
        for side: CGFloat in [-1, 1] {
            c.move(to: CGPoint(x: 0, y: 0.2))
            c.addQuadCurve(to: CGPoint(x: side * 1.6, y: 0.25 + flap * 0.65), control: CGPoint(x: side * 0.6, y: 0.95 + flap * 0.4))
            c.addQuadCurve(to: CGPoint(x: side * 0.95, y: -0.45), control: CGPoint(x: side * 0.95, y: 0.2))
            c.addQuadCurve(to: CGPoint(x: side * 0.45, y: -0.35), control: CGPoint(x: side * 0.65, y: -0.1))
            c.addLine(to: CGPoint(x: 0, y: -0.65)); c.closePath(); c.fillPath()
        }
        c.fillEllipse(in: CGRect(x: -0.15, y: -0.3, width: 0.3, height: 0.65))
        c.addLines(between: [CGPoint(x: -0.15, y: 0.1), CGPoint(x: -0.22, y: 0.52), CGPoint(x: 0, y: 0.3),
            CGPoint(x: 0.22, y: 0.52), CGPoint(x: 0.15, y: 0.1)])
        c.closePath(); c.fillPath(); c.restoreGState()
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
