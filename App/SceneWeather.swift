import CoreImage
import CoreGraphics

final class SceneWeather {
    func image(time: Double, options: SceneOptions, near: Bool, bounds: CGRect) -> CIImage {
        SceneCanvas.image(bounds: bounds) { c in
            guard !options.normal else { return }
            let t = options.animateScene ? time : 0
            if options.cinematic && options.rainAmount > 0 {
                let count = Int(options.rainAmount * (near ? 35 : 150))
                c.setLineCap(.round)
                for i in 0..<count {
                    let seed = i + (near ? 500 : 0)
                    let speed = (near ? 1.1 : 0.55) + Storm.random(seed, 31) * 0.7
                    let phase = (t * speed + Storm.random(seed, 32)).truncatingRemainder(dividingBy: 1)
                    let x = CGFloat(Storm.random(seed, 33)) * (bounds.width + 180) - 90 + CGFloat(phase) * 70
                    let y = bounds.height * (1 - CGFloat(phase))
                    let length = CGFloat(near ? 17 : 7) + CGFloat(Storm.random(seed, 34)) * 12
                    c.setStrokeColor(CGColor(red: 0.63, green: 0.72, blue: 0.82, alpha: near ? 0.12 : 0.075))
                    c.setLineWidth(near ? 1 : 0.65)
                    c.move(to: CGPoint(x: x, y: y)); c.addLine(to: CGPoint(x: x + length * 0.23, y: y - length)); c.strokePath()
                }
            }
            let age = time - options.swarmAt
            let swarm = age >= 0 && age < 4
            guard options.bats || swarm else { return }
            let count = swarm ? (near ? 12 : 18) : (near ? 1 : 7)
            for i in 0..<count {
                let seed = i + (near ? 60 : 0)
                let phase = ((swarm ? age / 3.4 : t / (17 + Storm.random(seed, 3) * 8)) + Storm.random(seed, 4)).truncatingRemainder(dividingBy: 1)
                let x = CGFloat(phase) * (bounds.width + 200) - 100
                let baseY = near ? 0.38 : 0.63
                let y = bounds.height * CGFloat(baseY + Storm.random(seed, 5) * 0.22) + sin(t * 0.8 + Double(seed)) * (near ? 45 : 28)
                let size = CGFloat(swarm ? 10 + Storm.random(seed, 6) * 17 : (near ? 18 : 5 + Storm.random(seed, 6) * 7))
                let scale = 0.75 + 0.25 * sin(phase * .pi)
                BatPainter.draw(in: c, point: CGPoint(x: x, y: y), size: size * scale, flap: sin(t * 11 + Double(seed) * 1.8), distant: !near)
            }
        }
    }

}
