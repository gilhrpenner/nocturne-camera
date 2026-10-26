import CoreImage
import Vision

struct PoseSnapshot {
    let body: BodyMeasurement?
    let hands: [[CGPoint]]
    let face: FaceAnchor
    let time: Double
}

/// One bounded background job keeps torso/hand inference from blocking the video compositor.
final class PoseAnalyzer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "Nocturne.pose", qos: .userInitiated)
    private let lock = NSLock()
    private var busy = false
    private var generation = 0
    private var latest: PoseSnapshot?
    private let bodyRequest = VNDetectHumanBodyPoseRequest()
    private let handRequest = VNDetectHumanHandPoseRequest()

    init() { handRequest.maximumHandCount = 2 }

    func reset() {
        lock.lock(); defer { lock.unlock() }
        generation += 1; latest = nil
    }

    func takeLatest() -> PoseSnapshot? {
        lock.lock(); defer { lock.unlock() }
        let value = latest; latest = nil; return value
    }

    func submit(image: CIImage, face: FaceAnchor, time: Double, hands: Bool, bounds: CGRect) {
        lock.lock()
        guard !busy else { lock.unlock(); return }
        busy = true
        let requestGeneration = generation
        lock.unlock()
        queue.async { [self] in
            let snapshot: PoseSnapshot? = autoreleasepool {
                do {
                    var requests: [VNRequest] = [bodyRequest]
                    if hands { requests.append(handRequest) }
                    try VNImageRequestHandler(ciImage: image, options: [:]).perform(requests)
                    let body = Self.measurement(bodyRequest.results ?? [], face: face, bounds: bounds)
                    let hulls: [[CGPoint]] = hands ? (handRequest.results ?? []).compactMap { hand in
                        guard let points = try? hand.recognizedPoints(.all) else { return nil }
                        let visible = points.values.filter { $0.confidence > 0.25 }.map {
                            CGPoint(x: $0.location.x * bounds.width, y: $0.location.y * bounds.height)
                        }
                        return visible.count >= 8 ? visible : nil
                    } : []
                    return PoseSnapshot(body: body, hands: hulls, face: face, time: time)
                } catch { return nil }
            }
            lock.lock()
            if generation == requestGeneration { latest = snapshot }
            busy = false
            lock.unlock()
        }
    }

    private static func measurement(_ observations: [VNHumanBodyPoseObservation], face: FaceAnchor, bounds: CGRect) -> BodyMeasurement? {
        let candidates: [BodyMeasurement] = observations.compactMap { observation in
            func point(_ joint: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
                guard let p = try? observation.recognizedPoint(joint), p.confidence > 0.25 else { return nil }
                return CGPoint(x: p.location.x * bounds.width, y: p.location.y * bounds.height)
            }
            guard let left = point(.leftShoulder), let right = point(.rightShoulder) else { return nil }
            let hips = [point(.leftHip), point(.rightHip)].compactMap { $0 }
            let arms = [[point(.leftElbow), point(.leftWrist)], [point(.rightElbow), point(.rightWrist)]]
                .map { $0.compactMap { $0 } }.filter { $0.count == 2 }
            return BodyMeasurement(shoulders: [left, right], hips: hips.count == 2 ? hips : [], arms: arms)
        }
        let target = CGPoint(x: face.bounds.midX, y: face.chin.y - face.bounds.height * 0.3)
        return candidates.min { distance(midpoint($0.shoulders[0], $0.shoulders[1]), target) < distance(midpoint($1.shoulders[0], $1.shoulders[1]), target) }
    }
}
