import Foundation
import CoreGraphics

@main struct TrackingStabilityTests {
    static func main() {
        let face = FaceAnchor(bounds: CGRect(x: 270, y: 380, width: 100, height: 140), chin: CGPoint(x: 320, y: 380))
        let base = BodyMeasurement(shoulders: [CGPoint(x: 160, y: 340), CGPoint(x: 480, y: 340)],
            hips: [CGPoint(x: 200, y: 100), CGPoint(x: 440, y: 100)])
        func corners(_ fit: CostumeFit) -> [CGPoint] { [fit.topLeft, fit.topRight, fit.bottomLeft, fit.bottomRight] }
        func replay(_ sample: (Int) -> BodyMeasurement?, faceForFrame: ((Int) -> FaceAnchor)? = nil) -> (step: CGFloat, total: CGFloat) {
            let tracker = BodyTracker(), stabilizer = CostumeStabilizer()
            var previous: [CGPoint] = [], first: [CGPoint] = []
            var largest: CGFloat = 0
            for frame in 0..<120 {
                let time = Double(frame) / 24
                let anchor = faceForFrame?(frame) ?? face
                if frame % 2 == 0 { tracker.update(sample(frame), face: anchor, at: time) }
                let fit = stabilizer.update(CostumeFit.make(body: tracker.resolve(face: anchor, at: time), face: anchor, width: 1, lift: 0), at: time)
                let points = corners(fit)
                if frame == 24 { first = points }
                if frame > 24 { largest = max(largest, zip(points, previous).map { distance($0, $1) }.max()!) }
                previous = points
            }
            return (largest, zip(first, previous).map { distance($0, $1) }.max()!)
        }
        let noise = replay { frame in
            var value = base
            let sign: CGFloat = frame % 4 == 0 ? 1 : -1
            value.shoulders = [CGPoint(x: 160 + sign * 4, y: 340 - sign * 3), CGPoint(x: 480 - sign * 4, y: 340 + sign * 3)]
            return value
        }
        let missingHips = replay { frame in
            var value = base
            if (48..<72).contains(frame) { value.hips = [] }
            return value
        }
        let droppedBody = replay { frame in (48..<68).contains(frame) ? nil : base }
        print(String(format: "Stationary landmark noise: %.2f px maximum garment step", Double(noise.step)))
        print(String(format: "Hip dropout/reacquisition: %.2f px maximum garment step", Double(missingHips.step)))
        print(String(format: "Body dropout/reacquisition: %.2f px maximum garment step", Double(droppedBody.step)))
        let movement = replay { frame in
            var value = base
            let offset = CGFloat(min(60, max(0, frame - 30) * 2))
            value.shoulders = value.shoulders.map { CGPoint(x: $0.x + offset, y: $0.y) }
            value.hips = value.hips.map { CGPoint(x: $0.x + offset, y: $0.y) }
            return value
        }
        precondition(movement.total > 50 && movement.total < 70, "Stabilization must still follow a genuine sustained lean")
        let faceNoise = replay({ _ in nil }, faceForFrame: { frame in
            let d: CGFloat = frame % 2 == 0 ? 1 : -1
            return FaceAnchor(bounds: face.bounds.insetBy(dx: d, dy: d), chin: CGPoint(x: face.chin.x + d, y: face.chin.y + d))
        })
        precondition(faceNoise.step < 3, "The face fallback must also be stabilized")
        let limits: [(String, CGFloat, CGFloat)] = [("landmark noise", noise.step, 4), ("hip dropout", missingHips.step, 8), ("body dropout", droppedBody.step, 8)]
        let failed = limits.filter { $0.1 > $0.2 }
        for failure in failed { print("FAIL: \(failure.0) moves the outfit too far between frames (limit \(failure.2) px)") }
        if !failed.isEmpty { exit(1) }
        print("PASS: steady garment under stationary tracking noise and pose dropouts")
    }
}
