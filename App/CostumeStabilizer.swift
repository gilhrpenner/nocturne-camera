import Foundation
import CoreGraphics

/// Position can follow a lean promptly; garment proportions settle much more slowly.
final class CostumeStabilizer {
    private var previous: CostumeFit?
    private var lastTime = -Double.infinity

    func reset() { previous = nil; lastTime = -.infinity }

    func update(_ target: CostumeFit, at time: Double) -> CostumeFit {
        guard let previous, time > lastTime, time - lastTime < 1.5,
              distance(previous.neck, target.neck) < target.shoulderSpan * 0.8 else {
            self.previous = target; lastTime = time; return target
        }
        let dt = min(0.1, time - lastTime)
        let motion = distance(previous.neck, target.neck)
        let deadband = max(1.2, target.shoulderSpan * 0.005)
        let positionAlpha = 1 - exp(-dt / (motion > target.shoulderSpan * 0.035 ? 0.09 : 0.24))
        let neck = motion < deadband ? previous.neck : blend(previous.neck, target.neck, positionAlpha)
        let shapeAlpha = 1 - exp(-dt / 0.48)
        func corner(_ old: CGPoint, _ new: CGPoint) -> CGPoint {
            let a = CGPoint(x: old.x - previous.neck.x, y: old.y - previous.neck.y)
            let b = CGPoint(x: new.x - target.neck.x, y: new.y - target.neck.y)
            let offset = distance(a, b) < max(1.5, target.shoulderSpan * 0.006) ? a : blend(a, b, shapeAlpha)
            return CGPoint(x: neck.x + offset.x, y: neck.y + offset.y)
        }
        let fit = CostumeFit(topLeft: corner(previous.topLeft, target.topLeft), topRight: corner(previous.topRight, target.topRight),
            bottomLeft: corner(previous.bottomLeft, target.bottomLeft), bottomRight: corner(previous.bottomRight, target.bottomRight),
            neck: neck, shoulderSpan: previous.shoulderSpan + (target.shoulderSpan - previous.shoulderSpan) * shapeAlpha, tracked: target.tracked)
        self.previous = fit; lastTime = time; return fit
    }
}
