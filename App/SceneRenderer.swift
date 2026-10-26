import AppKit
import CoreImage
import Vision

final class SceneRenderer {
    let context = CIContext(options: [.cacheIntermediates: false])
    let bounds = CGRect(x: 0, y: 0, width: VideoFormat.width, height: VideoFormat.height)
    private let background: CIImage
    private var pool: CVPixelBufferPool?
    private let segmentation = VNGeneratePersonSegmentationRequest()
    private let faceRequest = VNDetectFaceLandmarksRequest()
    private var face: VNFaceObservation?
    var segmentationFailed = false

    init(assetURL: URL) throws {
        guard let image = CIImage(contentsOf: assetURL) else {
            throw NSError(domain: "Nocturne", code: 1, userInfo: [NSLocalizedDescriptionKey: "The castle artwork is missing. Reinstall the app."])
        }
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

    func render(input: CVPixelBuffer?, options: SceneOptions, time: Double) throws -> CVPixelBuffer {
        var subject: CIImage?
        var mask: CIImage?
        segmentationFailed = false
        if let input {
            let camera = Self.fill(CIImage(cvPixelBuffer: input), in: bounds)
            if options.normal { return try output(camera) }
            var requests: [VNRequest] = []
            if options.castle { requests.append(segmentation) }
            if options.vampire { requests.append(faceRequest) }
            if !requests.isEmpty {
                do {
                    // Both requests see the exact same cropped, unmirrored image as the compositor.
                    try VNImageRequestHandler(ciImage: camera, options: [:]).perform(requests)
                    face = options.vampire ? faceRequest.results?.max(by: { $0.boundingBox.width < $1.boundingBox.width }) : nil
                    if options.castle, let result = segmentation.results?.first {
                        let raw = CIImage(cvPixelBuffer: result.pixelBuffer)
                        mask = raw.transformed(by: CGAffineTransform(scaleX: bounds.width / raw.extent.width,
                            y: bounds.height / raw.extent.height))
                            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.7]).cropped(to: bounds)
                    }
                } catch {
                    face = nil
                    segmentationFailed = true
                }
            }
            subject = options.vampire ? vampireGrade(camera, intensity: options.intensity) : camera
            if options.castle && mask == nil { segmentationFailed = true }
        } else { face = nil }

        let flash = options.flash(at: time)
        let useCastle = options.castle || input == nil || options.isVanished(at: time)
        var scene = useCastle ? background : subject!
        if useCastle {
            scene = scene.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: flash * 1.7])
            scene = overlay(time: time, options: options, foreground: false).composited(over: scene)
        }
        if let subject, options.castle, let mask, !options.isVanished(at: time) {
            scene = subject.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: scene,
                kCIInputMaskImageKey: mask])
        }
        // Fail closed: a failed cutout shows the castle, never exposes the room unexpectedly.
        if !options.isVanished(at: time), options.vampire, let face,
           (!options.castle || mask != nil) {
            scene = faceOverlay(face, intensity: options.intensity).composited(over: scene)
        }
        scene = overlay(time: time, options: options, foreground: true).composited(over: scene)
        return try output(scene)
    }

    private func vampireGrade(_ image: CIImage, intensity: Double) -> CIImage {
        guard let face else { return image }
        let r = face.boundingBox
        let center = CIVector(x: r.midX * bounds.width, y: r.midY * bounds.height)
        let radius = r.width * bounds.width * 0.55
        let mask = CIFilter(name: "CIRadialGradient", parameters: ["inputCenter": center,
            "inputRadius0": radius * 0.5, "inputRadius1": radius,
            "inputColor0": CIColor.white, "inputColor1": CIColor.clear])!.outputImage!.cropped(to: bounds)
        let pale = image.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1 - intensity * 0.7,
            kCIInputBrightnessKey: intensity * 0.065, kCIInputContrastKey: 1 + intensity * 0.08])
        return pale.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: image, kCIInputMaskImageKey: mask])
    }

    private func canvas(_ draw: (CGContext) -> Void) -> CIImage {
        let c = CGContext(data: nil, width: VideoFormat.width, height: VideoFormat.height, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        draw(c)
        return CIImage(cgImage: c.makeImage()!)
    }

    private func faceOverlay(_ face: VNFaceObservation, intensity: Double) -> CIImage {
        canvas { c in
            guard intensity > 0 else { return }
            func points(_ region: VNFaceLandmarkRegion2D?) -> [CGPoint] {
                guard let region else { return [] }
                return (0..<region.pointCount).map { i in
                    let p = region.normalizedPoints[i]
                    return CGPoint(x: (face.boundingBox.minX + p.x * face.boundingBox.width) * bounds.width,
                        y: (face.boundingBox.minY + p.y * face.boundingBox.height) * bounds.height)
                }
            }
            for eye in [face.landmarks?.leftEye, face.landmarks?.rightEye] {
                let p = points(eye)
                guard p.count > 3 else { continue }
                let r = p.reduce(CGRect.null) { $0.union(CGRect(origin: $1, size: CGSize(width: 0.1, height: 0.1))) }
                guard r.height > r.width * 0.12 else { continue } // Do not paint closed eyelids.
                c.saveGState()
                c.setShadow(offset: .zero, blur: r.width * 0.16,
                    color: CGColor(red: 0.12, green: 0.02, blue: 0.09, alpha: intensity * 0.5))
                c.setFillColor(CGColor(red: 0.13, green: 0.045, blue: 0.11, alpha: intensity * 0.25))
                c.fillEllipse(in: r.insetBy(dx: -r.width * 0.12, dy: -r.height * 0.5))
                c.restoreGState()
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
            let flash = options.flash(at: time)
            if !foreground, flash > 0 {
                let x: CGFloat = 990
                let points = [CGPoint(x: x, y: 720), CGPoint(x: x - 30, y: 650), CGPoint(x: x + 5, y: 610),
                    CGPoint(x: x - 75, y: 530), CGPoint(x: x - 45, y: 570), CGPoint(x: x - 60, y: 600)]
                c.setShadow(offset: .zero, blur: 20, color: CGColor(red: 0.6, green: 0.75, blue: 1, alpha: flash))
                c.setStrokeColor(CGColor(red: 0.83, green: 0.9, blue: 1, alpha: flash))
                c.setLineWidth(3); c.addLines(between: points); c.strokePath()
                c.setShadow(offset: .zero, blur: 0)
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
