import AppKit

@main struct StageEffectsTests {
    static func main() {
        let early = Storm.strikes(at: 100.05, automatic: false, manualAt: 100)
        let later = Storm.strikes(at: 100.15, automatic: false, manualAt: 100)
        precondition(early.count == 1 && later.count == 1)
        precondition(early[0].points == later[0].points && early[0].branches == later[0].branches, "A fading bolt must not jitter")
        precondition(early[0].brightness > later[0].brightness)
        precondition(Storm.strikes(at: 100.4, automatic: false, manualAt: 100).count == 3, "The manual cue must create a cluster")
        precondition(Storm.strikes(at: 101, automatic: false, manualAt: 100).isEmpty)
        precondition(Storm.strikes(at: 100, automatic: false, manualAt: -100).isEmpty)
        var positions = Set<Int>(), strengths = Set<Int>(), eventCount = 0
        for slot in 0..<20 {
            let start = Double(slot) * 3.2 + Storm.random(slot, 1) * 0.65
            let strikes = Storm.strikes(at: start + 0.001, automatic: true, manualAt: -100)
            precondition(!strikes.isEmpty)
            for strike in strikes {
                positions.insert(Int(strike.points[0].x * 10))
                strengths.insert(Int(strike.brightness * 10))
                precondition(strike.branches.count == 2 && strike.brightness > 0 && strike.brightness <= 1)
            }
            eventCount += 1
        }
        precondition(eventCount == 20 && positions.count >= 5 && strengths.count >= 4, "Storm must vary in location and strength")

        let lips = (0..<14).map { i in CGPoint(x: 300 + cos(Double(i) * .pi / 7) * 40, y: 360 + sin(Double(i) * .pi / 7) * 12) }
        func makeup(blood: Bool, time: Double, animate: Bool, intensity: Double = 1) -> Data {
            let c = CGContext(data: nil, width: 600, height: 600, bitsPerComponent: 8, bytesPerRow: 2400,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            VampireMakeup.draw(in: c, eyes: [], outerLips: lips, innerLips: [], face: CGRect(x: 220, y: 300, width: 160, height: 220),
                intensity: intensity, blood: blood, time: time, animateBlood: animate)
            return Data(bytes: c.data!, count: c.bytesPerRow * c.height)
        }
        precondition(makeup(blood: true, time: 1, animate: true) != makeup(blood: false, time: 1, animate: true), "Blood toggle must change the rendered makeup")
        precondition(makeup(blood: true, time: 1, animate: true) != makeup(blood: true, time: 2, animate: true), "Blood must animate")
        precondition(makeup(blood: true, time: 1, animate: false) == makeup(blood: true, time: 2, animate: false), "Reduce Motion must freeze blood")
        precondition(makeup(blood: true, time: 1, animate: true, intensity: 0).allSatisfy { $0 == 0 })
        print("PASS: varied storm, stable fading bolts, manual cluster, blood toggle/animation/reduced motion")
    }
}
