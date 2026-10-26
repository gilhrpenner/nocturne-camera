import CoreGraphics
import Foundation

struct BodyMeasurement {
    var shoulders: [CGPoint]
    var hips: [CGPoint] = []
    var arms: [[CGPoint]] = [] // elbow, wrist for each visible arm
}

struct FaceAnchor {
    let bounds: CGRect
    let chin: CGPoint
}

struct TrackedBody {
    let shoulders: [CGPoint]
    let hips: [CGPoint]
    let arms: [[CGPoint]]
    let isTracked: Bool
}

/// Tracks torso observations independently of the head. Final garment motion is stabilized separately.
final class BodyTracker {
    private var current: BodyMeasurement?
    private var lastTime = -Double.infinity

    func reset() { current = nil; lastTime = -.infinity }

    func update(_ measurement: BodyMeasurement?, face: FaceAnchor?, at time: Double) {
        guard time >= lastTime else { return }
        guard var next = measurement, next.shoulders.count == 2 else { return }
        next.shoulders.sort { $0.x < $1.x }
        next.hips.sort { $0.x < $1.x }
        let span = distance(next.shoulders[0], next.shoulders[1])
        if let face {
            let center = midpoint(next.shoulders[0], next.shoulders[1])
            guard span > face.bounds.width * 1.1, span < face.bounds.width * 4.5,
                  abs(center.x - face.bounds.midX) < face.bounds.width * 0.9,
                  center.y < face.chin.y + face.bounds.height * 0.25,
                  center.y > face.chin.y - face.bounds.height * 1.5 else { return }
        }
        guard span > 50, span < 1100 else { return }
        let dt = time - lastTime
        if let previous = current, dt > 0, dt < 0.25,
           distance(midpoint(previous.shoulders[0], previous.shoulders[1]), midpoint(next.shoulders[0], next.shoulders[1])) < span * 0.5 {
            let movement = distance(midpoint(previous.shoulders[0], previous.shoulders[1]), midpoint(next.shoulders[0], next.shoulders[1]))
            let alpha = min(0.88, max(0.45, 1 - exp(-dt * (12 + movement * 0.25))))
            next.shoulders = zip(previous.shoulders, next.shoulders).map { blend($0, $1, alpha) }
            if previous.hips.count == 2 && next.hips.count == 2 {
                next.hips = zip(previous.hips, next.hips).map { blend($0, $1, alpha) }
            }
        }
        current = next; lastTime = time
    }

    func resolve(face: FaceAnchor, at time: Double) -> TrackedBody {
        if let current, time - lastTime < 0.35 {
            return TrackedBody(shoulders: current.shoulders, hips: current.hips, arms: current.arms, isTracked: true)
        }
        // A quiet fallback when the shoulders are outside the camera crop.
        let span = face.bounds.width * 2.6
        let y = face.chin.y - face.bounds.height * 0.06 - span / 0.70 * 0.095
        let fallback = [CGPoint(x: face.bounds.midX - span / 2, y: y), CGPoint(x: face.bounds.midX + span / 2, y: y)]
        if let current, time - lastTime < 0.8 {
            let fraction = min(1, max(0, (time - lastTime - 0.35) / 0.45))
            return TrackedBody(shoulders: zip(current.shoulders, fallback).map { blend($0, $1, fraction) },
                hips: [], arms: [], isTracked: false)
        }
        return TrackedBody(shoulders: fallback,
            hips: [], arms: [], isTracked: false)
    }
}

func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
func blend(_ a: CGPoint, _ b: CGPoint, _ fraction: Double) -> CGPoint {
    CGPoint(x: a.x + (b.x - a.x) * fraction, y: a.y + (b.y - a.y) * fraction)
}
